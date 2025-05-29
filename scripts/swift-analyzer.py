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
    return response.json() if response.status_code == 200 else []

def analyze_code(files):
    file_list = "\n".join([f"- {f['filename']}" for f in files])
    prompt = f"""
You are an expert Swift/SwiftUI developer and code reviewer.
Analyze the following pull request files and provide a summary report with:
1. Swift code best practices (MVC, MVVM, SwiftUI-specific concerns)
2. Memory management and performance issues
3. Architecture recommendations
4. UI/UX design considerations (if applicable)
5. Testing and code maintainability

Files changed:
{file_list}

Focus on potential issues, risks, and improvements. Provide actionable feedback in Markdown format with clear sections.
"""
    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": "You are a Swift/SwiftUI code reviewer."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=800,
            temperature=0.2
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error getting AI review: {e}")
        return "Error generating AI review."

def post_pr_comment(comment):
    url = f"https://api.github.com/repos/{OWNER}/{REPO_NAME}/issues/{PR_NUMBER}/comments"
    payload = {"body": comment}
    response = requests.post(url, headers=HEADERS, json=payload)
    if response.status_code >= 300:
        print(f"Error posting comment: {response.text}")
    else:
        print("✅ AI review comment posted.")

def main():
    files = fetch_pr_files()
    if not files:
        print("No files to review.")
        return
    review_comment = analyze_code(files)
    post_pr_comment(review_comment)

if __name__ == "__main__":
    main()