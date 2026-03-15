# Next.js Design Guidelines
This chapter summarizes routing design, page hierarchy, data fetching strategies, and Metadata design for Next.js large-scale applications.

---

# 1. Routing (App Router)
Based on Next.js 13+ **App Router (/app) structure**.

## 1.1 App Router Basic Principles
* Place shared UI, global wrappers, authentication guards, and role controls in `layout.tsx`.
* Each page should provide the following as needed:
  * `loading.tsx` ... Suspense loading display
  * `error.tsx` ... Error handling (supports both server & client)
  * `not-found.tsx` ... Custom 404

## 1.2 Dynamic Routes
Utilize dynamic routing to design clear and consistent URLs.

```
Example:
/app/posts/[slug]/page.tsx
/app/users/[id]/settings/page.tsx
```

### Catch-all Route

Use **catch-all** or **optional catch-all** when complex hierarchies are needed.

```
/app/docs/[...slug]/page.tsx
```

---

# 2. Navigation (Transition Design)

### 2.2 Sub-layout Structure
* Feature-specific layouts enable UI consistency and separation of concerns.
* Examples: Dashboard-specific layout / Public page layout / Authentication layout

---

# 3. Metadata (SEO / OGP / Twitter Cards)
Use the Next.js **Metadata API**.

## 3.1 Basic Principles
* Define `export const metadata` in each page (`page.tsx`).
* Place global default settings in `app/layout.tsx`.
* Override metadata in child pages when the page has unique content that differs from the layout defaults — for example, a blog post page should override `title` and `description` with the post's actual title/excerpt, and product pages should set product-specific OG images.

```ts
// Example:
export const metadata = {
  title: "Article Detail Page",
  description: "Blog article content",
  openGraph: {
    title: "Article Detail Page",
    description: "Blog article content",
    images: ["/og/post.png"],
  },
  twitter: {
    card: "summary_large_image",
  },
};
```

## 3.2 Dynamic Metadata (Dynamic Route Support)
* For Dynamic Routes (e.g., `/posts/[slug]`),
  use `generateMetadata()` to dynamically generate **SEO information based on params or fetched results**.

```ts
export async function generateMetadata({ params, searchParams }) {
  // Fetch title and description from DB / API and return
}
```

---

# 4. Data Fetching (SSR / SSG / ISR Strategy)
Data fetching strategy optimized for Next.js App Router recommended patterns.

## 4.1 Public Content (SEO-focused)
* Use Static Site Generation (SSG) + ISR (Incremental Static Regeneration) as the default.
* In App Router, combine the following:
  * `generateStaticParams`
  * `fetch` with `next: { revalidate: <seconds> }`

## 4.2 User-specific Data (Authenticated User Information)

> **Reference:** For detailed implementation patterns of Server Actions + custom hooks, see frameworks/nextjs/state.md

* Render initial content with SSR (Server Component).
* On the client, use **Server Actions + custom hooks** (useAsyncAction, useListData, useTableState) to achieve **state management, loading, and error handling**.
* Combine with `useOptimistic` to achieve both secure server updates and real-time UI updates.

Benefits:
* Secure (authentication tokens can be handled server-side)
* Fast initial rendering
* Fast client-side state updates

## 4.3 Frequently Changing UI Data / Real-time
* Use **Server Actions + custom hooks** on the client side to handle high-frequency updates.
* Combine with WebSocket / EventSource / Server Sent Events for real-time updates.

## 4.4 Responsibilities of Server Components and Client Components

| Server Components | Client Components |
| --- | --- |
| DB queries (hide auth info and env vars, direct access without going through the API layer) | Interactive UI, forms (React Hook Form) |
| Auth checks, external API calls | Data fetching/mutation via Server Actions + custom hooks (useAsyncAction, useListData) |
| Heavy computation | Instant UI updates via `useOptimistic` |

---

# 5. Summary (Routing / Metadata / Data Fetching)
* Organize hierarchy with App Router and separate concerns at the layout level.
* Unify UX with per-page `loading.tsx` / `error.tsx`.
* Public pages use SSG/ISR; user-specific data uses SSR + Server Actions + custom hooks.
* Flexibly and dynamically control SEO/OG/Twitter via the Metadata API.
* Achieve DB access that balances security and performance through Server Components.
