#!/bin/bash

REPO_NAME=${1:-$(basename "$(pwd)")}
USERNAME=$(gh api user --jq .login 2>/dev/null)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

echo "💦 PUSHING HARD (BRANCH-AWARE) into GitHub as $USERNAME, repo: $REPO_NAME"
echo "🌿 Current branch: $CURRENT_BRANCH"

# ───────────────────────────────────── Privacy prompt
read -p "🔒 Do you want to push as a private repository? (Y/n): " PRIVATE_REPO
PRIVATE_REPO=$(echo "$PRIVATE_REPO" | tr '[:upper:]' '[:lower:]')

if [[ "$PRIVATE_REPO" == "n" || "$PRIVATE_REPO" == "no" ]]; then
  read -p "⚠️ Confirm you wish to push as a PUBLIC repository? (y/N): " CONFIRM_PUBLIC
  CONFIRM_PUBLIC=$(echo "$CONFIRM_PUBLIC" | tr '[:upper:]' '[:lower:]')
  
  if [[ "$CONFIRM_PUBLIC" != "y" && "$CONFIRM_PUBLIC" != "yes" ]]; then
    echo "❌ Operation cancelled. Exiting."
    exit 1
  fi
  IS_PRIVATE=false
else
  IS_PRIVATE=true
fi

# ───────────────────────────────────── Commit message
read -p "📝 Enter commit message: " USER_COMMIT_MSG
if [[ -z "$USER_COMMIT_MSG" ]]; then
  USER_COMMIT_MSG="💥 pushhard: auto-commit"
  echo "Using default commit message: $USER_COMMIT_MSG"
fi

# ───────────────────────────────────── README
if [ ! -f README.md ]; then
  echo "📝 No README.md found. Let's create one..."
  
  # Ask for project description
  read -p "📋 Enter a brief project description (or press Enter for default): " PROJECT_DESCRIPTION
  
  if [[ -z "$PROJECT_DESCRIPTION" ]]; then
    # Look for clues about the project
    if [ -f package.json ]; then
      PROJECT_DESCRIPTION=$(grep -m 1 '"description"' package.json | cut -d '"' -f 4)
      echo "📦 Found description in package.json: $PROJECT_DESCRIPTION"
    elif [ -f pyproject.toml ]; then
      PROJECT_DESCRIPTION=$(grep -m 1 'description' pyproject.toml | cut -d '"' -f 2)
      echo "🐍 Found description in pyproject.toml: $PROJECT_DESCRIPTION"
    else
      # Default description if nothing is found
      PROJECT_DESCRIPTION="A collection of scripts and tools."
      echo "Using default description: $PROJECT_DESCRIPTION"
    fi
  fi
  
  # Create README with the description
  cat <<EOL > README.md
# 🚀 $REPO_NAME

$PROJECT_DESCRIPTION

> Managed with PushHard™ 💦

## Features
- 🔒 ${IS_PRIVATE:+Private repository}${IS_PRIVATE:-Public repository}
- 🧼 Auto-untracks common ignored files (.env, node_modules)
- 🐙 Seamlessly deploys to GitHub
- 🔁 Handles Git branch management
EOL
  echo "✅ Created new README.md with project description"
else
  echo "📄 Existing README.md found - preserving content"
fi

# ───────────────────────────────────── .gitignore
cat <<EOL > .gitignore
.env
.env.local
node_modules/
.DS_Store
dist/
.next/
out/
build/
coverage/
*.log
*.sqlite
EOL

# ───────────────────────────────────── Clean tracked trash
git rm -r --cached node_modules/ dist/ .next/ out/ build/ coverage/ .env .env.local .DS_Store 2>/dev/null

# ───────────────────────────────────── Init repo if absent
if [ ! -d .git ]; then
  echo "🧬 No Git found — initializing…"
  git init
  git checkout -b "$CURRENT_BRANCH"
  git add .
  git commit -m "$USER_COMMIT_MSG"
else
  echo "📦 Git repo already exists. Continuing…"
fi

# ───────────────────────────────────── Create repo if no origin
if ! git remote | grep -q origin; then
  if [ "$IS_PRIVATE" = true ]; then
    echo "🔒 Creating PRIVATE GitHub repo via gh CLI…"
    gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
  else
    echo "🌐 Creating PUBLIC GitHub repo via gh CLI…"
    gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
  fi
