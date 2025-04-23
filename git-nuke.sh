#!/bin/bash

REPO_NAME=${1:-$(basename $(pwd))}
USERNAME=$(gh api user --jq .login)

echo "🔥 Initializing repo: $REPO_NAME for $USERNAME"

# Create files
echo "# $REPO_NAME" > README.md
echo ".DS_Store" > .gitignore

# Init + commit
git init
git add .
git commit -m "🔥 Initial commit"

# Create GH repo
gh repo create "$REPO_NAME" --public --source=. --remote=origin --push

echo "✅ Pushed to GitHub: https://github.com/$USERNAME/$REPO_NAME"