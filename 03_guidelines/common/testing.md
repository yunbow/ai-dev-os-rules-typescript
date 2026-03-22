# Testing Guidelines

This document defines testing strategy for large-scale Next.js applications, focusing on project-specific decisions and non-obvious patterns.

---

## 1. Testing Core Policy

## 1. Prioritize Testing Critical Logic

Critical logic = code where a bug has **high business cost or security impact**:

- **Financial**: Pricing calculations, subscription billing, payment flows ({Payment Service})
- **Security**: Authentication (NextAuth), authorization decisions, IDOR prevention
- **Data integrity**: DB queries (Prisma) that modify state, cascade deletes
- **Core business rules**: Date calculations, scheduling logic, domain-specific validation
  → If a bug in this code would require immediate hotfix or cause revenue loss, it is critical.

## 2. Server-side logic uses **unit tests + API integration tests** as the baseline

- Server Actions / Route Handler logic is unit-testable
- **Note DB environment differences**
  - Both production and test environments use SQLite. Use a separate SQLite file (or in-memory DB) for testing.
  - Add a migration dry run to CI/CD to verify schema consistency.

## 3. UI testing priority: **E2E > Integration > Unit**

- UI tests are costly, so only guarantee "critical user experience areas" with E2E

## 4. Introduce Contract Tests for external service integrations

- For external APIs like payment APIs, AI APIs, and RSS,
  adopt Contract Tests that are resilient to specification changes in real services
- **Note**: Contract Tests serve a different purpose from MSW (detecting external service specification changes)
  - Implementation method needs clarification (e.g., Pact + Webhook payload verification, SDK type definition comparison, OpenAPI specification comparison)

---

## 2. Layer-Specific Testing Strategy

## 1. Domain Logic (Unit Test)

- Zod schemas must always have standalone schema tests

### Example: Pricing logic / data transformation

```text
features/billing/domain/
features/calendar/domain/
```

---

## 2. API / Server Actions (Integration Test)

### Key Points

- Switch Prisma to **a test-specific SQLite / in-memory DB**
- Mock external APIs (payment / AI API, etc.) with MSW or mocks
- Add migration dry runs to CI/CD

### Server Actions Test Pattern

```ts
// tests/unit/server-actions/project-actions.test.ts

import { createProject, deleteProject } from "@/features/project/server/project-actions";
import { prisma } from "@/lib/prisma";

// Mock authentication context
jest.mock("@/lib/auth", () => ({
  auth: jest.fn(),
}));

describe("Project Actions", () => {
  beforeEach(() => {
    // Reset DB for each test
    await prisma.project.deleteMany();
  });

  describe("createProject", () => {
    it("allows authenticated users to create a project", async () => {
      // Mock authentication
      (auth as jest.Mock).mockResolvedValue({
        user: { id: "user_123" },
      });

      const result = await createProject({ name: "Test Project" });

      expect(result.success).toBe(true);
      expect(result.data?.id).toBeDefined();
    });

    it("returns UNAUTHORIZED for unauthenticated users", async () => {
      (auth as jest.Mock).mockResolvedValue(null);

      const result = await createProject({ name: "Test" });

      expect(result.success).toBe(false);
      expect(result.error?.code).toBe("UNAUTHORIZED");
    });

    it("returns fieldErrors on validation error", async () => {
      (auth as jest.Mock).mockResolvedValue({ user: { id: "user_123" } });

      const result = await createProject({ name: "" }); // Empty string

      expect(result.success).toBe(false);
      expect(result.error?.code).toBe("VALIDATION_ERROR");
      expect(result.error?.fieldErrors?.name).toBeDefined();
    });
  });

  describe("deleteProject - IDOR Prevention", () => {
    it("returns FORBIDDEN for another user's project", async () => {
      // Create another user's project
      const otherProject = await prisma.project.create({
        data: { name: "Other", userId: "other_user" },
      });

      (auth as jest.Mock).mockResolvedValue({ user: { id: "user_123" } });

      const result = await deleteProject(otherProject.id);

      expect(result.success).toBe(false);
      expect(result.error?.code).toBe("FORBIDDEN");
    });
  });
});
```

