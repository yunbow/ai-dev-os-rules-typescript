# CI/CD Guidelines

This document defines the CI/CD pipeline design policy for Next.js applications.

**Target Cloud:** Vercel / GitHub Actions

---

## 1. Core Principles

- **Staged pipeline**: Safe rollout through CI → Preview → Production. "Safe" means: every stage must pass automated checks (lint, type-check, tests, build) before proceeding, with auto-rollback on post-deployment validation failure.
- **Post-Deployment Validation**: Execute health checks and Smoke Tests after deployment. Smoke Tests verify: the app starts, the home page renders, authentication flow completes, and at least one API route returns a 200 response.

---

## 2. GitHub Actions-Based CI

### Recommended Workflow

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20

      # Leverage caching
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}

      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test
      - run: npm run build

      # Upload build artifacts for reuse during deployment
      - uses: actions/upload-artifact@v4
        with:
          name: build-artifact
          path: .next/

  # Separate E2E tests into a dedicated job (to avoid blocking fast feedback from unit tests)
  e2e:
    runs-on: ubuntu-latest
    needs: verify
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run e2e
```

---

## 3. Preview Deployment

### Vercel

- On PR creation, **Vercel PR Preview is automatically generated**
- Preview URL is displayed in PR comments
- Used for UI/UX design review and final review

### Reusing Build Artifacts

```yaml
- uses: actions/download-artifact@v4
  with:
    name: build-artifact
```

Reuse build artifacts created during CI to reduce duplicate build time.

---

## 4. Production Deployment

### Vercel Production

- Auto-deploy after merging into the main branch
- Manual Approval required (Protected Branch settings)
- Supports Edge Functions / ISR / Server Actions

### Post-Deployment Validation

Execute external health checks / Smoke Tests after deployment completion. Auto-rollback on failure:

- **Vercel**: Revert to the previous version from deployment history

---

## 5. Release Strategy

- **Semantic Versioning**: `MAJOR.MINOR.PATCH`
- **GitHub Release integration**
- **Automatic CHANGELOG generation**: `release-please` / `changesets` / `semantic-release`
- **Deployment gate**: Manual Approval required before main → Production deployment

---

## 6. Database Migration (Prisma Migrate)

- **CI**: `prisma validate` + `prisma format`
- **Production migrate**: Manual or safe CD stage
  - Non-destructive migrations → Auto-execute within the CD pipeline
  - Changes requiring downtime → Execute manually during a maintenance window
- Manage execution order considering **version mismatches between application and DB schema**

---

## 7. Secrets / Environment Variable Management

| Platform | Management Location |
|----------------|---------|
| GitHub Actions | Actions secrets |
| Vercel | Project Environment Variables |

- Do not handle `.env` files directly; inject from Secrets
- Protect production secrets so they are not exposed in PRs

---

## 8. Rollback Strategy

| Platform | Method |
|----------------|------|
| Vercel | Instant Rollback with one click in the UI |
| GitHub | Release Revert → Auto-deploy PR to main |

**Always execute auto-rollback when Post-Deployment Validation fails.**

---

## 9. Performance Measurement / Monitoring

- Vercel Analytics / Speed Insights
- Sentry (incident monitoring)
- Logtail / Datadog (logs)
- Automated Lighthouse checks

---

## 10. Pipeline Optimization

- **Leverage dependency caching**: `actions/cache@v4`
- **Use npm ci** (fast install from package-lock.json)
- **Test parallelization**: Run tests in parallel
- **Next.js incremental build**: Differential builds on Vercel

---

## 11. Monorepo Support (As Needed)

Leverage NX / Turborepo:

- Split caching
- Parallel execution
- Affected scope detection (Affected Graph)

---

## Summary

| Item | Policy |
|------|------|
| CI | Unified with GitHub Actions |
| Frontend | Vercel |
| Quality Assurance | PR Preview + Post-Deployment Validation |
| Release | Semantic Versioning + Manual Approval |
| Rollback | Automated + One-click |
| Secrets | Strict management (via Secrets) |

## Before/After Example

```typescript
// ❌ Before: Running all checks in a single step with no caching
const ci = {
  steps: [
    "npm install",     // Full install every time
    "npm run lint && npm test && npm run build && npm run e2e",
  ],
};
```

```typescript
// ✅ After: Staged pipeline with caching and parallel jobs
const ci = {
  verify: {
    cache: "actions/cache@v4",
    steps: ["npm ci", "npm run lint", "npm run typecheck", "npm test", "npm run build"],
  },
  e2e: { needs: "verify", steps: ["npm ci", "npm run e2e"] },
};
```
