$NOTE

# Design Principles

This document defines the fundamental principles that underpin all projects.
It articulates the "why" behind our guidelines and serves as the ultimate reference point when making difficult decisions.

---

## Three Pillars: Correctness, Observability, Pragmatism

All design decisions are made in this order of priority.

```text
1. Correctness   — Guarantee correct behavior through types and validation
2. Observability  — Ensure the running state can be observed and traced
3. Pragmatism     — Achieve goals with the minimum necessary complexity
```

### 1. Correctness

> *"Eliminate code that fails at runtime by catching it at compile time."*

- Security is built into the architecture, not bolted on after the fact

> The "cost" of types is negligible compared to the cost of runtime errors.

### 2. Observability

> *"Understand what is happening in production without redeploying."*

- Assign a Trace ID to every request and propagate it across layers
- Automatically mask PII. Never expose secrets in logs
- Continuously measure metrics (error rates, latency, SLO/SLA)

> Always maintain a state where "looking at the logs tells you everything."

### 3. Pragmatism

> *"Don't build it until you need it. When you need it, build it the simplest way possible."*

- Copy-paste is not evil. Don't abstract until duplication appears in 3 places. The number 3 is deliberate: with 1 occurrence you have no pattern; with 2 you see similarity but may be misled by coincidence; with 3 you have enough evidence to extract a correct, stable abstraction. Abstracting at 2 often produces the *wrong* abstraction because you lack sufficient examples to identify the true commonality
- Convention over Configuration
- Prefer "constrained systems" over "flexible systems." Constraints force design decisions early, reduce the surface area for bugs, and make code predictable. A constrained system (e.g., a fixed set of allowed status values as a union type) prevents invalid states by construction, whereas a flexible system (e.g., accepting arbitrary strings) defers validation to runtime and scatters guard logic throughout the codebase
- Exceptions are allowed, but make the reasons visible (comments are required on `eslint-disable`)

> Over-generalization produces code that is generically useless.

---

## Core Policies

### Server First

- Server Components are the default. Use `use client` only when interactivity is required
- All data fetching and mutations go through Server Actions. Direct `fetch` from components is prohibited
- Data flows unidirectionally: Server Actions → Hooks → Components

### Separation of Concerns

- Each layer (Client → Server → Database) has clearly defined responsibilities
- Features are self-contained per domain (components, server, schema, context)
- Shared logic is consolidated in `/lib/`. Do not create vague `util.ts` files

---

## Security Philosophy: Zero Trust

> *"Trust no input. Every user is a potential attacker."*

1. **API Layer**: Zod validation, CORS, rate limiting
2. **Auth Layer**: Session validation, IDOR checks (always verify ownership for resource access)
3. **DB Layer**: ORM-only access (raw SQL is prohibited), user_id filtering
4. **Data Layer**: Encrypt sensitive fields

Apply the principle of least privilege to everything (DB users, API scopes, feature flags).

---

## Approach to Errors

> *"Don't try to prevent every failure — detect, contain, and communicate them."*

- Errors fall into 3 categories: System (unexpected), Application (expected), User (input mistakes)
- Do not leak internal error details to the UI (return sanitized messages)
- Non-critical feature failures must not crash the entire app (Error Boundary, skeletons, cache)
- Always ensure traceability via Request ID

---

## UI/Design Philosophy

> *"Constraints create consistency, and consistency creates speed."*

- Constraint-based design with Tailwind CSS (spacing scale, color palette)
- CSS Variables serve as the Single Source of Truth
- Components are layered: UI Foundation → Shared Wrappers → Domain-Specific
