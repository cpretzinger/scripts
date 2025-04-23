#!/bin/bash

REPO_NAME=${1:-$(basename "$(pwd)")}
USERNAME=$(gh api user --jq .login 2>/dev/null)

echo "💦 PUSHING HARD (and PRIVATE) into GitHub as $USERNAME, repo: $REPO_NAME"

# Step 1: Setup .gitignore + README
[ -f README.md ] || echo "# $REPO_NAME" > README.md

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

# Optional: remove garbage from tracking if it slipped in
git rm -r --cached node_modules/ dist/ .next/ out/ build/ coverage/ .env .DS_Store 2>/dev/null

# Step 2: Init Git if needed
if [ ! -d .git ]; then
  git init
  git add .
  git commit -m "💥 pushhard: first commit, repo cleansed"
else
  echo "📦 Git repo already exists. Continuing..."
fi

# Step 3: Create private GitHub repo if no remote exists
if ! git remote | grep -q origin; then
  echo "🔒 Creating PRIVATE GitHub repo via gh CLI..."
  gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
else
  echo "🔁 Remote already exists. Pulling & pushing updates..."

  # Pull latest to avoid push errors
  git fetch origin main 2>/dev/null

  STATUS=$(git status -sb)

  if [[ $STATUS == *"ahead"* && $STATUS == *"behind"* ]]; then
    echo "❌ Branch has diverged. Manual fix needed. PushHard aborted."
    exit 1
  elif [[ $STATUS == *"behind"* ]]; then
    echo "📥 Behind remote. Pulling updates..."
    git pull origin main --rebase
  fi

  # Add + commit if changes exist
  git add .
  git diff --cached --quiet || git commit -m "🔁 pushhard: update"

  # Final push
  git push origin main
fi

echo "✅ Private repo is live at: https://github.com/$USERNAME/$REPO_NAME"
echo "🔒 PushHard complete. Repo secured. GitHub respected."
