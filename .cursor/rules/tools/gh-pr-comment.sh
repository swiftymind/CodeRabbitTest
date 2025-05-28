#!/bin/bash
export GITHUB_TOKEN="Add your token here"
# Ensure required environment variables are set
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set."
    exit 1
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
LATEST_COMMIT_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$API_COMMIT_URL" | jq -r '.head.sha')

if [ -z "$LATEST_COMMIT_ID" ] || [ "$LATEST_COMMIT_ID" == "null" ]; then
    echo "Error: Could not fetch the latest commit ID for PR #$PR_NUMBER"
    exit 1
fi

echo "Latest Commit ID: $LATEST_COMMIT_ID"
# Add review comment using GitHub API
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

# cat response.json

# echo "Response Code: $RESPONSE"
if [[ "$RESPONSE" -ne 201 ]]; then
    echo "Failed to add review comment. Check response.json for more details."
    exit 1
fi

echo "Review comment added successfully."