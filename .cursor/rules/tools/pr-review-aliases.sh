#!/bin/bash

# PR Review System Aliases
# Source this file in your shell profile for easy access
# 
# Usage:
#   source .cursor/rules/tools/pr-review-aliases.sh
#   review-pr 2

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Main PR review command
alias review-pr="$SCRIPT_DIR/review-pr.sh"

# Individual comment posting
alias pr-comment="$SCRIPT_DIR/gh-pr-comment.sh pr review"

# List open PRs
alias list-prs='curl -s "https://api.github.com/repos/swiftymind/CodeRabbitTest/pulls?state=open" | grep -E "\"number\"|\"title\"" | sed "N;s/\n/ /" | sed "s/.*\"number\": \([0-9]*\),.*\"title\": \"\([^\"]*\)\".*/  PR #\1: \2/"'

echo "🤖 PR Review aliases loaded!"
echo "Available commands:"
echo "  review-pr <number>     - Review any PR number"
echo "  pr-comment <args>      - Post individual comment"
echo "  list-prs               - List all open PRs" 