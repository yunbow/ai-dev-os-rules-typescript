# Database Guidelines

> **[Replaceable]** This guide uses **Prisma + SQLite**. If your project uses **Drizzle**, **Kysely**, or a different database (e.g., **PostgreSQL**, **Turso**), replace the ORM and database patterns accordingly. The principles (type-safe DB access, migration management, N+1 prevention, query limits) remain the same.

This document adopts **Prisma** as the ORM and uses **SQLite** as the database.

---

## Architecture Policy

### 1. Data Model Design Centered on schema.prisma

- All data models are defined in `prisma/schema.prisma`
- Model changes **must always be accompanied by migrations**
- Models are **centralized by domain** rather than "vertical slices (feature-based)".
  This is a deliberate trade-off: Prisma uses a single-file schema architecture, so splitting models across feature directories would require manual concatenation or tooling workarounds. Centralizing in one file means cross-domain relationships (foreign keys, many-to-many) are immediately visible and validated by Prisma. The downside is that the schema file grows large — mitigate this with clear comment sections per domain and consistent model ordering.

### 2. Prisma Client Usage Policy

- Strictly maintain "one instance per process" for the Client
- In Next.js, manage it in `lib/prisma.ts` as follows

### prisma.ts (Sample)

```ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: ["query", "info", "warn", "error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;

export default prisma;
```

---

## Database Design

- DB: **SQLite**
- Reasons:
  - No installation required, fast setup
  - Easy snapshot creation and testing
  - Fast migration verification
  - Easy deployment (file-based)

---

## Prisma Migrate Operational Rules

### 1. Model Changes → Always Generate a Migration

```bash
npx prisma migrate dev --name <change-name>
```

### 2. Run migrate deploy in Production

```bash
npx prisma migrate deploy
```

### 3. Zod Integration on Model Changes

- Update Zod schema when Prisma schema changes
- Maintain type safety for API Routes / Server Actions

---

## Query Best Practices

### Error Handling

- Absorb Prisma Client Errors in Route Handlers and API layer
- Display appropriate UI based on error codes (e.g., P2002)

### Safety Guidelines for Raw SQL Usage

Raw SQL (`$queryRaw`, `$executeRaw`) should be limited to complex queries that Prisma cannot handle.

#### Acceptable Use Cases

| Case | Example |
|------|---------|
| Complex aggregations | GROUP BY + HAVING + window functions |
| DB-specific features | SQLite-specific functions/syntax |
| Performance optimization | Bulk updates on large datasets |
| Legacy support | During migration period for existing SQL |

#### SQL Injection Prevention Checklist

```ts
// ✅ Safe: Using Prisma.sql template tag
const userId = "user_123";
const result = await prisma.$queryRaw`
  SELECT * FROM "User" WHERE id = ${userId}
`;

// ✅ Safe: Building IN clause with Prisma.join
const ids = ["id1", "id2", "id3"];
const result = await prisma.$queryRaw`
  SELECT * FROM "User" WHERE id IN (${Prisma.join(ids)})
`;

// ❌ Dangerous: String concatenation (strictly prohibited)
const result = await prisma.$queryRawUnsafe(
  `SELECT * FROM "User" WHERE id = '${userId}'`  // SQL injection vulnerability
);
```

#### Raw SQL Code Review Checklist

| Check Item | Verification |
|------------|-------------|
| Template tag usage | Is `Prisma.sql` or `` $queryRaw` `` being used? |
| Unsafe function prohibition | Is `$queryRawUnsafe` / `$executeRawUnsafe` not being used? |
| Variable escaping | Is user input not being directly concatenated into strings? |
| Type safety | Are return types explicitly specified? |
| Comments | Is the reason for using Raw SQL documented? |

```ts
// Type-safe Raw SQL example
type UserStats = {
  userId: string;
  totalOrders: number;
  lastActivity: Date;
};

// Using Raw SQL for complex aggregation that Prisma cannot handle
const stats = await prisma.$queryRaw<UserStats[]>`
  SELECT
    u.id as "userId",
    COUNT(o.id) as "totalOrders",
    MAX(u."updatedAt") as "lastActivity"
  FROM "User" u
  LEFT JOIN "Order" o ON o."userId" = u.id
  GROUP BY u.id
  HAVING COUNT(o.id) > 0
`;
```

---

## Large-Scale Data Handling Guidelines

### Limiting Query Result Count (take)

**Principle: Prohibit unlimited queries.** Without explicit limits, a `findMany` call returns every matching row. As data grows, this can exhaust Node.js heap memory (default ~1.5GB), cause request timeouts, and in serverless environments (Vercel), trigger function crashes or excessive billing. Even a simple query like `findMany({ where: { status: 'active' } })` can return millions of rows if the table is large.

```ts
// ❌ Unlimited (risk of memory exhaustion as records grow)
const allLogs = await prisma.loginHistory.findMany({
  where: { createdAt: { gte: oneHourAgo } }
});

