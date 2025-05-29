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
import requests
from openai import OpenAI
from typing import List, Dict, Any, Optional

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

def parse_diff_for_review(patch: str) -> List[Dict[str, Any]]:
    """Parse diff patch to extract context and new lines with line numbers."""
    lines = patch.split('\n')
    context_lines = []
    new_line_number = 0

    for line in lines:
        if line.startswith('@@'):
            # Extract starting line number for new file
            match = re.search(r'@@ .* \+(\d+)(,\d+)? @@', line)
            if match:
                new_line_number = int(match.group(1)) - 1
        elif line.startswith('+'):
            # New added line
            new_line_number += 1
            content = line[1:]  # Remove '+' prefix
            context_lines.append({
                'line_number': new_line_number,
                'content': content,
                'type': 'added'
            })
        elif line.startswith(' '):
            # Context line (unchanged)
            new_line_number += 1
            context_lines.append({
                'line_number': new_line_number,
                'content': line[1:],  # Remove ' ' prefix
                'type': 'context'
            })
        # Skip removed lines (don't increment line number)

    return context_lines[:300]  # Limit context to avoid huge prompts

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
    context_lines = parse_diff_for_review(patch)

    if not context_lines:
        return

    # Build context for AI
    diff_context = '\n'.join([
        f"Line {line['line_number']}: {line['content']}"
        for line in context_lines
    ])

    # Construct messages
    system_msg = get_system_message(category)
    user_msg = f"""Review the changes in file "{filename}".
Provide suggestions as a JSON array with objects containing "line" (number) and "comment" (string) fields.
Focus on the changed lines and provide clear, actionable feedback.

```
{diff_context}
```"""

    try:
        # Call OpenAI API
        response = client.chat.completions.create(
            model=MODEL_INLINE,
            messages=[
                {"role": "system", "content": system_msg},
                {"role": "user", "content": user_msg}
            ],
            temperature=0.2,
            max_tokens=1000
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

            # Post each suggestion as inline comment
            for suggestion in suggestions:
                if not all(key in suggestion for key in ['line', 'comment']):
                    continue

                line_number = suggestion['line']
                comment_text = suggestion['comment'].strip()

                # Ensure proper sentence ending
                if comment_text and not comment_text.endswith(('.', '!', '?')):
                    comment_text += '.'

                # Post comment to GitHub
                await post_inline_comment(filename, line_number, comment_text)

        except json.JSONDecodeError as e:
            print(f"⚠️  Failed to parse JSON response for {filename}: {e}")

    except Exception as e:
        print(f"❌ Error reviewing {filename}: {e}")

async def post_inline_comment(filename: str, line_number: int, comment: str) -> None:
    """Post an inline comment to the GitHub PR."""
    payload = {
        'body': comment,
        'commit_id': COMMIT_SHA,
        'path': filename,
        'line': line_number,
        'side': 'RIGHT'
    }

    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/pulls/{PR_NUMBER}/comments"
    response = requests.post(url, headers=HEADERS, json=payload)

    if response.status_code >= 300:
        print(f"⚠️  Failed to post comment on {filename}:{line_number} - {response.text}")
    else:
        print(f"✅ Posted comment on {filename}:{line_number}")

def generate_architectural_summary(files: List[Dict[str, Any]]) -> str:
    """Generate high-level architectural analysis summary."""
    print("🏗️  Generating architectural analysis...")

    file_list = "\n".join([f"- {f['filename']}" for f in files])

    prompt = f"""You are an expert iOS developer and architect.
Analyze the following pull request and provide a **comprehensive, structured report** with:

### 1. Architecture Patterns
- Review adherence to MVC, MVVM, or SwiftUI architectures
- Identify areas for architectural improvements with examples

### 2. Memory Management
- Check for potential retain cycles, proper use of weak self
- State management best practices
- Suggest improvements with code patterns

### 3. Performance Considerations
- Identify potential bottlenecks or inefficiencies
- Recommend optimizations (lazy loading, Combine, etc.)

### 4. UI/UX Review
- Accessibility compliance
- Adaptive layouts and SwiftUI view hierarchy
- User experience improvements

### 5. Code Quality & Maintainability
- Code readability and documentation
- Consistent naming conventions
- Refactoring opportunities
- Testing improvements

### 6. Security & Best Practices
- Identify potential security issues
- Swift/iOS best practice violations
- Data handling and privacy considerations

### 7. Actionable Recommendations
- Specific, prioritized action items
- Implementation suggestions
- Final conclusion with impact assessment

Files changed:
{file_list}

Format as **clear, well-structured Markdown** with bullet points and code examples where helpful."""

    try:
        response = client.chat.completions.create(
            model=MODEL_SUMMARY,
            messages=[
                {"role": "system", "content": "You are an expert Swift/SwiftUI architect and code reviewer."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1200,
            temperature=0.2
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        return f"❌ Error generating architectural analysis: {e}"

def post_summary_comment(content: str) -> None:
    """Post the architectural summary as a PR comment."""
    # Add header to distinguish from inline comments
    full_comment = f"""## 🏗️ AI Architectural Analysis

{content}

---
*This analysis was generated by AI and should be reviewed by human developers.*"""

    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/issues/{PR_NUMBER}/comments"
    payload = {"body": full_comment}

    response = requests.post(url, headers=HEADERS, json=payload)
    if response.status_code >= 300:
        print(f"❌ Failed to post summary comment: {response.text}")
    else:
        print("✅ Posted architectural analysis summary")

async def main():
    """Main execution function."""
    print("🚀 Starting comprehensive AI code review...")

    # Fetch PR files
    files = fetch_pr_files()
    if not files:
        print("ℹ️  No files found in PR")
        return

    # Filter files for review
    files_to_review = [f for f in files if should_review_file(f)]

    if not files_to_review:
        print("ℹ️  No files to review after filtering")
        return

    print(f"📁 Files to review: {[f['filename'] for f in files_to_review]}")

    # 1. Perform inline reviews for each file
    print("\n🔍 Starting inline code reviews...")
    for file_data in files_to_review:
        await review_file_inline(file_data)

    # 2. Generate and post architectural summary
    print("\n🏗️  Generating architectural summary...")
    summary = generate_architectural_summary(files_to_review)
    post_summary_comment(summary)

    print("\n✅ Code review complete!")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())