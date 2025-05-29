#!/usr/bin/env python3
"""
ai-code-reviewer.py

Comprehensive AI-powered code reviewer for iOS/Swift projects.
Combines both inline code review comments and high-level architectural analysis.

Features:
1. Line-by-line code review with inline PR comments (similar to ios-ai-reviewer.js)
2. High-level architectural analysis with summary comment (from swift-analyzer.py)
3. Specialized handling for SwiftUI, UIKit, test files, and configuration files
4. Intelligent file filtering to exclude binaries and generated files
"""

import os
import re
import json
import time
import requests
from openai import OpenAI
from typing import List, Dict, Any, Optional, Set

# Environment variables
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
MODEL_INLINE = os.getenv('OPENAI_MODEL', 'gpt-4o')  # For inline reviews
MODEL_SUMMARY = 'gpt-4o-mini'  # For architectural summary (more cost-effective)
PR_NUMBER = os.getenv('PR_NUMBER')
REPO = os.getenv('GITHUB_REPOSITORY')
COMMIT_SHA = os.getenv('PR_HEAD_SHA')

if not all([GITHUB_TOKEN, OPENAI_API_KEY, PR_NUMBER, REPO, COMMIT_SHA]):
    print("❌ Missing required environment variables")
    exit(1)

# Initialize OpenAI client
client = OpenAI(api_key=OPENAI_API_KEY)

# GitHub API headers
HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json"
}

OWNER, REPO_NAME = REPO.split('/')

# File patterns to exclude from review
EXCLUDE_PATTERNS = [
    '.xcodeproj', '.xcworkspace', '.xcassets', '.pbxproj', '.xcuserstate',
    '.plist', '.lock', '.png', '.jpg', '.jpeg', '.gif', '.pdf',
    '.storyboard', '.xib', '.md', '.json', '.yaml', '.yml'
]

# Rate limiting configuration
API_DELAY = 2.0  # Seconds between API calls to avoid rate limits
MAX_COMMENTS_PER_FILE = 5  # Limit comments per file to avoid spam

def rate_limited_request(func):
    """Decorator to add rate limiting to API requests."""
    def wrapper(*args, **kwargs):
        time.sleep(API_DELAY)  # Wait before making request
        return func(*args, **kwargs)
    return wrapper

def fetch_pr_files() -> List[Dict[str, Any]]:
    """Fetch the list of files changed in the pull request."""
    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/pulls/{PR_NUMBER}/files"
    response = requests.get(url, headers=HEADERS)
    if response.status_code != 200:
        print(f"❌ Error fetching PR files: {response.text}")
        return []
    return response.json()

def should_review_file(file_data: Dict[str, Any]) -> bool:
    """Determine if a file should be reviewed based on exclude patterns and status."""
    filename = file_data['filename']

    # Skip removed files
    if file_data['status'] == 'removed':
        print(f"⏭️  Skipping {filename} (file removed)")
        return False

    # Skip files matching exclude patterns
    if any(pattern in filename for pattern in EXCLUDE_PATTERNS):
        print(f"⏭️  Skipping {filename} (matches exclude pattern)")
        return False

    # Must have a patch (diff content)
    if not file_data.get('patch'):
        print(f"⏭️  Skipping {filename} (no patch content)")
        return False

    return True

def categorize_file(filename: str, content: str) -> str:
    """Categorize file type for targeted review prompts."""
    if re.search(r'Test\.swift$', filename) or '/Tests/' in filename:
        return 'Test'

    if filename.endswith('.swift'):
        if 'import SwiftUI' in content or 'SwiftUI.' in content:
            return 'SwiftUI'
        if any(keyword in content for keyword in ['import UIKit', 'UIView', 'ViewController']):
            return 'UI'
        return 'Swift'

    return 'Config'

def parse_diff_for_review(patch: str) -> tuple[List[Dict[str, Any]], Set[int]]:
    """Parse diff patch to extract context and valid line numbers for comments."""
    lines = patch.split('\n')
    context_lines = []
    valid_comment_lines = set()  # Track which lines can receive comments
    new_line_number = 0

    for line in lines:
        if line.startswith('@@'):
            # Extract starting line number for new file
            match = re.search(r'@@ .* \+(\d+)(,\d+)? @@', line)
            if match:
                new_line_number = int(match.group(1)) - 1
        elif line.startswith('+'):
            # New added line - these can receive comments
            new_line_number += 1
            content = line[1:]  # Remove '+' prefix
            context_lines.append({
                'line_number': new_line_number,
                'content': content,
                'type': 'added'
            })
            valid_comment_lines.add(new_line_number)  # Mark as valid for comments
        elif line.startswith(' '):
            # Context line (unchanged)
            new_line_number += 1
            context_lines.append({
                'line_number': new_line_number,
                'content': line[1:],  # Remove ' ' prefix
                'type': 'context'
            })
        # Skip removed lines (don't increment line number)

    return context_lines[:300], valid_comment_lines  # Limit context to avoid huge prompts

