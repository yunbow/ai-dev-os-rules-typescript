---
name: guideline-checker
description: Automatically check whether git diff contents comply with project guidelines after code changes. Run at coding completion or before committing.
allowed-tools: Read, Grep, Glob, Bash
---

# Guideline Compliance Checker

A skill that checks whether code changes comply with ai-dev-os guidelines.

## When to Execute

- When a review is requested after coding is complete
- When verifying compliance before committing
- When requested with "guideline check", "compliance check", etc.

## Execution Steps

### 1. Get Changed Files

```bash
git diff --name-only
```

If there are no changes, check staged or last commit changes with `git diff HEAD~1 --name-only`.

### 2. Identify Relevant Guidelines

Based on the paths of changed files, identify which guidelines to check:

| Changed File Pattern | Guidelines to Check |
|---------------------|---------------------|
| `*.ts`, `*.tsx` | common/code.md, common/naming.md |
| `*/server/*.ts`, `*-actions.ts` | frameworks/nextjs/api.md, common/security.md, common/error-handling.md |
| `*/schema/*.ts` | common/validation.md |
| `*/components/*.tsx` | frameworks/nextjs/ui.md, frameworks/nextjs/form.md |
| `*/hooks/*.ts` | frameworks/nextjs/state.md |
| `prisma/schema.prisma` | frameworks/nextjs/database.md, common/naming.md |
| `app/**/page.tsx`, `app/**/layout.tsx` | frameworks/nextjs/routing.md |
| `app/api/**` | frameworks/nextjs/api.md, common/security.md |
| `.env*` | common/env.md |
| `*.test.ts`, `*.spec.ts` | common/testing.md |

### 3. Check Items by Guideline

#### common/security.md (Security)

- [ ] Are authentication checks (`auth()`) performed in Server Actions?
- [ ] Is input validated with Zod?
- [ ] Are there IDOR protections (resource ownership checks)?
- [ ] Is sensitive information excluded from logs?

#### common/code.md (Coding Conventions)

- [ ] Is the `any` type not used? (`unknown` should be used instead)
- [ ] Are function arguments and return types explicitly typed?
- [ ] Are Union Literals used instead of Enums?
- [ ] Are reasons documented in comments when disabling ESLint rules?

#### common/error-handling.md (Error Handling)

- [ ] Are error responses in a unified format (ActionResult<T>, etc.)?
- [ ] Are internal errors not directly exposed to users?
- [ ] Are appropriate log levels (ERROR/WARN/INFO) used?

#### common/naming.md (Naming Conventions)

- [ ] Are file names in kebab-case? (PascalCase is acceptable for components)
- [ ] Are function names in camelCase?
- [ ] Are type names in PascalCase?
- [ ] Are constants in SCREAMING_SNAKE_CASE?

### 4. Output Check Results

```markdown
## Guideline Compliance Check Results

### Changed Files
- path/to/file1.ts
- path/to/file2.tsx

### Check Results

| Guideline | Item | Status | Details |
|-----------|------|--------|---------|
| security | Auth check | ✅ | auth() is used |
| validation | Zod validation | ✅ | safeParse is used |
| code | No any | ⚠️ | any used in 1 place (needs review) |
| error-handling | Unified error format | ✅ | ActionResult format |

### Improvement Suggestions
- file.ts:25 - Recommend changing `any` to `unknown`
```

## Status Symbols

- ✅ Compliant
- ⚠️ Needs review / Improvement recommended
- ❌ Violation (must fix)
