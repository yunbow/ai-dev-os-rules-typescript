$NOTE
# Architecture Decision Criteria

Defines the selection criteria for rendering strategies, data fetching, component placement, and API design.

---

## 1. Rendering Strategy Decisions

### Server Component vs Client Component

| Criteria | Server Component | Client Component |
|---------|-----------------|-----------------|
| Needs data fetching | ✔ Default | |
| Uses secrets / environment variables | ✔ Required | ✖ Never use |
| Heavy computation | ✔ Execute on server | |
| User interaction (clicks, inputs) | | ✔ Only when needed |
| React Hooks (useState, useEffect, etc.) | | ✔ When Hooks are needed |
| Uses browser APIs | | ✔ When DOM manipulation is needed |

**Principle**: Server Component is the default. Limit `use client` to the smallest subtree that actually needs interactivity — e.g., wrap only the interactive button, not the entire page section containing it. This keeps the server-rendered payload large and the client bundle small.

### Data Fetching Strategy Decisions

| Content Nature | Strategy | Pattern |
|---------------|------|---------|
| Public, SEO-important | SSG + ISR | `generateStaticParams` + `revalidate` |
| User-specific, authentication required | SSR + Server Actions | Initial fetch with RSC + updates via Hook |
| Real-time, frequent changes | Client refresh | Server Actions + `useListData` + polling |
| Static assets | CDN cache | Edge Cache (Vercel) |

### Cache Strategy Decisions

| Data Type | Cache Duration | Implementation |
|----------|-------------|------|
| Public/static content | Long-term (60s+) | ISR + `revalidate: 60`. 60s is the floor because shorter durations negate ISR benefits — the regeneration cost approaches that of SSR, and CDN hit rates drop below useful thresholds. Increase for truly static content (3600s+). |
| Authenticated user data | No cache | `force-dynamic: true` |
| API responses | Service-dependent | Cache-Control header in Route Handler |

---

## 2. API Design Decisions

### Route Handler vs Server Actions

| Use Case | Route Handler | Server Actions | Reason |
|------------|--------------|---------------|------|
| External API / webhook reception | ✔ | ✖ | External clients cannot call Server Actions |
| Public endpoints | ✔ | ✖ | REST API is required |
| Internal UI data mutations | △ | ✔ Recommended | Server Actions are optimized for UI |
| Form submission | △ | ✔ Recommended | Form binding + ActionResult |
| Data fetching from UI | △ | ✔ Recommended | State management via useAsyncAction / useListData |

**Decision axis**: Is the caller our own project's UI or an external system?

---

## 3. State Management Decisions

### Where to Place State

| State Type | Management Location | Pattern |
|----------|---------|---------|
| Initial page data | Fetch directly in Server Component | Pass as Props |
| Paginated lists | `useListData` Hook | Via Server Actions |
| Data create/update/delete | `useAsyncAction` Hook | Via Server Actions |
| Tables (search + sort + pagination) | `useTableState` Hook | Composite state aggregation |
| Filter state | `useFilterState` Hook | Derived from table state |
| Feature-internal shared state | React Context | Place in `features/*/context` |
| UI local state | `useState` | Within component |

---

## 4. Component Placement Decisions

### Directory Selection Criteria

| Component Nature | Location | Modifiable? |
|-----------------|--------|---------|
| UI foundation (Button, Dialog, etc.) | `/components/ui/` | ✖ No modifications (shadcn/ui originals) |
| App-wide wrappers (LoadingButton, etc.) | `/components/common/` | ✔ Project-wide common |
| Domain-specific UI | `/features/{domain}/components/` | ✔ Free within domain |

### File Splitting Decisions

| Condition | Decision |
|------|------|
| Component exceeds 200 lines | Consider splitting. 200 lines is the point where a component typically stops fitting in a single screen view and becomes hard to reason about as a unit. It's a review trigger, not a hard rule — a 250-line component with clear linear flow is fine; a 150-line component with 5 state variables and 3 effects should be split. |
| Logic that needs to be testable | Separate logic into a Hook |
| Same Props type used in multiple files | Separate type definition to `types.ts` |

---

## 5. Validation Placement Decisions

### Zod and Prisma Responsibility Split

| Case | Responsibility | Reason |
|--------|----------|------|
| UI input validation rules | Zod only | Changes frequently |
| DB integrity constraints (PK, FK, UNIQUE, NOT NULL) | Prisma only | Cannot be fully expressed in Zod |
| Shared business rules (enum, min/max) | Both | Type-safe double defense |
| Data transformation (null → default value, date parsing) | Zod only | UI-specific transformation |

---

## 6. Form Implementation Decisions

| Scenario | Choice |
|---------|------|
| Simple form, no complex state | Server Action + `<form action={}>` |
| Complex form, multi-step | React Hook Form + Server Action |
| Instant validation feedback | RHF + `zodResolver` (client) + server validation |
| Conditional fields | RHF + `watch()` |

### CSRF Protection Decisions

| Context | Protection Needed? | Method |
|------------|---------|------|
| Server Actions | Not needed | Built into the framework |
| Route Handlers (API) | Needed | Origin header validation |

---

## 7. Testing Strategy Decisions

### Test Target Priority

```
1. Authentication/authorization (sessions, IDOR)     ← Highest: a flaw here means full data breach
2. Payment processing                                ← Financial loss is immediate and concrete
3. DB operations + API Routes                        ← Data corruption is hard to reverse
4. Business logic (including Zod schemas)             ← Domain bugs erode user trust
5. User-critical UI flows                             ← Broken flows = lost revenue
6. External API integrations                          ← Third-party changes break silently
7. Edge cases                                         ← Long-tail reliability
```

### Test Type Selection

| Test Type | Purpose | Tool |
|----------|------|--------|
| Unit | Pure functions, business logic | Vitest / Jest |
| Integration | Server Actions, API Routes, Prisma | Vitest + Supertest |
| E2E | User journeys (login, payment, CRUD) | Playwright |
| Contract | API contracts with external services | Pact |
| Performance | API load, SSR response time | k6 / Lighthouse |
| Security | Authentication, authorization, XSS/injection | ZAP, SonarQube |

### Test Database Strategy

- Use a test-dedicated SQLite (file or in-memory)
- Apply the same schema as production
- Incorporate migration dry-run into CI/CD
