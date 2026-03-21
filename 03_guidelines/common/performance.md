# Performance Guidelines

This document covers only performance optimization items that **do not clearly overlap** with content covered in other documents.

**Related documents:**

- DB query optimization (N+1, indexes, take) → frameworks/nextjs/database.md
- API caching → frameworks/nextjs/api.md
- Server Actions + custom hook state management → frameworks/nextjs/state.md

---

## 1. Rendering & Server Components Optimization
### Use Server Components by Default
* Implement as Server Components whenever possible to minimize bundle size.
* Only add `use client` when UI interaction is required.

### RSC → CC "Hole Punching" Pattern
Decision rule for where to place the RSC/CC boundary:
* **Use RSC** when the component only displays data (no onClick, onChange, useState, useEffect)
* **Use CC** when the component needs browser APIs or user interaction
* At the boundary: fetch data in RSC, pass only the **minimal serializable props** to child Client Components
* Do not fetch from CC (to prevent duplicate fetches and bundle bloat)
* If a CC needs server data, lift the fetch to the nearest RSC ancestor and pass it down

---

## 2. Client Bundle Optimization (Client Components)
### Dynamic Import of Heavy Components

SHOULD use `next/dynamic` for client components that are heavy, below the fold, or conditionally rendered:

```ts
import dynamic from "next/dynamic";

// ✅ Heavy editor loaded only when needed
const RichTextEditor = dynamic(() => import("./RichTextEditor"), {
  ssr: false,
  loading: () => <div className="h-64 animate-pulse bg-muted rounded" />,
});

// ✅ Modal/dialog loaded on demand
const CreateTaskDialog = dynamic(() => import("./CreateTaskDialog"));

// ✅ Chart component (large dependency) deferred
const AnalyticsChart = dynamic(() => import("./AnalyticsChart"), { ssr: false });
```

Candidates for dynamic import:
* Rich text editors, code editors, markdown renderers
* Chart/graph components (recharts, chart.js)
* Modal/dialog content that is not visible on initial load
* Admin-only components on pages accessible to all users
* Any component importing a dependency > 50KB

### Use Tree-Shakable Imports Consistently
* `import { X } from 'lodash'` — avoid (imports entire library)
* `import debounce from 'lodash/debounce'` — preferred (imports only the function)

### Avoid Large Libraries Like Moment.js
* Day.js / date-fns are recommended.

---

## 3. Image Optimization (Next.js Image)

### External Domain Image Optimization Settings (Important)

Even when using Next.js `<Image>`, external images **will not be optimized without domain configuration in next.config.js**.

```js
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'example.com',
      },
    ],
  },
};
```

Forgetting this can cause build errors or disable optimization.

### Design With CDN (Vercel / Amplify) Caching in Mind
* Static images: bundle at build time
* Dynamic images: set Cache-Control headers

---

## 4. Font Optimization

### Use Next.js `next/font`

```ts
import { Inter } from "next/font/google";
const inter = Inter({ subsets: ["latin"], weight: ["400", "700"] });
```

### Use SVGs Instead of Icon Fonts

* shadcn/ui + lucide-react is recommended.

---

## 5. CSS / Sass Optimization (Enhanced Bundle Optimization)

### Recommend Static CSS-Based Approaches

* Tailwind CSS
* CSS Modules
* Vanilla Extract
  → **Runtime CSS-in-JS is discouraged due to increased bundle size and client-side JS bloat**

### Reduce Unused CSS

* Use Tailwind's `content` configuration to eliminate unused classes
* For Sass/CSS Modules, use PurgeCSS or similar tools to remove unused CSS

---

## 6. Caching Strategy (Non-Overlapping Items Only)

### Leverage fetch Cache

```ts
fetch(url, { next: { revalidate: 60 } })
```

### Cache-Control for Route Handlers

```ts
return new Response(JSON.stringify(data), {
  headers: { "Cache-Control": "s-maxage=60" }
});
```

---

## 7. Re-render Optimization (Client Components)

### Proper Use of useCallback / useMemo

* Use only when the computation takes **>2ms per render** or the component renders lists of **100+ items** — profile with React DevTools before adding memoization
* **Ensure dependency array accuracy**

```tsx
// ❌ Creates a new object every render
const options = { page: 1, limit: 10 };
useEffect(() => {
  fetchData(options);
}, [options]); // Infinite loop

// ✔ Stabilize with useMemo
const options = useMemo(() => ({ page: 1, limit: 10 }), []);
useEffect(() => {
  fetchData(options);
}, [options]);
```

### Prevent Props Drilling
* Overusing Context can be counterproductive; **local context pattern** is recommended.

### Stabilize Keys
* Prohibit index keys
* Use unique IDs

---

## 8. List / Table / Infinite Scroll Optimization
### Use Virtualization
* react-window / react-virtualized

### Partial Suspense Splitting

```tsx
<Suspense fallback={<LoadingSkeleton />}>
  <LargeTable />
</Suspense>
```

---

## 9. Memory / CPU Cost Optimization

### Avoid Excessive Use of JSON.parse / JSON.stringify

### Use Web Workers for Heavy Processing
* Markdown parsing
* Image processing
* Audio processing

---

## 10. Network Optimization
### Chunk Prefetching
### Reduce Excessive API Calls
* Minimize fetching in Client Components; aggregate on the RSC side.

---

## 11. SEO + Web Vitals
### Measure Web Vitals in CI
* Monitor LCP / FID / CLS

### CLS Countermeasures
* Display skeletons
* Fix heights for images, cards, and ads

---

## 12. Mobile Optimization
### Ensure Tap Targets Meet Minimum Size (44px+)
### Prohibit Hover-Dependent UI
* Reduce unnecessary client-side JS.

---

## 13. Edge Functions / CDN Placement
### Use Edge APIs for Parts That Don't Require Authentication
### Static HTML Generation (SSG / ISR)
* Maximize Edge cache utilization.

---

## 14. Profiling
### React Profiler
### Chrome Performance Panel
### Next.js Bundle Analyzer

```bash
npm run analyze
```
