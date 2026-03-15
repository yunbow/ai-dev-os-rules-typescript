# Overview

> **Note:** The technology stack below is a sample configuration. Replace libraries based on your project's requirements. Files marked with `[Replaceable]` in this directory contain library-specific patterns — update the corresponding files when switching libraries.

## Purpose
This is a guideline for designing large-scale applications centered on Next.js large-scale applications, balancing stability, observability, extensibility, and developer productivity.

## Technology Stack
- Next.JS Latest Version
  - Routing & Navigation
  - SSR/SSG & Data Fetching
  - Metadata
  - API Route Handling
  - Image Optimization
  - Environment Variables
  - Code Splitting & Build
- Form Management: React Hook Form
- Server State Management: Server Actions + Custom Hooks (useAsyncAction, useListData, etc.)
- Styling: Tailwind CSS + shadcn/ui
- Authentication: NextAuth.js
- AI Generation: {AI API} (Choose based on project: OpenAI, Google Gemini, Anthropic, etc.)
- Database ORM: Prisma (SQLite)
- Validation: Zod
- Internationalization: next-intl
- Logger: Pino

### Replaceable Libraries

| Category | Current | Alternatives | Related Files |
|----------|---------|-------------|---------------|
| State Management | Server Actions + Custom Hooks | TanStack Query, SWR | `state.md`, `client-hooks.md` |
| Form Management | React Hook Form | Conform, Formik | `form.md` |
| UI Components | Tailwind CSS + shadcn/ui | MUI, Mantine, Ant Design | `ui.md` |
| Authentication | NextAuth.js | Clerk, Lucia, Auth0 | `auth.md` |
| Database ORM | Prisma (SQLite) | Drizzle, Kysely; PostgreSQL, Turso | `database.md` |
| Server Communication | Server Actions (ActionResult) | tRPC | `server-actions.md` |
| Validation | Zod | Valibot, ArkType | `form.md`, `server-actions.md` |

The following are used according to functional requirements
- Payment Processing: {Payment Service} (Choose based on project: Stripe, PayPal, etc.)

The following cloud services are used
- {Cloud Provider} (AI API, Storage, etc.)
- Vercel (Hosting / Cron)

## Basic Principles
Unified data fetching/mutation via Server Actions (not client-side fetch or global state libraries), automated testing / CI/CD
