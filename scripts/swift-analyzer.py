"""
swift-analyzer.py

This Python script performs an AI-powered code review for Swift and SwiftUI projects on a pull request.
It retrieves the list of modified files from GitHub, filters out irrelevant files (such as binaries or project files),
and analyzes each file using OpenAI's Chat API (GPT-4 with fallback to GPT-3.5).

The script categorizes files into types: SwiftUI, general Swift, UI (UIKit), test, or config,
and adjusts the review prompt accordingly to get more context-specific feedback.
For SwiftUI files, the AI is prompted to consider SwiftUI best practices; for test files, it checks test quality, etc.
It then parses the AI's JSON response and posts inline comments on the PR for each suggestion using GitHub's API.

Non-code files (e.g., .xcodeproj, images, JSON) are ignored to avoid irrelevant feedback [oai_citation:3‡github.com](https://github.com/villesau/ai-codereviewer#:~:text=OPENAI_API_KEY%3A%20%24,exclude%20patterns%20separated%20by%20commas) [oai_citation:4‡cookbook.openai.com](https://cookbook.openai.com/examples/third_party/code_quality_and_security_scan_with_github_actions#:~:text=This%20GitHub%20Actions%20workflow%20is,your%20defined%20enterprise%20standards%20and).
"""
import os
import re
import json
import requests
import openai

# 1. Read environment variables provided by the GitHub Actions workflow
github_token = os.getenv('GITHUB_TOKEN')
openai_api_key = os.getenv('OPENAI_API_KEY')
model = os.getenv('OPENAI_MODEL', 'gpt-4')
pr_number = os.getenv('PR_NUMBER')
repo_slug = os.getenv('GITHUB_REPOSITORY')  # Format: "owner/repo"
commit_sha = os.getenv('PR_HEAD_SHA')       # Head commit SHA of the PR (for posting comments)

if not github_token or not openai_api_key or not pr_number or not repo_slug:
    print("Error: Missing required environment variables. Ensure GITHUB_TOKEN, OPENAI_API_KEY, PR_NUMBER, and GITHUB_REPOSITORY are set.")
    exit(1)

owner, repo = repo_slug.split('/')

# Set OpenAI API key for the openai library
openai.api_key = openai_api_key

# 2. Fetch the list of changed files in the pull request via GitHub API
files_url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/files"
headers = {
    "Authorization": f"Bearer {github_token}",
    "Accept": "application/vnd.github+json"
}
response = requests.get(files_url, headers=headers)
if response.status_code != 200:
    print(f"Failed to fetch PR files: {response.status_code} - {response.text}")
    exit(1)

files = response.json()

# Define patterns for files to exclude (binary files, project files, etc.)
exclude_patterns = [
    ".xcodeproj", ".xcworkspace", ".xcassets", ".pbxproj", ".xcuserstate",
    ".plist", ".lock",
    ".png", ".jpg", ".jpeg", ".gif", ".pdf",
    ".storyboard", ".xib",
    ".md", ".json", ".yaml", ".yml"
]

# Filter out files that we don't want to analyze
files_to_review = []
for file_info in files:
    filename = file_info.get('filename', '')
    # Skip if filename matches any exclude pattern
    if any(pat in filename for pat in exclude_patterns):
        print(f"Skipping file {filename} (excluded from analysis)")
        continue
    # Skip removed files (nothing to analyze)
    if file_info.get('status') == 'removed':
        print(f"Skipping file {filename} (file removed in this PR)")
        continue
    files_to_review.append(file_info)

# Helper function to categorize files into Swift, SwiftUI, UI, Test, or Config
def categorize_file(filename, content_text):
    """Determine the category of a file for targeted review feedback."""
    # Identify test files by naming convention or directory
    if filename.endswith("Test.swift") or "/Tests/" in filename:
        return "Test"
    if filename.endswith(".swift"):
        # Check for SwiftUI or UIKit import statements/usage in content
        if "import SwiftUI" in content_text or "SwiftUI." in content_text:
            return "SwiftUI"
        if "import UIKit" in content_text or "UIView" in content_text or "ViewController" in content_text:
            return "UI"
        return "Swift"
    # Any other file type could be considered configuration or not primary code
    return "Config"

