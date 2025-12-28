#!/bin/bash

# PR Review Automation Script - Enhanced with Swift Conventions Analysis
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

# Load Swift conventions
SWIFT_CONVENTIONS_FILE="$SCRIPT_DIR/../swift-conventions.mdc"
if [ -f "$SWIFT_CONVENTIONS_FILE" ]; then
    echo "📚 Loading Swift conventions from: swift-conventions.mdc"
    SWIFT_CONVENTIONS=$(cat "$SWIFT_CONVENTIONS_FILE")
    echo "✅ Swift conventions loaded successfully"
    echo ""
else
    echo "⚠️  Swift conventions file not found, using basic rules"
    SWIFT_CONVENTIONS=""
fi

# Fetch PR file changes
echo "🔍 Fetching changed files..."
PR_FILES=$(curl -s "https://api.github.com/repos/swiftymind/CodeRabbitTest/pulls/$PR_NUMBER/files")

# Count files changed
FILES_COUNT=$(echo "$PR_FILES" | jq '. | length')
echo "📁 Found $FILES_COUNT changed files"
echo ""

# Function to check Swift conventions
check_swift_conventions() {
    local filename="$1"
    local patch="$2"
    local line_num="$3"
    
    # Check for XCTest usage (should use Swift Testing instead)
    if echo "$patch" | grep -q "import XCTest\|XCTestCase\|XCTest"; then
        post_review_comment "$filename" "$line_num" "⚠️ **Swift Testing Convention**: Use Swift Testing framework instead of XCTest. Import 'Testing' and use '@Suite' and '@Test' annotations."
    fi
    
    # Check for Swift Testing best practices
    if echo "$patch" | grep -q "@Test"; then
        if ! echo "$patch" | grep -q '".*"'; then
            post_review_comment "$filename" "$line_num" "💡 **Swift Testing Best Practice**: Consider adding descriptive test names using @Test(\"Description\") format for better readability."
        fi
    fi
    
    # Check for SOLID principles violations
    if echo "$patch" | grep -q "class.*:\s*[A-Za-z,\s]*{" && echo "$patch" | grep -qE "(final|private|internal|public).*class"; then
        if ! echo "$patch" | grep -q "protocol"; then
            post_review_comment "$filename" "$line_num" "🏗️ **SOLID Principles**: Consider using protocols for dependency injection and better testability. Classes should depend on abstractions, not concretions."
        fi
    fi
    
    # Check for force unwrapping
    if echo "$patch" | grep -q "!"; then
        post_review_comment "$filename" "$line_num" "⚠️ **Swift Safety**: Avoid force unwrapping. Use optional binding, nil coalescing operator, or guard statements for safer code."
    fi
    
    # Check for proper naming conventions
    if echo "$patch" | grep -qE "func [a-z][A-Z]|var [a-z][A-Z]|let [a-z][A-Z]"; then
        post_review_comment "$filename" "$line_num" "📝 **Swift Naming Convention**: Use camelCase for functions and variables. Start with lowercase letter."
    fi
    
    # Check for Swinject dependency injection pattern
    if echo "$patch" | grep -q "init.*:.*=" && ! echo "$patch" | grep -q "Container\|Resolver"; then
        post_review_comment "$filename" "$line_num" "🔧 **Dependency Injection**: Consider using Swinject for dependency injection to improve testability and follow project architecture."
    fi
    
    # Check for missing documentation on public APIs
    if echo "$patch" | grep -qE "public\s+(class|struct|func|var|let)" && ! echo "$patch" | grep -qB3 "///"; then
        post_review_comment "$filename" "$line_num" "📖 **Documentation**: Public APIs should have comprehensive documentation using /// comments."
    fi
    
    # Check for async/await best practices
    if echo "$patch" | grep -q "async" && echo "$patch" | grep -q "throws"; then
        if ! echo "$patch" | grep -q "async throws"; then
            post_review_comment "$filename" "$line_num" "⚡ **Async/Await**: When a function is both async and throws, use 'async throws' order for consistency."
        fi
    fi
    
    # Check for proper error handling
    if echo "$patch" | grep -q "try!" || echo "$patch" | grep -q "try?"; then
        post_review_comment "$filename" "$line_num" "🛡️ **Error Handling**: Consider proper error handling with do-catch blocks instead of force try or optional try."
    fi
    
    # Check for SwiftUI best practices
    if echo "$patch" | grep -q "@StateObject\|@ObservedObject\|@State"; then
        if echo "$patch" | grep -q "class.*ObservableObject" && ! echo "$patch" | grep -q "@MainActor"; then
            post_review_comment "$filename" "$line_num" "🎭 **SwiftUI Convention**: ObservableObject classes should be marked with @MainActor for thread safety."
        fi
    fi
}

