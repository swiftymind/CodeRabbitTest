# 🤖 Automated PR Review System

This repository includes an automated Pull Request review system that can analyze code changes and post review comments directly to GitHub PRs.

## 📋 Overview

The system consists of two main components:
- **Core Script**: `.cursor/rules/tools/gh-pr-comment.sh` - Posts individual review comments
- **Main Workflow**: `.cursor/rules/tools/review-pr.sh` - Orchestrates the complete review process

## 🚀 Quick Start

### Prerequisites

1. **GitHub CLI Authentication**
   ```bash
   gh auth login
   ```

2. **Required Tools**
   - `curl` (for API calls)
   - `jq` (for JSON parsing)
   - `git` (for repository operations)

### Basic Usage

#### Option 1: Simple Review (Recommended)
```bash
# Review any open PR
./.cursor/rules/tools/review-pr.sh <PR_NUMBER>

# Examples:
./.cursor/rules/tools/review-pr.sh 1
./.cursor/rules/tools/review-pr.sh 2
```

#### Option 2: Using Aliases (Even Easier!)
```bash
# Load aliases first
source ./.cursor/rules/tools/pr-review-aliases.fish  # For fish shell
# or
source ./.cursor/rules/tools/pr-review-aliases.sh    # For bash/zsh

# Then use simple commands
review-pr 1        # Review PR #1
review-pr 2        # Review PR #2  
list-prs           # Show available PRs
```

#### Option 3: Manual Comment Posting
```bash
# Post individual review comments
./.cursor/rules/tools/gh-pr-comment.sh pr review <PR_NUMBER> \
  --comment -b "Your review comment here" \
  --path "path/to/file.swift" \
  --line 42
```

## 📖 Detailed Usage

### 1. List Available PRs
```bash
# The review-pr.sh script will show available PRs if no number is provided
./.cursor/rules/tools/review-pr.sh

# Or with alias
list-prs
```

### 2. Review Specific PR
```bash
# Review PR #1 (Base SwiftUI Project)
./.cursor/rules/tools/review-pr.sh 1

# Review PR #2 (PR Reviewer Scripts)  
./.cursor/rules/tools/review-pr.sh 2

# Or with aliases
review-pr1   # Quick review PR #1
review-pr2   # Quick review PR #2
```

### 3. Custom Review Comments
```bash
# Add a custom comment to a specific line
./.cursor/rules/tools/gh-pr-comment.sh pr review 2 \
  --comment -b "Consider using async/await for better error handling" \
  --path "GitHubExplorer/APIService.swift" \
  --line 25

# Or with alias
pr-comment 2 --comment -b "Your comment" --path "file.swift" --line 25
```

## 🐚 Shell Compatibility

The system supports multiple shells:

### Fish Shell (Current)
```fish
source ./.cursor/rules/tools/pr-review-aliases.fish
review-pr 2
```

### Bash/Zsh
```bash
source ./.cursor/rules/tools/pr-review-aliases.sh
review-pr 2
```

## 🔧 Configuration

### GitHub Token Setup

The system requires a GitHub token for API access. The token is configured in:
```
.cursor/rules/tools/gh-pr-comment.sh
```

**⚠️ Security Note**: The current setup includes the token in the script. For production use, consider:
- Using environment variables
- GitHub CLI authentication (recommended)
- GitHub Actions secrets

### Customizing Review Rules

Edit `.cursor/rules/tools/review-pr.sh` to add specific review logic for different PRs:

```bash
case $PR_NUMBER in
    3)
        echo "📋 Reviewing PR #3: New Feature"
        echo "🎯 Focus: Security, Performance"
        
        "$SCRIPT_DIR/gh-pr-comment.sh" pr review 3 \
          --comment -b "Your review comment" \
          --path "path/to/file.swift" \
          --line 10
        ;;
esac
```

## 📁 File Structure

```
.cursor/rules/
├── tools/
│   ├── gh-pr-comment.sh      # Core comment posting script
│   └── review-pr.sh          # Main review orchestration script
├── github-pr-review.mdc      # Review guidelines
└── PR_REVIEW_README.md       # This documentation
```

## 🎯 Review Focus Areas

### PR #1: Base SwiftUI Project
- **Focus**: API Service, Architecture, Foundation
- **Areas**: Error handling, URL construction, Network reliability

### PR #2: PR Reviewer Scripts  
- **Focus**: Error handling, Performance, Code quality
- **Areas**: Input validation, Search optimization, Security

### Custom PRs
- Add your own review logic in the case statement
- Focus on specific areas relevant to the changes

## 🔍 Example Workflows

### Daily PR Review Routine
```bash
# 1. Check what PRs are open
./.cursor/rules/tools/review-pr.sh

# 2. Review each open PR
./.cursor/rules/tools/review-pr.sh 1
./.cursor/rules/tools/review-pr.sh 2

# 3. Check results on GitHub
# Visit: https://github.com/swiftymind/CodeRabbitTest/pulls
```

### Adding New Review Comments
```bash
# Review code quality issues
./.cursor/rules/tools/gh-pr-comment.sh pr review 1 \
  --comment -b "Consider extracting this into a separate function for better testability" \
  --path "GitHubExplorer/ViewModel.swift" \
  --line 45

# Review security concerns  
./.cursor/rules/tools/gh-pr-comment.sh pr review 2 \
  --comment -b "Input validation needed here to prevent injection attacks" \
  --path "GitHubExplorer/SearchService.swift" \
  --line 23
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Error**
   ```
   Error: Could not fetch the latest commit ID for PR #X
   ```
   **Solution**: Check GitHub CLI authentication with `gh auth status`

2. **JSON Parsing Error**
   ```
   Problems parsing JSON
   ```
   **Solution**: Escape special characters in comments, avoid quotes in review text

3. **Permission Denied**
   ```
   bash: permission denied
   ```
   **Solution**: Make scripts executable with `chmod +x .cursor/rules/tools/*.sh`

### Debug Mode
```bash
# Enable verbose output
bash -x ./.cursor/rules/tools/review-pr.sh 1

# Check API response
cat response.json  # (after running gh-pr-comment.sh)
```

## 📈 Best Practices

### 1. Review Guidelines
- Focus on **actionable feedback**
- Avoid **style comments** (use linters instead)
- Highlight **security concerns**
- Suggest **performance improvements**
- Point out **potential bugs**

### 2. Comment Quality
- Be **specific** and **constructive**
- Provide **alternative solutions**
- Reference **documentation** when helpful
- Keep comments **concise** but **clear**

### 3. Automation Strategy
- **Customize** review rules per PR type
- **Focus** on high-impact issues
- **Supplement** (don't replace) human review
- **Update** rules based on team feedback

## 🔄 Integration with Development Workflow

### Pre-commit Hook
```bash
# Add to .git/hooks/pre-push
#!/bin/bash
echo "🤖 Running automated PR review..."
./.cursor/rules/tools/review-pr.sh $(gh pr view --json number -q .number)
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Automated PR Review
  run: |
    ./.cursor/rules/tools/review-pr.sh ${{ github.event.pull_request.number }}
```

## 📚 References

- [GitHub REST API - Pull Request Comments](https://docs.github.com/en/rest/pulls/comments)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Cursor Rules Documentation](https://docs.cursor.com/rules)

## 🤝 Contributing

To improve the review system:

1. **Add new review rules** in `review-pr.sh`
2. **Enhance comment templates** for common issues
3. **Improve error handling** in scripts
4. **Add more automated checks** for code quality

---

**Made with ❤️ for better code reviews** 