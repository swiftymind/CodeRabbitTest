#!/bin/bash

# 🔒 SECURITY: GitHub token should NEVER be hardcoded!
# This script now uses secure methods to get the GitHub token.

# Method 1: Try to use GitHub CLI (recommended)
if command -v gh &> /dev/null; then
    # Check if GitHub CLI is authenticated
    if gh auth status &> /dev/null; then
        echo "✅ Using GitHub CLI authentication (recommended)"
        # GitHub CLI will handle authentication automatically
        USE_GH_CLI=true
    else
        echo "⚠️  GitHub CLI found but not authenticated. Run 'gh auth login' first."
        USE_GH_CLI=false
    fi
else
    echo "ℹ️  GitHub CLI not found. Using environment variable method."
    USE_GH_CLI=false
fi

# Method 2: Use environment variable (fallback)
if [ "$USE_GH_CLI" = false ]; then
    if [ -z "$GITHUB_TOKEN" ]; then
        echo ""
        echo "🚨 SECURITY ERROR: No GitHub token found!"
        echo ""
        echo "🔒 SECURE OPTIONS:"
        echo "   1. Use GitHub CLI (RECOMMENDED):"
        echo "      brew install gh"
        echo "      gh auth login"
        echo ""
        echo "   2. Set environment variable:"
        echo "      export GITHUB_TOKEN='your_token_here'"
        echo "      (Add this to your ~/.bashrc or ~/.zshrc)"
        echo ""
        echo "   3. Create .env file in project root:"
        echo "      echo 'GITHUB_TOKEN=your_token_here' > .env"
        echo "      source .env"
        echo ""
        echo "❌ NEVER hardcode tokens in scripts!"
        exit 1
    else
        echo "✅ Using GITHUB_TOKEN environment variable"
    fi
fi

# Check arguments
if [ "$1" != "pr" ] || [ "$2" != "review" ]; then
    echo "Usage: $0 pr review <PR_NUMBER> --comment -b <review comment> --path <FILE_PATH> --line <LINE_NUMBER>"
    exit 1
fi

# Parse arguments
PR_NUMBER=$3
shift 3

COMMENT=""
FILE_PATH=""
LINE_NUMBER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --comment)
            shift
            if [ "$1" != "-b" ]; then
                echo "Error: --comment flag must be followed by -b <review comment>"
                exit 1
            fi
            shift
            COMMENT="$1"
            ;;
        --path)
            shift
            FILE_PATH="$1"
            ;;
        --line)
            shift
            LINE_NUMBER="$1"
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Validate required parameters
if [ -z "$PR_NUMBER" ] || [ -z "$COMMENT" ] || [ -z "$FILE_PATH" ] || [ -z "$LINE_NUMBER" ]; then
    echo "Error: Missing required parameters."
    echo "Usage: $0 pr review <PR_NUMBER> --comment -b <review comment> --path <FILE_PATH> --line <LINE_NUMBER>"
    exit 1
fi

# Get repository owner and name from git remote
REMOTE_URL=$(git config --get remote.origin.url)
if [[ "$REMOTE_URL" =~ github.com[:/]([^/]+)/([^/.]+) ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
else
    echo "Error: Could not determine repository owner and name from remote URL: $REMOTE_URL"
    exit 1
fi

echo "Repository: $OWNER/$REPO"
echo "PR Number: $PR_NUMBER"
echo "File Path: $FILE_PATH"
echo "Line Number: $LINE_NUMBER"
echo "Comment: $COMMENT"
echo "Fetching commit ID..."

# Get latest commit ID of the PR
API_COMMIT_URL="https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER"

if [ "$USE_GH_CLI" = true ]; then
    # Use GitHub CLI for API calls (more secure)
    LATEST_COMMIT_ID=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER" --jq '.head.sha')
else
    # Fallback to manual curl with environment variable
    LATEST_COMMIT_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$API_COMMIT_URL" | jq -r '.head.sha')
fi

if [ -z "$LATEST_COMMIT_ID" ] || [ "$LATEST_COMMIT_ID" == "null" ]; then
    echo "Error: Could not fetch the latest commit ID for PR #$PR_NUMBER"
    exit 1
fi

echo "Latest Commit ID: $LATEST_COMMIT_ID"

# Add review comment using GitHub API
if [ "$USE_GH_CLI" = true ]; then
    # Use GitHub CLI to post comment (more secure)
    RESPONSE=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments" \
        --method POST \
        --field body="$COMMENT" \
        --field commit_id="$LATEST_COMMIT_ID" \
        --field path="$FILE_PATH" \
        --field line="$LINE_NUMBER" \
        --field side="RIGHT" 2>/dev/null && echo "201" || echo "error")
else
    # Fallback to manual curl
    API_URL="https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments"
    RESPONSE=$(curl -L -s -o response.json -w "%{http_code}" \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$API_URL" \
        -d "{
            \"body\": \"$COMMENT\",
            \"commit_id\": \"$LATEST_COMMIT_ID\",
            \"path\": \"$FILE_PATH\",
            \"line\": $LINE_NUMBER,
            \"side\": \"RIGHT\"
        }")
fi

# Check response
if [ "$USE_GH_CLI" = true ]; then
    if [ "$RESPONSE" = "201" ]; then
        echo "Review comment added successfully using GitHub CLI."
    else
        echo "Failed to add review comment using GitHub CLI."
        exit 1
    fi
else
    if [[ "$RESPONSE" -ne 201 ]]; then
        echo "Failed to add review comment. Check response.json for more details."
        exit 1
    fi
    echo "Review comment added successfully using environment variable."
fi