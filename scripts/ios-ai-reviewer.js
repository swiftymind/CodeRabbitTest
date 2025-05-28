/**
 * ios-ai-reviewer.js
 *
 * This Node.js script reviews the changes in a pull request using OpenAI's GPT-4 (with fallback to GPT-3.5).
 * It fetches the list of changed files via GitHub API, filters out non-code files (binaries, project files, etc.),
 * and for each remaining file, it constructs a prompt with the diff of changes. The prompt is structured to request
 * line-by-line code review comments in JSON format, which the script then posts back to the GitHub PR as inline comments.
 *
 * The script provides specialized handling for SwiftUI, UI, test, and config files by adjusting the prompt (contextual instructions)
 * to get relevant feedback (e.g., SwiftUI best practices for SwiftUI files). It ignores files like .xcodeproj, .xcworkspace, images,
 * JSON, Markdown, etc., as these are not relevant for code review [oai_citation:0‡github.com](https://github.com/villesau/ai-codereviewer#:~:text=OPENAI_API_KEY%3A%20%24,exclude%20patterns%20separated%20by%20commas) [oai_citation:1‡cookbook.openai.com](https://cookbook.openai.com/examples/third_party/code_quality_and_security_scan_with_github_actions#:~:text=This%20GitHub%20Actions%20workflow%20is,your%20defined%20enterprise%20standards%20and).
 */

const fs = require('fs');
const axios = require('axios');

// Gather required environment variables (set in the workflow file)
const githubToken = process.env.GITHUB_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
let model = process.env.OPENAI_MODEL || 'gpt-4';  // Primary model (GPT-4 by default)
const prNumber = process.env.PR_NUMBER;
const repoSlug = process.env.GITHUB_REPOSITORY;  // "owner/repo"

if (!githubToken || !openaiApiKey || !prNumber || !repoSlug) {
  console.error("Missing required environment variables. Ensure GITHUB_TOKEN, OPENAI_API_KEY, PR_NUMBER, and GITHUB_REPOSITORY are set.");
  process.exit(1);
}

const [owner, repo] = repoSlug.split('/');