def get_system_message(category: str) -> str:
    """Get specialized system message based on file category."""
    base_msg = "You are a senior iOS developer expert in Swift and code review."

    if category == 'SwiftUI':
        return base_msg + " Focus on SwiftUI best practices, data flow (State, Binding, ObservableObject), view composition, and performance."
    elif category == 'UI':
        return base_msg + " Focus on UIKit best practices, view controller lifecycle, memory management, and Auto Layout."
    elif category == 'Test':
        return base_msg + " Focus on test coverage, proper assertions, edge cases, and test maintainability."
    elif category == 'Config':
        return base_msg + " Focus on configuration correctness and potential security issues."
    else:
        return base_msg + " Focus on Swift best practices, code quality, performance, and maintainability."

async def review_file_inline(file_data: Dict[str, Any]) -> None:
    """Perform inline code review for a single file."""
    filename = file_data['filename']
    patch = file_data['patch']

    print(f"🔍 Reviewing {filename} for inline comments...")

    # Read full file content for better categorization
    full_content = ''
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            full_content = f.read()
    except (FileNotFoundError, UnicodeDecodeError):
        full_content = patch  # Fallback to patch content

    # Categorize file and parse diff
    category = categorize_file(filename, full_content)
    context_lines, valid_comment_lines = parse_diff_for_review(patch)

    if not context_lines:
        print(f"⚠️  No context lines found for {filename}")
        return

    print(f"📝 Found {len(valid_comment_lines)} valid lines for comments in {filename}")

    # Build context for AI - focus on added lines
    added_lines = [line for line in context_lines if line['type'] == 'added']
    if not added_lines:
        print(f"⚠️  No added lines to review in {filename}")
        return

    diff_context = '\n'.join([
        f"Line {line['line_number']}: {line['content']}"
        for line in context_lines
    ])

    # Construct messages
    system_msg = get_system_message(category)
    user_msg = f"""Review the changes in file "{filename}".
Provide suggestions ONLY for the newly added lines (marked with +).
Return a JSON array with objects containing "line" (number) and "comment" (string) fields.
Focus on the most critical issues. Maximum {MAX_COMMENTS_PER_FILE} comments.

Valid line numbers for comments: {sorted(list(valid_comment_lines))}

```
{diff_context}
```"""

    try:
        # Call OpenAI API with rate limiting
        print(f"🤖 Calling OpenAI API for {filename}...")
        time.sleep(1)  # Brief delay before API call

        response = client.chat.completions.create(
            model=MODEL_INLINE,
            messages=[
                {"role": "system", "content": system_msg},
                {"role": "user", "content": user_msg}
            ],
            temperature=0.2,
            max_tokens=800  # Reduced to limit response size
        )

        ai_content = response.choices[0].message.content.strip()

        # Parse JSON response
        try:
            # Handle potential markdown code blocks
            if ai_content.startswith('```'):
                ai_content = re.sub(r'^```\w*\n?', '', ai_content)
                ai_content = re.sub(r'\n?```$', '', ai_content)

            suggestions = json.loads(ai_content)

            if not isinstance(suggestions, list):
                print(f"⚠️  Non-array response for {filename}")
                return

            # Filter and limit suggestions
            valid_suggestions = []
            for suggestion in suggestions:
                if not all(key in suggestion for key in ['line', 'comment']):
                    continue

                line_number = suggestion['line']

                # Validate line number is in valid comment lines
                if line_number not in valid_comment_lines:
                    print(f"⚠️  Skipping invalid line {line_number} for {filename}")
                    continue

                valid_suggestions.append(suggestion)

                # Limit number of comments per file
                if len(valid_suggestions) >= MAX_COMMENTS_PER_FILE:
                    break

            print(f"📝 Posting {len(valid_suggestions)} valid comments for {filename}")

            # Post each valid suggestion as inline comment
            for i, suggestion in enumerate(valid_suggestions):
                line_number = suggestion['line']
                comment_text = suggestion['comment'].strip()

                # Ensure proper sentence ending
                if comment_text and not comment_text.endswith(('.', '!', '?')):
                    comment_text += '.'

                # Post comment to GitHub with rate limiting
                print(f"📤 Posting comment {i+1}/{len(valid_suggestions)} for {filename}:{line_number}")
                await post_inline_comment(filename, line_number, comment_text)

        except json.JSONDecodeError as e:
            print(f"⚠️  Failed to parse JSON response for {filename}: {e}")

    except Exception as e:
        print(f"❌ Error reviewing {filename}: {e}")

