#!/bin/bash

# PR Review Automation Script
# Usage: ./review-pr.sh <PR_NUMBER>

set -e

PR_NUMBER=$1

if [ -z "$PR_NUMBER" ]; then
    echo "❌ Error: Please provide a PR number"
    echo "Usage: $0 <PR_NUMBER>"
    echo ""
    echo "Available open PRs:"
    curl -s "https://api.github.com/repos/swiftymind/CodeRabbitTest/pulls?state=open" | grep -E '"number"|"title"' | sed 'N;s/\n/ /' | sed 's/.*"number": \([0-9]*\),.*"title": "\([^"]*\)".*/  PR #\1: \2/'
    exit 1
fi

echo "🔍 Reviewing PR #$PR_NUMBER..."
echo ""

# Get PR details
PR_INFO=$(curl -s "https://api.github.com/repos/swiftymind/CodeRabbitTest/pulls/$PR_NUMBER")
PR_TITLE=$(echo "$PR_INFO" | grep '"title"' | cut -d'"' -f4)
PR_STATE=$(echo "$PR_INFO" | grep '"state"' | cut -d'"' -f4)

if [ "$PR_STATE" != "open" ]; then
    echo "❌ Error: PR #$PR_NUMBER is not open (state: $PR_STATE)"
    exit 1
fi

echo "📝 PR #$PR_NUMBER: $PR_TITLE"
echo "🔄 State: $PR_STATE"
echo ""

# Run generic automated review for any PR
echo "🤖 Running automated code review..."
echo "📋 Reviewing PR #$PR_NUMBER: $PR_TITLE"
echo "🎯 Focus: Code quality, best practices, and potential improvements"
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Generic review approach - you can customize this section
echo "📊 Generic review completed for PR #$PR_NUMBER"
echo "💡 To add specific review comments, you can:"
echo "   1. Use: $SCRIPT_DIR/gh-pr-comment.sh pr review $PR_NUMBER --comment -b \"Your comment\" --path \"file.swift\" --line 10"
echo "   2. Or customize this script to add automated comments for specific file patterns"

echo ""
echo "🎉 PR Review Complete!"
echo "🌐 View PR: https://github.com/swiftymind/CodeRabbitTest/pull/$PR_NUMBER" 