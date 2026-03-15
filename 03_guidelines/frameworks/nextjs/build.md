# Build Guidelines
This document formulates a Code Splitting strategy to maximize Next.js build optimization features (App Router + Turbopack + Server Components), with the goals of **fast initial load**, **reduced runtime cost**, and **improved maintainability**.

---

# 1 Build Strategy (Build Optimization)
## 1. Adopt Server Components by Default
- Server Components are the standard in App Router
- Server Components send **zero JavaScript to the client** — their output is streamed as serialized React elements (RSC payload), not executable JS. This means a page composed entirely of Server Components has no hydration cost and the browser only downloads HTML and the RSC runtime (~5KB). Each Client Component you add increases the JS bundle that must be downloaded, parsed, and hydrated.
- Extract only interactive parts into Client Components

### Processing Suited for Server Components
- DB/Prisma queries
- Authentication (NextAuth)
- External API calls
- SSG/SSR data fetching
- Static layouts

### Addendum: Caching Strategy for the Data Fetching Layer
- DB/API calls in Server Components should leverage **React's `cache` function and Next.js fetch extensions** to prevent duplicate calls
- Designing a caching strategy can reduce both build time and runtime cost

---

## 2. Minimize Client-Side Code
- Limit where `use client` is applied to the minimum
(Only for forms, interactions, and dynamic UI)
- Import only the necessary parts of third-party UI libraries
  - shadcn/ui has good compatibility as it supports tree-shaking

### The "Waterfall" Problem with imports and use client
- Directly importing many Server Components inside a Client Component risks including unnecessary code in the client bundle
- **Design principle:** Keep Server Components as "leaves" — meaning Server Components should be at the bottom of the component tree, not wrapped inside Client Components. When a Client Component imports a Server Component directly, the bundler cannot separate them and the Server Component's code gets included in the client bundle. Instead:
  - Only pass `children` props to Client Components (composition pattern)
  - Pass necessary data from parent Server Components as serializable props
  - This preserves the zero-JS benefit of Server Components while allowing interactivity where needed

---

## 3. Fast Builds with Turbopack (Development) / SWC (Production)
- Leverage the latest Next.js build toolchain
- The speed difference is especially notable for large applications

---

## 4. Leveraging Vercel Optimizations
- **Vercel**: Edge cache + On-demand ISR
→ Bundle separation directly translates to deployment unit optimization

### Addendum: Comprehensive Use of Next.js Caching
- Request Memoization
- Data Cache (fetch)
- Full Route Cache (App Router)
- Combining these with edge caching maximizes optimization

---

# 2 Code Splitting Guidelines (App Router)
## 1. App Router Automatic Code Splitting
- Automatic splitting by each `page.tsx` and `layout.tsx` unit
- Generates independent JS/HTML bundles per route
- Initial load only fetches the required route

---

## 2. Third-Party Library Splitting

* Payment service SDKs (Stripe, PayPal, etc.)
* Chart.js
* Rich-text editors
* Date pickers

Use dynamic imports for these to avoid loading them on unnecessary pages.

---

# 3 SSG / SSR Strategy and Build Load
## SSG (Static Generation)
* Public pages (blogs, landing pages, help, etc.) use SSG + ISR
* Avoid overusing generateStaticParams as it increases build time
* Adopt On-demand ISR for sites with many pages

## SSR (Server-Side Rendering)
* User-specific data such as dashboards use SSR
* SSR can compress bundle size
* Works well with Vercel's fast edge execution

---

# 4 Bundle Size Optimization Checklist (Practical)
## 1. Introduce next-bundle-analyzer
Visualize whether dependency libraries are becoming bloated.

## 2. Import Only Necessary Parts of State Management / Data Fetching Libraries
* Custom hooks (useAsyncAction / useListData) should only be used in the components that need them
* Avoid singletons for Zustand stores

## 3. Lighten Images with Image Optimization
* Use automatic optimization via Next.js `<Image />`

---

# 5 Directory Structure Proposal (Build / Splitting Perspective)

```
src/
  app/
    dashboard/
      page.tsx          // Server Component
      client-panel.tsx  // Client Component (consider dynamic import)
    posts/
      [slug]/page.tsx   // SSR/SSG
    (public)/...        // Public area
    (auth)/login/...
  components/
    charts/             // Assumed to use dynamic import
    editors/
    modals/
```

---

# 6 Summary
* **Next.js App Router code splitting is automated at the route level**
* **Minimize Client Components and dynamically import only what's needed**
* **Keep Server Components as "leaves"** — use the children/composition pattern to avoid pulling Server Component code into client bundles
* **Introduce caching strategy for the data fetching layer**
  * Eliminate duplicates with React `cache` / Next.js fetch extensions
* **Comprehensively leverage Next.js caching strategies (Request Memoization / Data Cache / Full Route Cache)**
* **Design with Vercel Edge & SSR optimization as a prerequisite**
* **Optimize build time and browsing speed by choosing between SSG/SSR/ISR appropriately**
* **Visualize dependencies with bundle analyzer and continuously optimize**