### ActionResult Pattern Test Helper

```ts
// tests/helpers/action-helpers.ts

import type { ActionResult } from "@/lib/actions/action-helpers";

export function expectSuccess<T>(result: ActionResult<T>): asserts result is { success: true; data: T } {
  expect(result.success).toBe(true);
  if (!result.success) throw new Error("Expected success");
}

export function expectFailure(result: ActionResult<unknown>, code: string) {
  expect(result.success).toBe(false);
  if (result.success) throw new Error("Expected failure");
  expect(result.error.code).toBe(code);
}

// Usage example
it("project creation succeeds", async () => {
  const result = await createProject({ name: "Test" });
  expectSuccess(result);
  expect(result.data.id).toBeDefined();
});
```

---

## 3. UI / Pages (E2E Test)

### Critical Path Criteria

An E2E test is "critical path" if it covers a flow where **failure blocks the user from completing their primary goal** or **causes financial/security harm**:

- Authentication flow (login / sign up) — users cannot access the app without it
- Payment flow — revenue-impacting
- Dashboard main navigation — primary entry point after auth
- Critical CRUD operations (e.g., task create → update → delete) — core value proposition

### Security Test Playbook

- Attempt to access other users' data by ID replacement after login
- CSRF token exploitation
- XSS / Injection via form input

---

## 4. Contract Test (External Services)

### Payment API / AI API, etc

- Payment/subscription API contracts, Webhook payloads, SDK type definition consistency
- Implement Consumer-Driven Contracts with Pact, etc.
- Purpose: detect specification changes in external services
- MSW is for internal API mocking, not a substitute for Contract Tests

---

## 3. Performance & Quality Assurance

## 1. Performance Test

- API Route load testing with k6
- SSR response measurement on Vercel / Amplify

## 2. Automated Lighthouse Score Measurement

- Integrate into CI/CD, auto-measure on PR

## 3. Security Test

- Integrate static/dynamic analysis tools (ZAP, SonarQube) into CI/CD
- Detect vulnerabilities in authentication, authorization, and payment flows

---

## 4. Test Target Priority

1. Authentication (NextAuth)
2. Payments ({Payment Service})
3. DB (Prisma) + Route Handler
4. Logic (including Zod schemas)
5. Critical UI flows users must navigate
6. Key external API integrations
7. Edge cases (e.g., invalid tokens / expired sessions)

---

## 5. Directory Structure

```text
tests/
  unit/
    calendar/
    billing/
    integration/
    api/
    server-actions/
  e2e/
    auth/
    dashboard/
    mocks/
    msw/
src/
  features/
    billing/
      domain/
      components/
      api/
    calendar/
      domain/
```

---

## 6. Summary

- Increase change resilience for external APIs (payment, AI API, etc.) with Contract Tests
- MSW-based internal API mocking strategy
- E2E covers only flows where failure blocks users or causes financial/security harm
- Integrate Security Tests into CI/CD for early vulnerability detection
- Run tests on test SQLite (file or in-memory) with production-identical schemas

## Before/After Example

```typescript
// ❌ Before: Testing only the success path
it("creates a project", async () => {
  const result = await createProject({ name: "Test" });
  expect(result.success).toBe(true);
});
```

```typescript
// ✅ After: Testing success, auth failure, and IDOR prevention
it("creates a project", async () => {
  const result = await createProject({ name: "Test" });
  expectSuccess(result);
});
it("rejects unauthenticated users", async () => {
  mockAuth(null);
  const result = await createProject({ name: "Test" });
  expectFailure(result, "UNAUTHORIZED");
});
it("prevents access to another user's project", async () => {
  const result = await deleteProject(otherUserProjectId);
  expectFailure(result, "FORBIDDEN");
});
```