# 3. Loop through each file and generate AI review comments
for file_info in files_to_review:
    filename = file_info['filename']
    patch = file_info.get('patch')
    if not patch:
        # No diff available (binary file or no textual changes), skip
        continue

    # Read full file content from the local checkout for better context (if available)
    file_content = ""
    try:
        with open(filename, 'r') as f:
            file_content = f.read()
    except Exception as e:
        file_content = ""

    # Determine file category for the prompt
    category = categorize_file(filename, file_content if file_content else patch)

    # Parse the patch to construct a diff context for the prompt (include changed and surrounding lines)
    diff_lines = patch.split('\n')
    prompt_lines = []
    new_line_num = 0
    for line in diff_lines:
        if line.startswith('@@'):
            # Diff hunk header, extract the starting line number for the new file chunk
            match = re.search(r'\+(\d+)', line)
            if match:
                new_line_num = int(match.group(1)) - 1
        elif line.startswith('+'):
            # Line added in the new version
            new_line_num += 1
            prompt_lines.append(f"Line {new_line_num}: {line[1:]}")
        elif line.startswith(' '):
            # Unchanged context line in the new version
            new_line_num += 1
            prompt_lines.append(f"Line {new_line_num}: {line[1:]}")
        elif line.startswith('-'):
            # Removed line from old version; skip and do not increment line count for new file
            continue

    # Limit the number of context lines to avoid excessive prompt size
    if len(prompt_lines) > 300:
        prompt_lines = prompt_lines[:300]

    file_diff_context = "\n".join(prompt_lines)

    # Craft the OpenAI prompt messages
    system_message = "You are an experienced iOS developer performing a code review."
    # Add category-specific guidance in the system prompt for better suggestions
    if category == "SwiftUI":
        system_message += " The file uses SwiftUI. Consider SwiftUI-specific best practices, such as efficient use of Views, body structuring, and State/Data Flow."
    elif category == "UI":
        system_message += " The file is related to UIKit (storyboards or view controllers). Check for proper UIView/UIViewController usage and memory management."
    elif category == "Test":
        system_message += " The file is a test file (unit tests/UI tests). Ensure tests are thorough, well-structured, and cover edge cases."
    elif category == "Config":
        system_message += " The file is a configuration or resource. Verify the formatting and values for potential issues."
    else:
        system_message += " The file is a Swift source file. Focus on code logic, style, and potential bugs or improvements."

    user_message = (
        f"Review the changes in `{filename}` below and provide improvement suggestions.\n"
        f"Output the suggestions as a JSON array where each element has a 'line' number and a 'comment'. Focus on the changed lines:\n"
        "```\n" + file_diff_context + "\n```"
    )

    messages = [
        {"role": "system", "content": system_message},
        {"role": "user", "content": user_message}
    ]

    # 4. Call the OpenAI ChatCompletion API to get suggestions (using GPT-4, fallback to GPT-3.5-turbo)
    try:
        ai_completion = openai.ChatCompletion.create(model=model, messages=messages, temperature=0.2)
    except Exception as e:
        if model == 'gpt-4':
            print(f"GPT-4 request failed for {filename}, retrying with gpt-3.5-turbo")
            try:
                ai_completion = openai.ChatCompletion.create(model="gpt-3.5-turbo", messages=messages, temperature=0.2)
                model = "gpt-3.5-turbo"
            except Exception as e2:
                print(f"OpenAI API call failed for {filename}: {e2}")
                continue
        else:
            print(f"OpenAI API call failed for {filename}: {e}")
            continue

    ai_reply = ai_completion.choices[0].message.content if ai_completion and ai_completion.choices else ""
    # 5. Parse the assistant's response into JSON
    suggestions = None
    try:
        suggestions = json.loads(ai_reply)
    except json.JSONDecodeError:
        # If the response is not pure JSON (maybe wrapped in markdown), attempt to fix it
        trimmed = ai_reply.strip().strip('```').strip()
        try:
            suggestions = json.loads(trimmed)
        except Exception as parse_err:
            print(f"Could not parse suggestions for {filename}: {parse_err}")
            continue

    if not suggestions or not isinstance(suggestions, list):
        print(f"No suggestions or invalid format for {filename}.")
        continue

    # 6. Post each suggestion as an inline comment on the GitHub pull request
    for suggestion in suggestions:
        line = suggestion.get("line")
        comment_text = suggestion.get("comment")
        if not line or not comment_text:
            continue  # skip invalid suggestion entries

        # Tidy up the comment text
        comment_text = comment_text.strip()
        if comment_text and not comment_text.endswith((".", "!", "?")):
            comment_text += "."  # ensure the comment ends properly

        # Prepare the review comment payload for GitHub API
        comment_payload = {
            "body": comment_text,
            "commit_id": commit_sha,
            "path": filename,
            "line": line,
            "side": "RIGHT"
        }
        post_url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/comments"
        post_resp = requests.post(post_url, headers=headers, json=comment_payload)
        if post_resp.status_code >= 300:
            print(f"Failed to post comment on {filename} (line {line}): {post_resp.status_code} {post_resp.text}")
        else:
            print(f"Posted comment on {filename} (line {line}): {comment_text}")