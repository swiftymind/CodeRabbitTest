#!/bin/bash

# PR Review Automation Script - Enhanced with Actual Code Analysis
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fetch PR file changes
echo "🔍 Fetching changed files..."
PR_FILES=$(curl -s "https://api.github.com/repos/swiftymind/CodeRabbitTest/pulls/$PR_NUMBER/files")

# Count files changed
FILES_COUNT=$(echo "$PR_FILES" | jq '. | length')
echo "📁 Found $FILES_COUNT changed files"
echo ""

# Function to analyze and review code
analyze_and_review() {
    local filename="$1"
    local patch="$2"
    local additions="$3"
    local deletions="$4"
    
    echo "🔍 Analyzing: $filename"
    
    # Extract specific line numbers that were added
    local added_lines=$(echo "$patch" | grep "^+" | grep -v "^+++" | head -5)
    
    # Generate intelligent review comments based on file type and content
    if [[ "$filename" == *.md ]]; then
        # Markdown documentation review
        if echo "$patch" | grep -q "token\|password\|secret"; then
            post_review_comment "$filename" "1" "⚠️ **Security Alert**: This documentation contains references to tokens/passwords. Consider using placeholders or environment variables instead."
        fi
        
        if [[ $additions -gt 100 ]]; then
            post_review_comment "$filename" "1" "📖 **Documentation Review**: This is a substantial documentation addition ($additions lines). Great work on comprehensive documentation! Consider breaking it into smaller sections for better readability."
        fi
        
    elif [[ "$filename" == *.sh ]]; then
        # Shell script review
        if echo "$patch" | grep -q "curl.*-s"; then
            local line_num=$(echo "$patch" | grep -n "curl.*-s" | head -1 | cut -d: -f1)
            post_review_comment "$filename" "$line_num" "🔒 **Security**: Consider adding timeout and retry logic to curl commands. Also validate API responses before processing."
        fi
        
        if ! echo "$patch" | grep -q "set -e"; then
            post_review_comment "$filename" "1" "💡 **Best Practice**: Consider adding 'set -e' at the top of the script to exit on errors."
        fi
        
        if echo "$patch" | grep -q "echo.*\$"; then
            local line_num=$(echo "$patch" | grep -n "echo.*\$" | head -1 | cut -d: -f1)
            post_review_comment "$filename" "$line_num" "🐛 **Potential Issue**: Unquoted variables in echo statements can cause issues. Consider using double quotes around variables."
        fi
        
    elif [[ "$filename" == *.swift ]]; then
        # Swift code review
        if echo "$patch" | grep -q "force.*unwrap\|!"; then
            local line_num=$(echo "$patch" | grep -n "!" | head -1 | cut -d: -f1)
            post_review_comment "$filename" "$line_num" "⚠️ **Swift Safety**: Consider using optional binding or nil coalescing instead of force unwrapping to prevent runtime crashes."
        fi
        
        if echo "$patch" | grep -q "@objc\|NSObject"; then
            post_review_comment "$filename" "1" "🔍 **Architecture**: Using Objective-C bridging. Consider if pure Swift alternatives would be more appropriate for new code."
        fi
        
    elif [[ "$filename" == ".gitignore" ]]; then
        # Gitignore review
        if echo "$patch" | grep -q "\.env\|config.*\.json"; then
            post_review_comment "$filename" "1" "✅ **Security**: Good practice ignoring environment and config files. Make sure all sensitive files are covered."
        fi
    fi
    
    # Generic code quality checks
    if [[ $additions -gt 50 && $deletions -eq 0 ]]; then
        post_review_comment "$filename" "1" "📏 **Code Size**: This is a large addition ($additions lines) with no deletions. Consider if this could be broken into smaller, more focused changes."
    fi
}

# Function to post review comments
post_review_comment() {
    local file_path="$1"
    local line_num="$2"
    local comment="$3"
    
    echo "💬 Posting comment to $file_path:$line_num"
    echo "   └── $comment"
    
    # Use the existing gh-pr-comment.sh script to post the comment
    "$SCRIPT_DIR/gh-pr-comment.sh" pr review "$PR_NUMBER" \
        --comment -b "$comment" \
        --path "$file_path" \
        --line "$line_num" 2>/dev/null || {
        echo "   ⚠️  Could not post comment (file may not have changes at line $line_num)"
    }
    
    echo ""
}

# Start automated review
echo "🤖 Starting Intelligent Code Review..."
echo "🎯 Analyzing code patterns, security, and best practices"
echo ""

# Process each changed file
echo "$PR_FILES" | jq -c '.[]' | while read -r file_data; do
    filename=$(echo "$file_data" | jq -r '.filename')
    patch=$(echo "$file_data" | jq -r '.patch // ""')
    additions=$(echo "$file_data" | jq -r '.additions')
    deletions=$(echo "$file_data" | jq -r '.deletions')
    
    # Skip if no patch (binary files, etc.)
    if [ "$patch" = "null" ] || [ -z "$patch" ]; then
        echo "⏭️  Skipping $filename (no diff available)"
        continue
    fi
    
    analyze_and_review "$filename" "$patch" "$additions" "$deletions"
done

echo "🎉 Automated Code Review Complete!"
echo ""
echo "📊 Review Summary:"
echo "   • Files analyzed: $FILES_COUNT"
echo "   • Focus areas: Security, Best practices, Code quality"
echo "   • Comments posted: Check PR on GitHub"
echo ""
echo "🌐 View PR with comments: https://github.com/swiftymind/CodeRabbitTest/pull/$PR_NUMBER"
echo ""
echo "💡 This automated review supplements human review - always verify suggestions!" 