// ✔ Explicitly set an upper limit
const recentLogs = await prisma.loginHistory.findMany({
  where: { createdAt: { gte: oneHourAgo } },
  take: 10000,  // Limit maximum number of records
  orderBy: { createdAt: 'desc' }
});
```

### Limiting nested includes

```ts
// ✔ Apply take to nested relations as well
const items = await prisma.item.findMany({
  where: { projectId },
  take: 100,
  include: {
    children: {
      take: 500,
      include: {
        details: { take: 100 }
      }
    }
  }
});

// Performance note: This query may return up to 100 × 500 × 100 = 5,000,000 records
// Be mindful of memory usage when changing limit values
```

### Utilizing Composite Indexes

### Add composite indexes for frequently combined conditions

```prisma
model TaskItem {
  id        String  @id @default(cuid())
  taskId    String
  status    String
  resultUrl String?

  // Composite indexes (aligned with search patterns)
  @@index([taskId, status])      // Search by task and status
  @@index([status, resultUrl])   // Search by status + result URL
}
```

### Optimizing OR Condition Queries

### NG: Complex OR conditions (reduced index efficiency)

```ts
// ❌ OR conditions do not effectively use indexes
const presets = await prisma.preset.findMany({
  where: {
    OR: [
      { userId },
      { purchases: { some: { userId } } }
    ]
  }
});
```

### OK: Split queries and combine results

```ts
// ✔ Split into independent queries (indexes are effective)
const [ownPresets, purchasedPresets] = await Promise.all([
  prisma.preset.findMany({
    where: { userId },
    take: 100
  }),
  prisma.preset.findMany({
    where: {
      purchases: { some: { userId } },
      userId: { not: userId }  // Exclude duplicates
    },
    take: 100
  })
]);

// Combine results
const combined = [...ownPresets, ...purchasedPresets]
  .sort((a, b) => a.name.localeCompare(b.name))
  .slice(0, 100);
```

### Documentation Requirement

### Document the rationale for limit values in comments

```ts
// Performance note: This query may return up to N records
// Be mindful of memory usage when changing limit values
const results = await prisma.table.findMany({
  take: 5000,  // Maximum 5000 records (for unique ID retrieval)
});
```

### Query Performance Checklist

| Check Item | Action |
|------------|--------|
| No queries inside loops? | Batch fetch with include |
| No unlimited findMany? | Explicitly set take |
| Complex OR conditions? | Consider splitting queries |
| Indexes on frequently searched conditions? | Add @@index |
| Aware of maximum record count for nested includes? | Document in comments |

---

## Prisma Code Generation and Type Usage

- Link Prisma Client types with Zod schemas to ensure **type consistency (Single Source of Truth)**.
- Do not return `@prisma/client` model types directly;

### it is recommended to format them through a DTO (Data Transfer Object) layer

  → Easier to maintain API compatibility

---

## Prisma Directory Structure

```text
/prisma
  ├─ schema.prisma
  ├─ migrations/
  └─ seeds/
src/
  └─ lib/
      └─ prisma.ts   // Prisma Client instance
```

---

## Benefits

- Type-safe and robust DB access
- Schema-centric DB changes are easy to track
- Simple file-based operation with SQLite
- Excellent compatibility with Next.js

---

## Separation of Responsibilities with Zod

> **Reference:** common/validation.md

| Responsibility | Owner | Description |
|---------------|-------|-------------|
| External input validation | **Zod** | Form input, API request validation |
| DB integrity constraints | **Prisma** | PK, FK, unique, not null, etc. |
| Type generation source | **Both** | Zod for input types, Prisma for DB types |

```text
External input → Validate with Zod → Save with Prisma
                ↑                    ↑
           Source of truth      Source of truth
           for input            for DB structure
```

**Important:** Prisma types are trustworthy for data from the DB, but **should never be used for external input validation**. External input must always be validated with Zod before being passed to Prisma.

---

## Summary

In this project:

- **Prisma**: Single Source of Truth for DB data models
- **Zod**: Single Source of Truth for input validation

The two are complementary, each serving as the "single source of truth" within their respective areas of responsibility.
