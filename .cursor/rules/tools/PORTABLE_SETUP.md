# 🚀 Portable PR Review System Setup

This guide shows you how to use the automated PR review system across different iOS projects.

## 📁 Quick Setup (Copy & Paste)

### 1. Copy Required Files

Copy this entire directory structure to your new iOS project:

```bash
# Copy the entire .cursor/rules directory
cp -r /path/to/source/project/.cursor/rules /path/to/new/project/.cursor/
```

### 2. Required Files Structure

```
your-ios-project/
└── .cursor/
    └── rules/
        ├── swift-conventions.mdc          # Swift coding standards
        ├── github-pr-review.mdc           # PR review guidelines
        ├── memory-management.mdc          # iOS memory management rules
        └── tools/
            ├── review-pr.sh               # ✅ Main review script (auto-detects repo)
            ├── gh-pr-comment.sh           # GitHub API integration
            ├── pr-review-aliases.sh       # ✅ Shell aliases (auto-detects repo)
            ├── pr-review-aliases.fish     # Fish shell aliases
            ├── PR_REVIEW_README.md        # Documentation
            └── PORTABLE_SETUP.md          # This file
```

## ⚙️ Prerequisites

### Required Tools
```bash
# Install GitHub CLI
brew install gh

# Install jq for JSON parsing
brew install jq

# Authenticate with GitHub
gh auth login
```

### Shell Setup (Optional)
```bash
# Add to your ~/.bashrc or ~/.zshrc
source /path/to/your/project/.cursor/rules/tools/pr-review-aliases.sh
```

## 🎯 Zero Configuration Required!

**The system automatically detects:**
- ✅ Repository owner/name from `git remote`
- ✅ GitHub URL (supports SSH and HTTPS)
- ✅ Project-specific Swift conventions

**No hardcoded values!** Works immediately in any GitHub repository.

## 📋 Usage

### Basic Review
```bash
# Navigate to your iOS project
cd /path/to/your/ios/project

# Review any PR by number
./.cursor/rules/tools/review-pr.sh 4

# Using aliases (if sourced)
review-pr 4
rpr 4                    # Short alias
```

### List PRs
```bash
# Using aliases
list-prs                 # Lists all open PRs
lpr                      # Short alias
```

### Check Setup
```bash
# Source aliases and run setup check
source .cursor/rules/tools/pr-review-aliases.sh
setup-pr-review
```

## 🔧 Customization Options

### 1. Swift Conventions
Edit `.cursor/rules/swift-conventions.mdc` to add project-specific rules:

```markdown
# Your Custom Swift Rules

## Project-Specific Conventions
- Use specific naming patterns
- Custom architecture requirements
- Team-specific best practices
```

### 2. Review Focus Areas
The script automatically checks:
- ✅ Swift Testing framework usage
- ✅ Force unwrapping safety
- ✅ Memory management
- ✅ SOLID principles
- ✅ SwiftUI best practices
- ✅ Error handling patterns

### 3. Add Custom Checks
Edit `review-pr.sh` to add project-specific pattern detection:

```bash
# Example: Check for custom architectural patterns
if echo "$patch" | grep -q "YourCustomPattern"; then
    local line_num=$(extract_line_numbers_from_patch "$patch" "YourCustomPattern")
    if [ -n "$line_num" ]; then
        post_review_comment "$filename" "$line_num" "🏗️ **Custom Rule**: Your custom message here."
    fi
fi
```

## 🌟 Features

### Automatic Repository Detection
- Parses `git remote get-url origin`
- Supports GitHub SSH and HTTPS URLs
- Works with any GitHub repository

### Precise Line Number Detection
- Parses diff headers correctly
- Comments on exact problematic code lines
- No more generic file header comments

### Swift-First Design
- Built specifically for iOS/Swift projects
- Follows Swift Testing framework conventions
- Integrates iOS memory management best practices

### Security
- No hardcoded tokens
- Uses GitHub CLI authentication
- Environment variable support

## 🔍 Verification

Test the setup in your new project:

```bash
# 1. Check repository detection
git remote get-url origin

# 2. Test PR listing
./.cursor/rules/tools/review-pr.sh

# 3. Review a test PR
./.cursor/rules/tools/review-pr.sh <PR_NUMBER>
```

## 📚 Documentation Files

- **`swift-conventions.mdc`** - Swift coding standards and conventions
- **`github-pr-review.mdc`** - PR review process and guidelines  
- **`memory-management.mdc`** - iOS-specific memory management rules
- **`PR_REVIEW_README.md`** - Detailed tool documentation

## 🚀 Ready to Use!

The system is now **100% portable** and requires **zero configuration**. Simply copy the files and start reviewing PRs in any iOS project!

```bash
# That's it! Start reviewing:
./.cursor/rules/tools/review-pr.sh 1
``` 