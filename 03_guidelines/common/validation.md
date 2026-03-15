# Validation Guidelines
This document outlines how to manage **Types** and **Validation** in a unified manner across large-scale Next.js applications, centered on Zod and Prisma.

---

# 1. Core Policy
* Build a structure where types naturally synchronize in the order **Zod → Prisma → TypeScript**.
* API schemas can be converted from **Zod → JSON Schema (for AI APIs, etc.)** for external sharing.

---

# 2. Business Logic Rules in Zod Schemas

Business logic rules that belong in Zod schemas (not just format validation):

* **Cross-field constraints**: e.g., `endDate` must be after `startDate`, `maxPrice` >= `minPrice`
* **Domain value boundaries**: e.g., quantity must be 1-999, discount percentage 0-100
* **Conditional required fields**: e.g., if `paymentMethod` is "card", `cardNumber` is required
* **Enumerated state transitions**: e.g., order status can only move from "pending" → "confirmed" → "shipped"
* **Composite uniqueness hints**: e.g., `slug` must match `^[a-z0-9-]+$` pattern (DB enforces actual uniqueness)

Rules that do NOT belong in Zod (handle in service/domain layer):
* Checks requiring DB lookups (e.g., "email must not already exist")
* Rules depending on external service state (e.g., "inventory must be available")
* Multi-aggregate consistency checks

---

# 3. Synchronizing Zod Schemas and Prisma Models

Recommended process:
1. **Write Zod first**
   UI requirements and business requirements are consolidated in Zod.
2. **Define Prisma models based on Zod**
   Enums and similar constructs are also mapped to the Prisma Schema.
3. Generate/update the DB via Prisma migrate.
4. Frontend, backend, and API all use Zod-derived types.

### Single Source of Truth for Types
* **Truth for input types: Zod**
* **Truth for DB: Prisma**
* **Truth for API Schema: Zod (→ JSON Schema generation)**

---

# 4. Directory Structure (Schema / Prisma / Types)

```
src/
 ├─ features/
 │   ├─ user/
 │   │   ├─ schema/          # Zod schemas (source of truth for input)
 │   │   ├─ types/           # Types generated via infer()
 │   │   ├─ services/        # Zod → Prisma transformation
 │   │   └─ server/          # Route Handler / Server Actions
 │
 ├─ lib/
 │   ├─ prisma/              # Prisma Client
 │
 └─ types/                   # Global types
```

---

# 5. API Schema (JSON Schema) Generation

* Zod schemas can be converted to JSON Schema,
  serving as **the foundation for AI API schemas, external APIs, and specification generation**.

Benefits:
* Prevents type mismatches
* Unifies the API ecosystem
* Facilitates automatic documentation generation

---

# 6. Guidelines for Zod and Prisma Definition Duplication Risk
Since Zod and Prisma define the same fields, there is a **risk of inconsistency when changes are made**.
Follow these principles to mitigate:

### Principles
1. **Input constraints (validation) → Zod is the sole source of truth**
2. **Structural constraints (DB integrity) → Prisma is the sole source of truth**
3. Shared domain rules (enum / MinMax / Regex) should be **defined in both Zod and Prisma** where possible

### Operational Rules

| Case | Where to Define | Reason |
| --- | --- | --- |
| UI/external input validation | Zod only | Changes frequently; Prisma changes are costly |
| DB integrity constraints | Prisma only | Cannot be guaranteed by Zod |
| Application-wide business rules | Zod → sync to Prisma | Single source management |
| Enum / fixed values | Both | Required to prevent type mismatches |

### Recommended Support Tools

| Tool | Effect |
| ---------------------- | ------------------ |
| `zod-prisma` type sync tool | Assists Zod → Prisma conversion |
| `@anatine/zod-openapi` | Generates OpenAPI from Zod |
| `@ts-safeql/prisma` | Improves type safety for Prisma queries |

> **Duplication is acceptable, but responsibilities must be clearly separated.**
> Maintain the structure where validation and transformation belong to Zod, and DB protection belongs to Prisma.

---

# 7. Summary (Zod + Prisma)

* Types from UI → API → DB naturally synchronize via Zod → Prisma
* JSON Schema generation unifies external API schemas as well
* **Definition duplication is tolerated from a responsibility separation perspective, but intentional synchronization management must be enforced**

## Before/After Example

```typescript
// ❌ Before: Inline validation without Zod, no type inference
function createUser(data: any) {
  if (!data.email || !data.email.includes("@")) throw new Error("Bad email");
  if (!data.name) throw new Error("Name required");
  return prisma.user.create({ data });
}
```

```typescript
// ✅ After: Zod schema as single source of truth with inferred types
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});
type CreateUserInput = z.infer<typeof CreateUserSchema>;

function createUser(data: CreateUserInput) {
  return prisma.user.create({ data });
}
```
