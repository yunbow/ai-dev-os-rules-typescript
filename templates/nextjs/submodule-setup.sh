#!/bin/bash
set -euo pipefail

# ============================================================
# ai-dev-os Submodule Setup Script
#
# Usage:
#   cd /path/to/your-project
#   bash /path/to/ai-dev-os/templates/nextjs/submodule-setup.sh
#
# Or specify the ai-dev-os repo on GitHub:
#   AI_DEV_OS_REPO=https://github.com/your-org/ai-dev-os.git \
#   bash /path/to/submodule-setup.sh
# ============================================================

# Configuration
AI_DEV_OS_REPO="${AI_DEV_OS_REPO:-https://github.com/your-org/ai-dev-os.git}"
SUBMODULE_PATH="docs/ai-dev-os"
TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== ai-dev-os Setup ==="
echo "Repository: $AI_DEV_OS_REPO"
echo "Destination: $SUBMODULE_PATH"
echo ""

# Check if current directory is a Git repository
if [ ! -d ".git" ]; then
  echo "Error: The current directory is not a Git repository"
  echo "   Please run this from the project root"
  exit 1
fi

# Add submodule
if [ -d "$SUBMODULE_PATH" ]; then
  echo "$SUBMODULE_PATH already exists. Skipping."
else
  echo "Adding submodule..."
  git submodule add "$AI_DEV_OS_REPO" "$SUBMODULE_PATH"
  git submodule update --init
  echo "Submodule added successfully"
fi

echo ""

# Copy template files
copy_if_not_exists() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ]; then
    echo "$dst already exists. Skipping."
  else
    cp "$src" "$dst"
    echo "Created $dst"
  fi
}

copy_dir_if_not_exists() {
  local src="$1"
  local dst="$2"
  if [ -d "$dst" ]; then
    echo "$dst already exists. Skipping."
  else
    cp -r "$src" "$dst"
    echo "Created $dst"
  fi
}

echo "Copying template files..."

# CLAUDE.md
copy_if_not_exists "$TEMPLATE_DIR/CLAUDE.md.template" "./CLAUDE.md"

# Configuration files
copy_if_not_exists "$TEMPLATE_DIR/tsconfig.json" "./tsconfig.json"
copy_if_not_exists "$TEMPLATE_DIR/eslint.config.mjs" "./eslint.config.mjs"
copy_if_not_exists "$TEMPLATE_DIR/prettier.config.js" "./prettier.config.js"
copy_if_not_exists "$TEMPLATE_DIR/postcss.config.mjs" "./postcss.config.mjs"
copy_if_not_exists "$TEMPLATE_DIR/.gitignore" "./.gitignore"

# Claude Code skills
mkdir -p .claude/skills
copy_dir_if_not_exists "$TEMPLATE_DIR/.claude/skills/commit" ".claude/skills/commit"
copy_dir_if_not_exists "$TEMPLATE_DIR/.claude/skills/guideline-checker" ".claude/skills/guideline-checker"
copy_dir_if_not_exists "$TEMPLATE_DIR/.claude/skills/type-check" ".claude/skills/type-check"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit the project name and project-specific guidelines in CLAUDE.md"
echo "  2. Configure next.config.ts using next.config.ts.template as a reference"
echo "  3. Add dependencies to package.json using package.json.template as a reference"
echo "  4. Run npm install"
