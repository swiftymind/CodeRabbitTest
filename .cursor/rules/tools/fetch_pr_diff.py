import re
import subprocess
import argparse

def get_repo():
    """Fetches the GitHub repository details from the current branch."""
    result = subprocess.run("git config --get remote.origin.url", shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print("Error fetching repository details:", result.stderr)
        exit(1)
    repo_url = result.stdout.strip()
    
    # Handle both SSH and HTTPS URLs with or without usernames
    if repo_url.startswith('git@github.com:'):
        # SSH format: git@github.com:owner/repo.git
        repo = repo_url.replace('git@github.com:', '').replace('.git', '')
    elif 'github.com/' in repo_url:
        # HTTPS format: https://[username@]github.com/owner/repo.git
        # Extract everything after 'github.com/'
        repo = repo_url.split('github.com/')[-1].replace('.git', '')
    else:
        # Fallback to original logic for other formats
        repo = repo_url.split(':')[-1].replace('.git', '').replace('/', '/')
    
    return repo

def get_pr_number():
    """Fetches the current PR number if available."""
    # Try multiple approaches to get PR number
    
    # Method 1: Try with explicit shell=False and full path
    try:
        result = subprocess.run(["/opt/homebrew/bin/gh", "pr", "view", "--json", "number", "--jq", ".number"], 
                              capture_output=True, text=True, shell=False)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except:
        pass
    
    # Method 2: Try without jq, parse JSON manually
    try:
        result = subprocess.run(["/opt/homebrew/bin/gh", "pr", "view", "--json", "number"], 
                              capture_output=True, text=True, shell=False)
        if result.returncode == 0 and result.stdout.strip():
            import json
            data = json.loads(result.stdout.strip())
            return str(data.get('number', ''))
    except:
        pass
    
    # Method 3: Fallback - assume PR 1 exists (common case)
    print("Warning: Could not detect PR number automatically. Assuming PR #1")
    return "1"

def get_pr_diff(pr_number, repo):
    """Fetches the PR diff using GitHub CLI."""
    # Use full path and shell=False to avoid shell interference
    try:
        result = subprocess.run(["/opt/homebrew/bin/gh", "pr", "diff", pr_number, "--repo", repo], 
                              capture_output=True, text=True, shell=False)
        if result.returncode == 0:
            return result.stdout
        else:
            print("Error fetching PR diff:", result.stderr)
            exit(1)
    except Exception as e:
        print(f"Error running gh command: {e}")
        exit(1)

def parse_diff(diff_text):
    result = []
    current_file = None
    current_hunk = None

    for line in diff_text.splitlines():
        file_match = re.match(r'^diff --git a/(.+) b/(.+)', line)
        if file_match:
            if current_file:
                result.append("\n".join(current_file))
            current_file = [f"## File: '{file_match.group(2)}'"]
            current_hunk = None  # Reset current hunk when a new file starts
            continue

        hunk_match = re.match(r'^@@.*@@', line)
        if hunk_match:
            if current_hunk:
                result.append("\n".join(current_hunk))
            current_hunk = ["\n@@ ... @@", "__new hunk__"]
            continue

        if current_hunk is None:
            current_hunk = []  # Ensure hunk is initialized

        if line.startswith('+') and not line.startswith('+++'):
            current_hunk.append(f"{line[1:]} +new code line added in the PR")
        elif line.startswith('-') and not line.startswith('---'):
            current_hunk.append(f"{line[1:]} -old code line removed in the PR")
        else:
            current_hunk.append(line)

    if current_hunk:
        result.append("\n".join(current_hunk))

    if current_file:
        result.append("\n".join(current_file))

    return "\n".join(result)

if __name__ == "__main__":
    repo = get_repo()
    pr_number = get_pr_number()
    
    diff_content = get_pr_diff(pr_number, repo)
    parsed_diff = parse_diff(diff_content)
    print(parsed_diff)