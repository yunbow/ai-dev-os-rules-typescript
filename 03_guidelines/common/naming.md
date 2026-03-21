# Naming Convention Guidelines
This document defines **unified naming conventions** for large-scale Next.js applications.

Scope:
* Prisma models and field names
* Database physical names (table and column names)
* URL paths
* Component names
* API routes
* Type / Interface / Enum
* File and directory names

Prioritizes readability, searchability, and scalability.

---

# 1. General Principles
### Consistency
Unify naming within each domain. Do not mix different naming conventions.

### English Naming Thresholds
* **Variable/field names**: 1-3 words, max 30 characters (e.g., `createdAt`, `orderItemCount`)
* **Function names**: verb + noun, 2-4 words, max 40 characters (e.g., `fetchUserProfile`, `calculateTotalPrice`)
* **Type/interface names**: 1-3 words describing the shape (e.g., `UserProfile`, `OrderSummary`)
* **Avoid abbreviations** unless universally understood (`id`, `url`, `api`, `db` are acceptable; `usr`, `msg`, `btn`, `cfg` are not)
* **When a name exceeds thresholds**, it signals the concept should be split or the scope narrowed

---

# 2. Prisma Relation Names
* **1:1 / N:1 → singular**
* **1:N / N:M → plural (to clearly indicate arrays)**
* lowerCamelCase
* Use names that clearly convey the role

Examples:

```prisma
// N:1
user    User     @relation(fields: [userId], references: [id])
userId  String

// 1:N
orderItems  OrderItem[]
```

---
# 3. Database Physical Names (SQLite)
## Table Names

* **snake_case**
* **Plural**

Examples:

```
users
blog_posts
order_items
```

## Column Names
* **snake_case**
* Singular

Examples:

```
created_at
user_id
is_active
```

## Constraint Names
This guideline adopts the convention of prefixing with the constraint type (pk, fk, idx) for readability and searchability.

Rationale:
* **Constraints are visually grouped by type when listed**
* **Easy to filter by prefix in tools and logs**
* Can be more readable than the common "orders_user_id_fk" format

Naming rules:
* Primary key: `pk_<table>`
* Foreign key: `fk_<table>_<ref_table>`
* Index: `idx_<table>_<column>`

Examples:

```
pk_users
fk_orders_users
idx_blog_posts_author_id
```

---

# 4. URL Path Naming (Next.js App Router)
* **kebab-case**
* Resources in **plural**
* No verbs (REST)

Examples:

```
/users
/users/[id]
/blog/posts
/blog/posts/[slug]
```

---

# 5. API Route Naming (/api)
* Follow REST principles
* Resource names in **plural**
* Operations expressed through HTTP methods
* No verbs in paths

Examples:

```
/api/users
/api/users/[id]
/api/orders
/api/orders/[orderId]/items
```

---

# 6. Service / Repository
* `[domain].service.ts`
* `[domain].repository.ts`

Examples:

```
user.service.ts
order.repository.ts
```

---

# 7. Validation Schema (Zod)
* Schema names: **PascalCase**
* File names: **unified to kebab-case + -schema.ts**

Example:

```ts
export const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});
```

File name examples:

```
user-schema.ts
order-schema.ts
form-schema.ts
```

---

# 8. Event Handlers and Callbacks

* MUST use `handle` + noun + verb pattern: `handleTaskDelete`, `handleFormSubmit`, `handleStatusToggle`
* ❌ `handleDelete`, `handleSubmit`, `onSubmit` — missing noun, unclear what is being acted on
* ✅ `handleTaskDelete`, `handleProfileUpdate`, `handleInvitationAccept`
* Props passed to child components use `on` prefix: `onTaskDelete`, `onStatusChange`

---

# 9. Forms (React Hook Form)

* `[Domain]Form.tsx`
* `use[Domain]Form.ts`

---

# 10. WebSocket / Realtime Names

* Event names: **snake_case**
* Channel names: **plural**

---

# Summary

| Target | Naming Convention |
| --- | --- |
| Prisma model | PascalCase (singular) |
| Prisma field | lowerCamelCase |
| Prisma relation (1:N / N:M) | **plural (emphasizing arrays)** |
| DB table physical name | snake_case (plural) |
| DB column | snake_case (singular) |
| URL path | kebab-case (plural) |
| API path | REST / plural |
| React component | PascalCase export, **kebab-case file name** (`task-card.tsx` exports `TaskCard`) |
| Other files/directories | kebab-case |
| Type / Enum | PascalCase |
| Zod schema | PascalCase / file name is kebab-case (-schema.ts) |

## Before/After Example

```typescript
// ❌ Before: Inconsistent naming and unclear abbreviations
const usrMgr = new UserMgr();
const get_data = () => fetch("/api/User");
interface order_item { qty: number; }
```

```typescript
// ✅ After: Consistent conventions with clear names
const userManager = new UserManager();
const fetchUserProfile = () => fetch("/api/users");
interface OrderItem { quantity: number; }
```
