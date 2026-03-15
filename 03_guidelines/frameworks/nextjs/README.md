# Next.js (App Router) Guidelines

Framework-specific guidelines for Next.js App Router projects.
See [overview.md](./overview.md) for the full technology stack and replaceable library table.

## File List

| File | Topic | Replaceable Library |
|------|-------|-------------------|
| [overview.md](./overview.md) | Technology Stack & Replaceable Libraries | — |
| [project-structure.md](./project-structure.md) | Directory Structure & Architecture | — |
| [routing.md](./routing.md) | Routing, Navigation, Metadata, Data Fetching | — |
| [api.md](./api.md) | API Design (Route Handlers vs Server Actions) | — |
| [server-actions.md](./server-actions.md) | Server Actions & ActionResult Pattern | tRPC |
| [client-hooks.md](./client-hooks.md) | Custom Hooks (useAsyncAction, useListData, etc.) | TanStack Query, SWR |
| [state.md](./state.md) | State Management | TanStack Query, SWR |
| [form.md](./form.md) | Form Management & Validation | Conform, Formik, Valibot |
| [ui.md](./ui.md) | UI Components & Styling | MUI, Mantine, Ant Design |
| [auth.md](./auth.md) | Authentication & Authorization | Clerk, Lucia, Auth0 |
| [database.md](./database.md) | Database & ORM | Drizzle, Kysely, PostgreSQL |
| [middleware.md](./middleware.md) | Edge Middleware Design | — |
| [format.md](./format.md) | Date, Number & Currency Formatting | — |
| [build.md](./build.md) | Build Optimization & Code Splitting | — |

> Files marked with a replaceable library contain `[Replaceable]` notes at the top. The architectural principles remain the same regardless of the library chosen.