@rate_limited_request
async def post_inline_comment(filename: str, line_number: int, comment: str) -> None:
    """Post an inline comment to the GitHub PR with rate limiting."""
    payload = {
        'body': comment,
        'commit_id': COMMIT_SHA,
        'path': filename,
        'line': line_number,
        'side': 'RIGHT'
    }

    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/pulls/{PR_NUMBER}/comments"

    try:
        response = requests.post(url, headers=HEADERS, json=payload)

        if response.status_code == 201:
            print(f"✅ Posted comment on {filename}:{line_number}")
        elif response.status_code == 422:
            print(f"⚠️  Invalid line number {line_number} for {filename} (line not in diff)")
        elif response.status_code == 403:
            print(f"🚫 Rate limited - waiting longer before next request...")
            time.sleep(10)  # Wait longer if rate limited
        else:
            print(f"⚠️  Failed to post comment on {filename}:{line_number} - {response.status_code}")

    except Exception as e:
        print(f"❌ Exception posting comment on {filename}:{line_number}: {str(e)}")

def generate_architectural_summary(files: List[Dict[str, Any]]) -> str:
    """Generate high-level architectural analysis summary."""
    print("🏗️  Generating architectural analysis...")

    # Create a more detailed file analysis for the prompt
    file_details = []
    for file_data in files:
        filename = file_data['filename']
        additions = file_data.get('additions', 0)
        deletions = file_data.get('deletions', 0)
        file_details.append(f"- {filename} (+{additions}/-{deletions} lines)")

    file_list = "\n".join(file_details)

    prompt = f"""You are an expert iOS developer and architect reviewing a pull request.

**Files Changed ({len(files)} files):**
{file_list}

Please provide a **comprehensive, structured analysis** covering:

## 📋 Pull Request Summary
- Brief overview of the changes and their purpose
- Impact assessment (High/Medium/Low)

## 🏗️ Architecture & Design
- Review of architectural patterns (MVC, MVVM, SwiftUI)
- Design principle adherence (SOLID, Clean Architecture)
- Suggestions for architectural improvements

## 🧠 Memory & Performance
- Memory management best practices
- Potential retain cycles or leaks
- Performance optimization opportunities
- Threading and concurrency considerations

## 🎨 UI/UX & Accessibility
- User interface design patterns
- SwiftUI best practices (if applicable)
- Accessibility compliance (VoiceOver, Dynamic Type)
- Responsive design considerations

## 🔒 Security & Best Practices
- Data handling and privacy compliance
- Input validation and error handling
- API security considerations
- iOS security best practices

## 🧪 Testing & Quality
- Test coverage assessment
- Code maintainability and readability
- Documentation quality
- Refactoring opportunities

## ⚡ Action Items
1. **High Priority**: Critical issues that should be addressed
2. **Medium Priority**: Important improvements
3. **Low Priority**: Nice-to-have optimizations

## 🎯 Overall Assessment
- Code quality score (1-10)
- Readiness for merge (Ready/Needs Changes/Major Revisions)
- Key strengths and areas for improvement

Format as **clear Markdown** with emojis, bullet points, and code examples where helpful."""

    try:
        print("🤖 Calling OpenAI API for architectural analysis...")
        response = client.chat.completions.create(
            model=MODEL_SUMMARY,
            messages=[
                {"role": "system", "content": "You are an expert Swift/SwiftUI architect and code reviewer with 10+ years of iOS development experience."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1500,  # Increased for more comprehensive analysis
            temperature=0.1   # Lower temperature for more consistent analysis
        )

        summary_content = response.choices[0].message.content.strip()
        print("✅ Successfully generated architectural analysis")
        return summary_content

    except Exception as e:
        error_msg = f"❌ Error generating architectural analysis: {str(e)}"
        print(error_msg)

        # Return a basic fallback summary
        return f"""## 🏗️ AI Architectural Analysis

**Note**: Error occurred during analysis generation.

### Files Reviewed
{file_list}

### Status
Analysis could not be completed due to: {str(e)}

Please review the inline comments for detailed feedback on individual files."""

@rate_limited_request
def post_summary_comment(content: str) -> bool:
    """Post the architectural summary as a PR comment. Returns True if successful."""
    print("📝 Posting architectural summary to PR...")

    # Enhanced header with more context
    full_comment = f"""# 🤖 AI Code Review Summary

{content}

---
> 💡 **Note**: This analysis was generated by AI and should be reviewed by human developers.
>
> 🔍 **Inline Comments**: Check individual file diffs for detailed line-by-line feedback.
>
> 📅 **Generated**: {os.getenv('GITHUB_SHA', 'Unknown commit')[:7]}"""

    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/issues/{PR_NUMBER}/comments"
    payload = {"body": full_comment}

    try:
        response = requests.post(url, headers=HEADERS, json=payload)

        if response.status_code == 201:
            print("✅ Successfully posted architectural analysis summary to PR")
            return True
        elif response.status_code == 403:
            print("🚫 Rate limited when posting summary - waiting and retrying...")
            time.sleep(15)  # Wait longer for summary

            # Retry once
            response = requests.post(url, headers=HEADERS, json=payload)
            if response.status_code == 201:
                print("✅ Successfully posted summary after retry")
                return True
            else:
                print(f"❌ Failed summary retry: {response.status_code}")
                return False
        else:
            print(f"❌ Failed to post summary comment: {response.status_code} - {response.text[:200]}")
            return False

    except Exception as e:
        print(f"❌ Exception posting summary comment: {str(e)}")
        return False

async def main():
    """Main execution function."""
    print("🚀 Starting comprehensive AI code review...")
    print(f"⚙️  Rate limiting: {API_DELAY}s between requests, max {MAX_COMMENTS_PER_FILE} comments per file")

    # Fetch PR files
    files = fetch_pr_files()
    if not files:
        print("ℹ️  No files found in PR")
        return

    print(f"📊 Total files in PR: {len(files)}")

    # Filter files for review
    files_to_review = [f for f in files if should_review_file(f)]

    if not files_to_review:
        print("ℹ️  No files to review after filtering")
        # Still post a summary even if no files to review
        summary = """## 🏗️ AI Code Review Summary

**Status**: No reviewable code files found in this PR.

The PR may contain only:
- Binary files (images, assets)
- Configuration files
- Documentation files

No code review comments were generated."""
        post_summary_comment(summary)
        return

    print(f"📁 Files selected for review: {[f['filename'] for f in files_to_review]}")

    # 1. Perform inline reviews for each file
    print("\n🔍 Starting inline code reviews...")
    total_comments_posted = 0

    for i, file_data in enumerate(files_to_review, 1):
        print(f"\n📄 Processing file {i}/{len(files_to_review)}: {file_data['filename']}")
        try:
            await review_file_inline(file_data)

            # Add delay between files to avoid overwhelming GitHub API
            if i < len(files_to_review):  # Don't delay after last file
                print(f"⏸️  Waiting {API_DELAY}s before next file...")
                time.sleep(API_DELAY)

        except Exception as e:
            print(f"❌ Error processing {file_data['filename']}: {str(e)}")
            continue

    # 2. Generate and post architectural summary (always attempt this)
    print(f"\n🏗️  Generating architectural summary for {len(files_to_review)} files...")
    try:
        print("⏸️  Waiting before summary generation...")
        time.sleep(3)  # Extra wait before summary

        summary = generate_architectural_summary(files_to_review)
        success = post_summary_comment(summary)

        if not success:
            print("⚠️  Retrying summary post with simplified content...")
            # Fallback: post a simple summary
            simple_summary = f"""## 🏗️ AI Code Review Summary

**Files Reviewed**: {len(files_to_review)} files
- {chr(10).join([f"• {f['filename']}" for f in files_to_review])}

**Status**: Analysis completed with rate limiting. Check inline comments for specific feedback.

*Note: Simplified summary due to API limitations.*"""

            time.sleep(5)  # Wait before retry
            post_summary_comment(simple_summary)

    except Exception as e:
        print(f"❌ Critical error in summary generation: {str(e)}")
        # Always try to post something
        error_summary = f"""## 🏗️ AI Code Review Summary

**Error**: Summary generation failed: {str(e)}

**Files in PR**: {len(files_to_review)} reviewable files found.

Please check individual file comments for detailed feedback."""

        time.sleep(3)
        post_summary_comment(error_summary)

    print(f"\n✅ Code review process complete!")
    print(f"📈 Processed {len(files_to_review)} files with rate limiting")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())