else
  echo "🔁 Remote already exists. Checking for updates…"

  # ───── Ensure origin URL belongs to current user
  REMOTE_URL=$(git remote get-url origin 2>/dev/null)
  if [[ "$REMOTE_URL" != *"$USERNAME"* ]]; then
    echo "⚠️  origin is $REMOTE_URL — repointing to git@github.com:$USERNAME/$REPO_NAME.git"
    git remote set-url origin git@github.com:$USERNAME/$REPO_NAME.git
  fi

  git fetch origin "$CURRENT_BRANCH" 2>/dev/null
  STATUS=$(git status -sb)

  if [[ $STATUS == *"ahead"* && $STATUS == *"behind"* ]]; then
    echo "❌ Branch has diverged. Manual fix needed. PushHard aborted."
    exit 1
  elif [[ $STATUS == *"behind"* ]]; then
    echo "📥 Behind remote. Pulling updates…"
    git pull origin "$CURRENT_BRANCH" --rebase
  fi

  echo "🔍 Git status before commit:"
  git status

  # ───── Stage everything
  git add -A

  if ! git diff --cached --quiet; then
    echo "📦 Committing updates…"
    
    # Generate appropriate commit message based on changes
    CHANGED_FILES=$(git diff --cached --name-status)
    ADDED_COUNT=$(echo "$CHANGED_FILES" | grep -c "^A")
    MODIFIED_COUNT=$(echo "$CHANGED_FILES" | grep -c "^M")
    DELETED_COUNT=$(echo "$CHANGED_FILES" | grep -c "^D")
    
    # Create descriptive commit message
    COMMIT_MSG="🔁 pushhard: "
    if [[ $ADDED_COUNT -gt 0 ]]; then
      COMMIT_MSG+="add $ADDED_COUNT file(s) "
    fi
    if [[ $MODIFIED_COUNT -gt 0 ]]; then
      COMMIT_MSG+="update $MODIFIED_COUNT file(s) "
    fi
    if [[ $DELETED_COUNT -gt 0 ]]; then
      COMMIT_MSG+="remove $DELETED_COUNT file(s) "
    fi
    
    # Add some key files to the message if present
    if echo "$CHANGED_FILES" | grep -q "package.json"; then
      COMMIT_MSG+="(deps updated) "
    fi
    if echo "$CHANGED_FILES" | grep -q "\.js\|\.ts\|\.jsx\|\.tsx"; then
      COMMIT_MSG+="(code changes) "
    fi
    
    # Use user-provided commit message instead of auto-generated one
    echo "📝 Using commit message: $USER_COMMIT_MSG"
    git commit -m "$USER_COMMIT_MSG"
    git push origin "$CURRENT_BRANCH"
  else
    echo "🟢 Nothing new to commit. Checking README just in case…"
    git add README.md
    if ! git diff --cached --quiet; then
      echo "📄 README.md was updated — committing forcefully."
      git commit -m "$USER_COMMIT_MSG"
      git push origin "$CURRENT_BRANCH"
    else
      echo "✔️  Confirmed: no detectable changes. Repo fully synced."
    fi
  fi
fi

VISIBILITY=$([ "$IS_PRIVATE" = true ] && echo "private" || echo "public")
echo "✅ $VISIBILITY repo is live at: https://github.com/$USERNAME/$REPO_NAME/tree/$CURRENT_BRANCH"
echo "🔒 PushHard complete. GitHub respected. Swagger intact."

# Update README.md with project summary without overwriting existing content
if [ -f README.md ]; then
  # Check if README already has a pushhard tag section
  if grep -q "<!-- PUSHHARD-TAG -->" README.md; then
    # Remove the existing pushhard tag section
    sed -i.bak '/<!-- PUSHHARD-TAG -->/,/<!-- END-PUSHHARD-TAG -->/d' README.md
    rm -f README.md.bak
  fi
  
  # Get project summary
  REPO_DESCRIPTION=$(gh repo view "$USERNAME/$REPO_NAME" --json description --jq .description 2>/dev/null || echo "")
  FILE_COUNT=$(find . -type f -not -path "*/\.*" -not -path "*/node_modules/*" | wc -l | tr -d ' ')
  LAST_COMMIT=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "No commits yet")
  
  # Append pushhard tag and project summary to README
  cat <<EOL >> README.md

<!-- PUSHHARD-TAG -->
## 📊 Project Status
- Repository: $REPO_NAME
- Branch: $CURRENT_BRANCH
- Files: $FILE_COUNT
- Last Update: $(date "+%Y-%m-%d %H:%M")
- Last Commit: $LAST_COMMIT
${REPO_DESCRIPTION:+- Description: $REPO_DESCRIPTION}

> *This section was auto-generated by PushHard™*
<!-- END-PUSHHARD-TAG -->
EOL
fi

# Add pushhard tag to terminal output
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏷️  PUSHHARD TAG | $(date "+%Y-%m-%d %H:%M") | $REPO_NAME | $CURRENT_BRANCH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"