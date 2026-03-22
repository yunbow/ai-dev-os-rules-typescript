---
name: commit
description: Standardize commit creation. Review changes, generate an appropriate commit message, and execute the commit.
allowed-tools: Bash, Read, Grep
---

# Commit Creation Skill

A skill that reviews changes and creates commits following the project's commit conventions.

## When to Execute

- When committing after implementation is complete
- When requested with "commit", etc.

## Execution Steps

### 1. Review Changes

```bash
git status
git diff
git diff --staged
git log --oneline -5
```

### 2. Commit Message Format

```text
<type>(<scope>): <description>

- [Change 1]
- [Change 2]

Co-Authored-By: Claude <assistant> <noreply@anthropic.com>
```

### 3. Type List

| Type | Use Case |
|------|----------|
| feat | Add new feature |
| fix | Bug fix |
| docs | Documentation changes |
| style | Formatting (no code changes) |
| refactor | Refactoring |
| test | Add or modify tests |
| chore | Build or configuration changes |
| perf | Performance improvement |
| ci | CI/CD changes |

### 4. Scope Examples

- auth: Authentication-related
- api: API-related
- ui: UI components
- db: Database-related
- i18n: Internationalization
- config: Configuration files

### 5. Execute Commit

```bash
git add path/to/file1.ts path/to/file2.tsx

git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

- Change 1
- Change 2

Co-Authored-By: Claude <assistant> <noreply@anthropic.com>
EOF
)"
```

### 6. Post-Commit Verification

```bash
git status
git log -1
```

## Notes

- **Avoid git add -A or git add .**: Prevent unintended files from being included
- **Do not include sensitive files**: .env, credentials.json, etc.
- **Do not use --amend unless explicitly requested**
- **Never use --force**
- **If a pre-commit hook fails**: Fix the issue and create a new commit
