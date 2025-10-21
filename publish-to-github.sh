#!/bin/bash
# Script to publish data-discovery-infrastructure-gcp to GitHub

set -e

echo "🚀 Publishing data-discovery-infrastructure-gcp to GitHub"
echo "=========================================================="
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ Error: GitHub username is required"
    exit 1
fi

echo ""
echo "📝 Repository URL will be:"
echo "   https://github.com/${GITHUB_USERNAME}/data-discovery-infrastructure-gcp"
echo ""

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -f "LICENSE" ]; then
    echo "❌ Error: Please run this script from the data-discovery-infrastructure-gcp directory"
    exit 1
fi

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "❌ Error: Git repository not initialized"
    exit 1
fi

# Check if we have commits
if ! git log -1 > /dev/null 2>&1; then
    echo "❌ Error: No commits found. Please commit your changes first."
    exit 1
fi

echo "✅ Git repository verified"
echo ""

# Ask about remote method
echo "Choose authentication method:"
echo "  1) HTTPS (recommended - works everywhere)"
echo "  2) SSH (requires SSH keys configured)"
read -p "Select [1 or 2]: " AUTH_METHOD

if [ "$AUTH_METHOD" = "2" ]; then
    REPO_URL="git@github.com:${GITHUB_USERNAME}/data-discovery-infrastructure-gcp.git"
else
    REPO_URL="https://github.com/${GITHUB_USERNAME}/data-discovery-infrastructure-gcp.git"
fi

echo ""
echo "⚠️  IMPORTANT: Before continuing, create the repository on GitHub:"
echo ""
echo "   1. Go to: https://github.com/new"
echo "   2. Repository name: data-discovery-infrastructure-gcp"
echo "   3. Visibility: Public"
echo "   4. DO NOT initialize with README, .gitignore, or license"
echo "   5. Click 'Create repository'"
echo ""
read -p "Have you created the repository on GitHub? [y/N]: " REPO_CREATED

if [ "$REPO_CREATED" != "y" ] && [ "$REPO_CREATED" != "Y" ]; then
    echo ""
    echo "Please create the repository on GitHub first, then run this script again."
    echo "Or create it via GitHub CLI:"
    echo ""
    echo "  gh repo create data-discovery-infrastructure-gcp \\"
    echo "    --public \\"
    echo "    --description \"Production-ready Terraform infrastructure for data discovery systems on GCP\" \\"
    echo "    --source=. \\"
    echo "    --remote=origin"
    echo ""
    exit 0
fi

echo ""
echo "🔗 Adding GitHub remote..."

# Remove existing origin if it exists
if git remote get-url origin > /dev/null 2>&1; then
    echo "   Removing existing origin remote..."
    git remote remove origin
fi

# Add the new remote
git remote add origin "$REPO_URL"

echo "✅ Remote added successfully"
echo ""

# Verify remote
echo "📋 Remote configuration:"
git remote -v
echo ""

# Ask before pushing
read -p "Ready to push to GitHub? [y/N]: " PUSH_CONFIRM

if [ "$PUSH_CONFIRM" != "y" ] && [ "$PUSH_CONFIRM" != "Y" ]; then
    echo ""
    echo "Push cancelled. You can push manually later with:"
    echo "  git push -u origin main"
    exit 0
fi

echo ""
echo "📤 Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ Successfully published to GitHub!"
echo ""
echo "🎉 Your repository is now live at:"
echo "   https://github.com/${GITHUB_USERNAME}/data-discovery-infrastructure-gcp"
echo ""
echo "📋 Next steps:"
echo "   1. Add topics/tags to your repository (see GITHUB_SETUP.md)"
echo "   2. Enable Issues and Discussions"
echo "   3. Share your repository with the community!"
echo ""
echo "For detailed instructions, see: GITHUB_SETUP.md"

