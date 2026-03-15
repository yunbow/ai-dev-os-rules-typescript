# API Design Guidelines
This chapter summarizes how to design and divide responsibilities between **Route Handlers (app/api/)** and
Server Actions in Next.js large-scale applications.

---

# 1. API Design Basic Principles
In Next.js App Router, the following two types are used depending on the use case.

* **Route Handler (app/api/*/route.ts)**
  → For REST API / Webhook / receiving from external services / public endpoints
* **Server Actions**
  → Server methods called from pages and components (forms / internal processing)

As a general rule:
* External clients (mobile apps / Webhooks / other services)
  → **Use Route Handlers**
* Internal UI events (form submissions / Mutations)
  → **Use Server Actions**
* APIs requiring authentication → **Perform session checks within Server Actions or Route Handlers**

---

# 2. Route Handlers (REST API) Design Guidelines

Place APIs in `app/api/**/route.ts`.

## 2.1 Directory Structure (Example)

```
app/
└─ api/
   ├─ auth/
   │   └─ route.ts
   ├─ users/
   │   ├─ [id]/
   │   │   └─ route.ts
   │   └─ route.ts
   ├─ posts/
   └─ webhooks/
       └─ {service}/        # Example: stripe, paypal, etc.
           └─ route.ts
```

---

# 3. Role Separation: Route Handler vs Server Actions

| Use Case | Route Handler | Server Actions |
| --- | --- | --- |
| External API / Webhook | Recommended | Not applicable |
| Access from outside the site | Recommended | Not applicable |
| Internal UX optimization (form submissions, etc.) | Possible | Recommended |
| Secure processing requiring authentication | Recommended | Recommended |
| Data fetching via Server Actions | Possible | Recommended (called via useAsyncAction / useListData) |
| UI-dependent Mutation | Possible | Recommended |

---

# 4. Validation Policy (Zod)

Schema validation with **Zod** is required for both Route Handlers and Server Actions.

```ts
const schema = z.object({
  title: z.string().min(1),
  content: z.string().optional(),
});
```

* Safely parse request body (json/form-data) with Zod
* Return 400/422 for errors
* Always pass **validated data** to Prisma / DB

---

# 5. Server Actions Characteristics and Implementation Guidelines
Server Actions are treated as **UI-coupled** server logic.

---

## 5.1 Security: Zod Validation is Required
> Since form values can be tampered with on the client side,
> **Zod validation immediately after Action function execution is required**

```ts
export async function createPostAction(prevState: any, formData: FormData) {
  const parsed = schema.safeParse({
    title: formData.get("title"),
    content: formData.get("content"),
  });

  if (!parsed.success) {
    return { error: "Invalid input" };
  }

  // DB operation...safe
}
```

---

## 5.2 UI Integration (form / useFormState / useFormStatus)
* Can be directly bound to `<form action={serverAction}>`
* With `useFormState` and `useFormStatus`,

  * **Loading state**
  * **Validation error display**
    are automatically reflected on the client side

→ **Client Components become simpler (no unnecessary fetch required)**

---

# 6. Route Handler Security

Route Handlers receive external access, so
**security header application is required**.

* **CORS** — restrict `Access-Control-Allow-Origin` to your own domains; prevents other websites from making authenticated requests on behalf of your users
* **CSP** — set `Content-Security-Policy` to control which scripts/styles/images can load; mitigates XSS by blocking inline scripts and unauthorized origins
* **XSS protection** — set `X-Content-Type-Options: nosniff` and sanitize any user-generated content rendered in responses

### Implementation Examples

* Global settings: `next.config.js`
* Specific endpoints: Add headers to `Response`

```ts
return new Response(JSON.stringify(data), {
  headers: {
    "Content-Security-Policy": "default-src 'none'",
    "Access-Control-Allow-Origin": "https://example.com",
  },
});
```

---

# 7. Authentication (NextAuth.js)

## 7.1 Route Handler Case

```ts
import { auth } from "@/lib/auth";

export async function GET() {
  const session = await auth();
  if (!session) return new Response("Unauthorized", { status: 401 });
}
```

* Role-based access control (RBAC) can be applied
* Authentication logic is consolidated in lib/auth

---

## 7.2 Server Actions Case

* `auth()` operates securely on the server
* Works well with UI-coupled mutations

---

# 8. Error Handling

> **Reference:** For error classification, HTTP status details, and user-facing messages, see common/error-handling.md
> **Reference:** For the Server Actions ActionResult pattern, see frameworks/nextjs/server-actions.md

### Route Handler (REST API) Format

```json
{
  "error": {
    "code": "BAD_REQUEST",
    "message": "Invalid Request"
  }
}
```

Determine success/failure by HTTP status code (200-299 = success, 4xx/5xx = error).

### Server Actions Format

```ts
// ActionResult pattern (discriminated union)
type ActionResult<T> =
  | { success: true; data: T }
  | { success: false; error: ActionError };
```

Determine success/failure by the `success` flag, not HTTP status.

### Usage Guidelines

| Target | Format | Reason |
|------|------|------|
| Route Handler | REST JSON + HTTP status | External client compatibility |
| Server Actions | ActionResult | Type safety, React integration |

---

# 9. External Integration (Webhook / External API / RSS)

### Payment Service Webhooks
* Use Route Handlers only (Server Actions not allowed)
* Place in `app/api/webhooks/{service}/route.ts`
* Signature verification must be implemented

### External APIs (AI services, etc.)
* Both Route Handlers and Server Actions are acceptable
* Authentication credentials are securely maintained on the server

### RSS
* fetch within Route Handler → CORS bypass

---

# 10. Cache / Revalidate
For public APIs:

```ts
export const revalidate = 60;
```

For authenticated APIs:

```ts
export const dynamic = "force-dynamic";
```

---

# 10.5 Pagination Pattern

> **Reference:** For the complete implementation of `executePaginatedQuery()`, see frameworks/nextjs/server-actions.md#7

Implement unified pagination for list retrieval APIs.

### Usage Example in Route Handler

```ts
// app/api/projects/route.ts
import { executePaginatedQuery } from "@/lib/actions/action-helpers";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const page = parseInt(searchParams.get("page") ?? "1");
  const limit = parseInt(searchParams.get("limit") ?? "20");

  const result = await executePaginatedQuery(prisma.project, {
    where: { isPublic: true },
    orderBy: { createdAt: "desc" },
    page,
    limit,
  });

  return Response.json(result);
}
```

### Response Format

```json
{
  "items": [...],
  "total": 50,
  "page": 1,
  "limit": 20,
  "totalPages": 3
}
```

---

# 11. Summary
* Use **Route Handlers** for external-facing APIs
* Use **Server Actions** for UI operations
* **Zod validation on all inputs**
* **Thorough authentication checks** with NextAuth
* Strict REST design + HTTP methods
* Webhooks (payment services, etc.) use Route Handlers only
* **Security headers are required** for Route Handlers
* Server Actions optimize UX through form integration