(async () => {
  try {
    // 1. Fetch the list of files changed in the pull request
    const filesUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}/files`;
    const filesResponse = await axios.get(filesUrl, {
      headers: {
        Authorization: `Bearer ${githubToken}`,
        Accept: 'application/vnd.github+json'
      }
    });
    const files = filesResponse.data;

    // Define patterns for files to exclude from AI review (binaries, generated files, etc.)
    const excludePatterns = [
      '.xcodeproj', '.xcworkspace', '.xcassets', '.pbxproj', '.xcuserstate',   // Xcode project/workspace files
      '.plist', '.lock',                                                     // Config or lock files
      '.png', '.jpg', '.jpeg', '.gif', '.pdf',                               // Binary assets (images, etc.)
      '.storyboard', '.xib',                                                // UI design files (optional to skip)
      '.md', '.json', '.yaml', '.yml'                                       // Documentation or data files
    ];

    // Filter out files that match any exclude pattern or are removed
    const filesToReview = files.filter(file => {
      const filename = file.filename;
      if (excludePatterns.some(pattern => filename.includes(pattern))) {
        console.log(`Skipping file: ${filename} (matches exclude pattern)`);
        return false;
      }
      if (file.status === 'removed') {
        console.log(`Skipping file: ${filename} (file removed in this PR)`);
        return false;
      }
      return true;
    });

    // Helper function to categorize a file for targeted feedback
    function categorizeFile(filename, content) {
      // Identify test files by naming convention or path
      if (filename.match(/Test\.swift$/) || filename.includes('/Tests/')) {
        return 'Test';
      }
      // Focus only on Swift source files
      if (filename.endsWith('.swift')) {
        if (content.includes('import SwiftUI') || content.includes('SwiftUI.')) {
          return 'SwiftUI';
        }
        if (content.includes('import UIKit') || content.includes('UIView') || content.includes('ViewController')) {
          return 'UI';
        }
        return 'Swift';
      }
      // Other file types (configuration, data, etc.)
      return 'Config';
    }

    // 2. Loop through each file to review and generate AI suggestions
    for (const file of filesToReview) {
      const filename = file.filename;
      const patch = file.patch;  // Unified diff of changes in this file
      if (!patch) {
        // Patch might be undefined for binary files or if no content changes (e.g., file mode changed)
        continue;
      }

      // Read full file content from the checked-out repository (for better context in categorization)
      let fullContent = '';
      try {
        fullContent = fs.readFileSync(filename, 'utf8');
      } catch (err) {
        fullContent = '';
      }

      // Determine file category using either full content or patch (if content not available)
      const category = categorizeFile(filename, fullContent || patch);

      // Build prompt content: include relevant lines from the diff (context + added lines)
      const diffLines = patch.split('\n');
      let promptLines = [];
      let newLineNumber = 0;
      for (const line of diffLines) {
        if (line.startsWith('@@')) {
          // Diff hunk header, extract starting line number for new file
          const match = /@@ .* \+(\d+)(,\d+)? @@/.exec(line);
          if (match) {
            newLineNumber = parseInt(match[1], 10) - 1;
          }
        } else if (line.startsWith('+')) {
          // New added line in diff
          newLineNumber++;
          const content = line.substring(1); // Remove '+' prefix
          promptLines.push(`Line ${newLineNumber}: ${content}`);
        } else if (line.startsWith(' ')) {
          // Context line (unchanged)
          newLineNumber++;
          // Include context lines to give AI some surrounding code for understanding
          promptLines.push(`Line ${newLineNumber}: ${line.substring(1)}`);
        } else if (line.startsWith('-')) {
          // Removed line, do not increment new line number for the new file, skip it
          continue;
        }
      }

      // Optionally limit the context length to avoid very long prompts (if diff is huge)
      if (promptLines.length > 300) {
        promptLines = promptLines.slice(0, 300);
      }

      const fileDiffContext = promptLines.join('\n');

      // Construct system and user messages for the OpenAI chat
      let systemMessage = "You are a senior iOS developer adept in Swift and code review.";
      // Tailor the system message based on file category for more relevant feedback
      if (category === 'SwiftUI') {
        systemMessage += " The following code is a SwiftUI view or related UI code. Focus on SwiftUI best practices, data flow (State, Binding), and UI performance.";
      } else if (category === 'UI') {
        systemMessage += " The following code uses UIKit (storyboards/views/controllers). Focus on UI code structure, memory management, and UIKit best practices.";
      } else if (category === 'Test') {
        systemMessage += " The following code is a test file. Provide feedback on test coverage, assertions, and edge cases.";
      } else if (category === 'Config') {
        systemMessage += " The following is a configuration or non-source file. Check for correctness and potential issues in configuration.";
      } else {
        // 'Swift' or general case
        systemMessage += " The following is a Swift source file. Focus on code quality, efficiency, and maintainability.";
      }

      // User message includes the diff context and asks for JSON formatted suggestions
      const userMessage =
        `Review the changes in the file "${filename}" below. ` +
        `Provide a list of improvement suggestions as JSON objects with "line" and "comment" for each suggestion (line numbers refer to the new file). ` +
        `Focus on the changed lines and provide clear, concise feedback.\n` +
        "```\n" + fileDiffContext + "\n```";

      const messages = [
        { role: 'system', content: systemMessage },
        { role: 'user', content: userMessage }
      ];

      // 3. Call OpenAI API to get code review suggestions (attempt GPT-4, then fallback to GPT-3.5) [oai_citation:2‡cookbook.openai.com](https://cookbook.openai.com/examples/third_party/code_quality_and_security_scan_with_github_actions#:~:text=1,Step%20Validation)
      let aiResponse;
      try {
        aiResponse = await axios.post(
          'https://api.openai.com/v1/chat/completions',
          { model: model, messages: messages, temperature: 0.2 },
          { headers: { 'Authorization': `Bearer ${openaiApiKey}`, 'Content-Type': 'application/json' } }
        );
      } catch (error) {
        if (model === 'gpt-4') {
          console.warn("GPT-4 request failed, retrying with gpt-3.5-turbo...");
          // Fallback to GPT-3.5-turbo if GPT-4 is unavailable or errors out
          model = 'gpt-3.5-turbo';
          try {
            aiResponse = await axios.post(
              'https://api.openai.com/v1/chat/completions',
              { model: model, messages: messages, temperature: 0.2 },
              { headers: { 'Authorization': `Bearer ${openaiApiKey}`, 'Content-Type': 'application/json' } }
            );
          } catch (err) {
            console.error(`OpenAI API call failed on ${filename}:`, err.response ? err.response.data : err.message);
            continue;  // Skip this file if both model calls fail
          }
        } else {
          console.error(`OpenAI API call error on ${filename}:`, error.response ? error.response.data : error.message);
          continue;
        }
      }

      const aiContent = aiResponse.data.choices[0].message.content;
      // 4. Parse the AI response, expected to be a JSON array of comments
      let suggestions;
      try {
        suggestions = JSON.parse(aiContent);
      } catch (parseErr) {
        // If the response is not directly parseable JSON (e.g., it might be wrapped in a code block)
        let trimmed = aiContent.trim();
        if (trimmed.startsWith("```")) {
          // Remove Markdown code fence if present
          trimmed = trimmed.replace(/^```(\w+)?/, '').replace(/```$/, '').trim();
        }
        try {
          suggestions = JSON.parse(trimmed);
        } catch (err) {
          console.error(`Failed to parse AI suggestions for ${filename}:`, err);
          continue;
        }
      }

      if (!Array.isArray(suggestions)) {
        console.log(`No structured suggestions returned for ${filename}.`);
        continue;
      }

      // 5. Post each suggestion as an inline comment on the PR diff
      for (const suggestion of suggestions) {
        if (!suggestion.line || !suggestion.comment) {
          continue;  // skip if malformed suggestion
        }
        const lineNumber = suggestion.line;
        let commentText = suggestion.comment.trim();
        // Ensure the comment is a complete sentence for professionalism
        if (commentText && !/[.!?]$/.test(commentText)) {
          commentText += '.';
        }

        const commentPayload = {
          body: commentText,
          commit_id: process.env.PR_HEAD_SHA,  // commit SHA of the PR head, to anchor the comment
          path: filename,
          line: lineNumber,
          side: "RIGHT"  // comment on the "right" (head) side of the diff
        };

        try {
          await axios.post(
            `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}/comments`,
            commentPayload,
            { headers: { Authorization: `Bearer ${githubToken}`, Accept: 'application/vnd.github+json' } }
          );
          console.log(`Posted comment on ${filename} (line ${lineNumber}): ${commentText}`);
        } catch (postErr) {
          // Log any failures to post (e.g., if line is out of diff bounds or other error)
          const errData = postErr.response ? postErr.response.data : postErr.message;
          console.error(`Failed to post comment on ${filename} line ${lineNumber}:`, errData);
        }
      }
    }
  } catch (err) {
    console.error("Error in AI reviewer script:", err);
    process.exit(1);
  }
})();