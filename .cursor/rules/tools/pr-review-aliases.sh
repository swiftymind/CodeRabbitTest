#!/bin/bash

# PR Review Aliases for Bash/Zsh
# Source this file in your shell: source .cursor/rules/tools/pr-review-aliases.sh

# Auto-detect repository function
get_repo_path() {
    local repo_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$repo_url" ]; then
        echo "Error: Not in a git repository with GitHub remote" >&2
        return 1
    fi
    echo "$repo_url" | sed -E 's|^.*github\.com[:/]||' | sed 's|\.git$||'
}

# Enhanced PR review aliases
alias review-pr='./.cursor/rules/tools/review-pr.sh'
alias rpr='./.cursor/rules/tools/review-pr.sh'

# List all open PRs for current repository
alias list-prs='REPO_PATH=$(get_repo_path) && [ -n "$REPO_PATH" ] && curl -s "https://api.github.com/repos/$REPO_PATH/pulls?state=open" | grep -E "\"number\"|\"title\"" | sed "N;s/\n/ /" | sed "s/.*\"number\": \([0-9]*\),.*\"title\": \"\([^\"]*\)\".*/  PR #\1: \2/"'
alias lpr='list-prs'

# Quick setup function for new repositories
setup-pr-review() {
    echo "🔧 Setting up PR review system..."
    echo "✅ Repository auto-detection enabled"
    echo "✅ Aliases loaded:"
    echo "   • review-pr <PR_NUMBER> - Review a specific PR"
    echo "   • rpr <PR_NUMBER>       - Short alias for review-pr"
    echo "   • list-prs              - List all open PRs"
    echo "   • lpr                   - Short alias for list-prs"
    echo ""
    echo "💡 Usage: review-pr 4"
}

echo "🚀 PR Review aliases loaded! Run 'setup-pr-review' for usage info." 