# Function to analyze and review code
analyze_and_review() {
    local filename="$1"
    local patch="$2"
    local additions="$3"
    local deletions="$4"
    
    echo "🔍 Analyzing: $filename"
    
    # Extract line numbers for added lines
    local line_numbers=$(echo "$patch" | grep -n "^+" | grep -v "^+++" | head -5 | cut -d: -f1)
    
    # Apply Swift-specific conventions if it's a Swift file
    if [[ "$filename" == *.swift ]]; then
        echo "🐦 Applying Swift conventions analysis..."
        
        # Get first line number for Swift-specific comments
        local first_line_num=$(echo "$line_numbers" | head -1)
        if [ -z "$first_line_num" ]; then
            first_line_num=1
        fi
        
        check_swift_conventions "$filename" "$patch" "$first_line_num"
        
        # Additional Swift-specific checks
        if echo "$patch" | grep -q "ViewModel\|ViewController"; then
            if ! echo "$patch" | grep -q "@MainActor"; then
                post_review_comment "$filename" "$first_line_num" "🎯 **SwiftUI Architecture**: ViewModels should be marked with @MainActor to ensure UI updates happen on the main thread."
            fi
        fi
        
        # Check for proper use of computed properties
        if echo "$patch" | grep -qE "var.*:\s*[A-Za-z]+\s*{" && echo "$patch" | grep -q "return"; then
            post_review_comment "$filename" "$first_line_num" "✨ **Swift Optimization**: For single-expression computed properties, consider using implicit return for cleaner code."
        fi
        
    elif [[ "$filename" == *Test*.swift || "$filename" == *Tests.swift ]]; then
        echo "🧪 Applying Swift Testing conventions..."
        
        # Check for proper test structure
        if ! echo "$patch" | grep -q "@Suite\|@Test"; then
            post_review_comment "$filename" "1" "🧪 **Swift Testing Framework**: Use Swift Testing framework with @Suite and @Test annotations instead of XCTest."
        fi
        
        # Check for descriptive test names
        if echo "$patch" | grep -q "@Test func test" && ! echo "$patch" | grep -q "@Test(\""; then
            local test_line=$(echo "$patch" | grep -n "@Test func" | head -1 | cut -d: -f1)
            post_review_comment "$filename" "$test_line" "📝 **Test Naming**: Use descriptive test names with @Test(\"Description\") format for better test documentation."
        fi
        
        # Check for #expect usage
        if echo "$patch" | grep -q "XCTAssert"; then
            local assert_line=$(echo "$patch" | grep -n "XCTAssert" | head -1 | cut -d: -f1)
            post_review_comment "$filename" "$assert_line" "✅ **Swift Testing Assertion**: Use #expect() instead of XCTAssert for Swift Testing framework."
        fi
        
    elif [[ "$filename" == *.md ]]; then
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
echo "🎯 Analyzing code patterns, security, Swift conventions, and best practices"
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
echo "   • Focus areas: Swift conventions, Security, Best practices, Code quality"
echo "   • Swift conventions source: swift-conventions.mdc"
echo "   • Comments posted: Check PR on GitHub"
echo ""
echo "🌐 View PR with comments: https://github.com/swiftymind/CodeRabbitTest/pull/$PR_NUMBER"
echo ""
echo "💡 This automated review supplements human review - always verify suggestions!" 