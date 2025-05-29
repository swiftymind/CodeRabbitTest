#!/usr/bin/env python3

import os
import requests
from openai import OpenAI

# Setup
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
PR_NUMBER = os.getenv('PR_NUMBER')
REPO = os.getenv('GITHUB_REPOSITORY')
COMMIT_SHA = os.getenv('PR_HEAD_SHA')

client = OpenAI(api_key=OPENAI_API_KEY)

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json"
}

OWNER, REPO_NAME = REPO.split('/')

def fetch_pr_files():
    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/pulls/{PR_NUMBER}/files"
    response = requests.get(url, headers=HEADERS)
    if response.status_code != 200:
        print(f"Error fetching PR files: {response.text}")
        return []
    return response.json()

def analyze_code(files):
    file_list = "\n".join([f"- {f['filename']}" for f in files])
    prompt = f"""
You are an expert iOS developer and code reviewer.
Analyze the following pull request files and provide a **structured, detailed report** with:

### 1. Architecture Patterns
- Review for adherence to MVC, MVVM, or SwiftUI-specific architectures.
- Point out areas where architecture can be improved, with examples.

### 2. Memory Management
- Check for retain cycles, use of weak self, state management.
- Suggest improvements with code samples.

### 3. Performance
- Identify potential bottlenecks or inefficiencies.
- Recommend optimizations, such as using lazy loading or Combine.

### 4. UI/UX Considerations
- Review accessibility, adaptive layouts, and SwiftUI view hierarchy.
- Highlight issues and suggest design improvements.

### 5. Code Quality and Maintainability
- Comment on code readability, documentation, and consistent naming.
- Recommend refactoring opportunities.
- Suggest test improvements (unit/UI).

### 6. Actionable Summary
- Provide a bullet-point list of **specific, actionable recommendations** for the team to implement.
- End with a **final actionable conclusion**, such as:
  - "By implementing these changes, the codebase will become more robust, maintainable, and user-friendly."

Files changed:
{file_list}

Ensure the output is **Markdown-formatted**, well-structured, and clear. Use bullet points where appropriate.
"""

    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a Swift/SwiftUI code reviewer."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=900,
            temperature=0.2
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error getting AI review: {e}")
        return f"Error generating AI review: {e}"

def post_pr_comment(comment):
    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/issues/{PR_NUMBER}/comments"
    payload = {"body": comment}
    response = requests.post(url, headers=HEADERS, json=payload)
    if response.status_code >= 300:
        print(f"Error posting comment: {response.text}")
    else:
        print("✅ AI review summary comment posted.")

def main():
    files = fetch_pr_files()
    print(f"📄 Files fetched: {[f['filename'] for f in files]}")
    if not files:
        print("No files to review.")
        return
    review_comment = analyze_code(files)
    print("📝 AI Review Content:\n", review_comment)
    post_pr_comment(review_comment)

if __name__ == "__main__":
    main()