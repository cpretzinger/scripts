#!/bin/bash

REPO_NAME=${1:-$(basename $(pwd))}
USERNAME=$(gh api user --jq .login)

echo "💦 PUSHING HARD into GitHub as $USERNAME, repo: $REPO_NAME"

# Step 1: Prep the essentials
echo "# $REPO_NAME" > README.md
cat <<EOL > .gitignore
node_modules/
.env
.DS_Store
dist/
.next/
out/
build/
coverage/
*.log
*.sqlite
EOL

# Step 2: Git init and first commit
git init
git add .
git commit -m "💥 pushhard: first commit, repo cleansed"

# Step 3: Create repo + push
gh repo create "$REPO_NAME" --public --source=. --remote=origin --push

echo "✅ Repo pushed hard at: https://github.com/$USERNAME/$REPO_NAME"
echo "💣 Repo has been CLEANSED & SENT DEEP into the GitHub abyss."