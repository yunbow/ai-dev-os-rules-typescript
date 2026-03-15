---
name: type-check
description: Run TypeScript type checking and ESLint, identify error locations, and provide fix suggestions. Used for quality assurance after implementation.
allowed-tools: Bash, Read, Grep, Glob
---

# Type & Lint Check Skill

A skill that runs TypeScript type checking and ESLint to detect and fix errors.

## When to Execute

- For quality assurance after implementation is complete
- When requested with "type check", "lint", "type-check", etc.
- For final verification before committing

## Execution Steps

### 1. TypeScript Type Check

```bash
npx tsc --noEmit
```

### 2. ESLint Check

```bash
npm run lint
```

### 3. Error Analysis

When errors occur, collect the following information:

- File path and line number
- Error code (TS2345, @typescript-eslint/no-explicit-any, etc.)
- Error message

### 4. Common Errors and Fixes

#### TypeScript Errors

| Error | Cause | Fix |
|-------|-------|-----|
| TS2345 | Type mismatch | Convert to correct type or use assertion |
| TS2322 | Type error on assignment | Fix the type definition |
| TS7006 | Implicit any | Add explicit type annotation |
| TS2339 | Non-existent property | Review and fix the type definition |
| TS2304 | Undefined name | Add import or definition |

#### ESLint Errors

| Rule | Fix |
|------|-----|
| @typescript-eslint/no-explicit-any | Change to `unknown` |
| @typescript-eslint/no-unused-vars | Remove or use the variable |
| react-hooks/exhaustive-deps | Fix the dependency array |
| @next/next/no-img-element | Use the `<Image>` component |
| import/order | Fix import order |

### 5. Run Auto-Fix (If Needed)

```bash
npm run lint:fix
npx prettier --write "src/**/*.{ts,tsx}"
```

### 6. Re-Check After Fixes

```bash
npx tsc --noEmit && npm run lint
```

## Output Format

```markdown
## Type & Lint Check Results

### TypeScript
- **Status**: ✅ No errors / ❌ X error(s)

### ESLint
- **Status**: ✅ No errors / ❌ X error(s)

### Error Details (If Any)

| File | Line | Error | Suggested Fix |
|------|------|-------|---------------|
| src/xxx.ts | 25 | TS2345: Type mismatch | Change `string` to `number` |
| src/yyy.tsx | 10 | no-explicit-any | Change `any` to `unknown` |
```

## Status Symbols

- ✅ Check passed
- ⚠️ Warnings present (fix recommended)
- ❌ Errors present (must fix)

## Notes

- **Build errors must be fixed**: Resolve all errors before committing
- **Address warnings when possible**: Avoid technical debt
- **Disabling ESLint is a last resort**: Document the reason in a comment when disabling
