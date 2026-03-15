# Project Templates

## Overview

A collection of templates for quickly bootstrapping new projects that comply with ai-dev-os guidelines.

## Available Templates

| Template | Tech Stack | Use Case |
|----------|-----------|----------|
| `nextjs/` | Next.js (App Router) + TypeScript + Prisma + Tailwind | Full-stack web app |

> New framework templates should be added under `templates/{framework}/`.

## Usage

### 1. Create a New Project

```bash
# For a Next.js project
npx create-next-app@latest my-project
cd my-project
```

### 2. Add ai-dev-os as a Submodule

```bash
# Using submodule-setup.sh (recommended)
bash /path/to/ai-dev-os/templates/nextjs/submodule-setup.sh

# Or manually
git submodule add https://github.com/yunbow/ai-dev-os.git docs/ai-dev-os
git submodule update --init
```

### 3. Copy Template Files

```bash
# CLAUDE.md
cp docs/ai-dev-os/templates/nextjs/CLAUDE.md.template ./CLAUDE.md

# Configuration files
cp docs/ai-dev-os/templates/nextjs/tsconfig.json ./tsconfig.json
cp docs/ai-dev-os/templates/nextjs/eslint.config.mjs ./eslint.config.mjs
cp docs/ai-dev-os/templates/nextjs/prettier.config.js ./prettier.config.js
cp docs/ai-dev-os/templates/nextjs/postcss.config.mjs ./postcss.config.mjs
cp docs/ai-dev-os/templates/nextjs/.gitignore ./.gitignore

# Claude Code skills
cp -r docs/ai-dev-os/templates/nextjs/.claude/ ./.claude/
```

### 4. Edit Project-Specific Settings

- Update the project name and project-specific guideline paths in `CLAUDE.md`
- Configure `remotePatterns` in `next.config.ts` to match your project
- Adjust the project name and dependencies in `package.json`
- Customize skill definitions in `.claude/skills/` to match your project

## Updating Templates

When templates are updated, existing projects are not automatically affected.
Apply updates to existing projects manually (review the diff and merge).

## Adding New Templates

```
templates/{framework}/
├── README.md               # Template description
├── submodule-setup.sh      # Submodule setup script
├── CLAUDE.md.template      # CLAUDE.md template
├── .claude/                # Claude Code skill definitions
│   └── skills/
├── .gitignore              # gitignore template
└── {config files}          # Framework-specific configuration
```
