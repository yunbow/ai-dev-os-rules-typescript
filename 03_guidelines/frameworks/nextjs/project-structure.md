# Project Structure Guidelines
This document summarizes the directory policies and architecture guidelines for designing large-scale web applications centered on Next.js large-scale applications.

# 1. Overall Principles
- Adopt **vertical slicing (feature-based) as the base structure**
  → Group UI / API / DB / types / validation / hooks / services per feature
- **Horizontal slicing is limited to shared functionality only**
  → Shared layers such as ui / lib / config / types / styles

---

# 2. Directory Structure

```
src/
├─ app/                    # Next.js App Router (page entry points)
│  ├─ (public)/            # Public pages (no authentication required)
│  ├─ (protected)/         # Authentication-required pages
│  ├─ api/                 # Route Handlers (REST API / Webhook / Cron)
│  └─ layout.tsx
│
├─ features/               # Core of vertical slicing (full-stack management per feature)
│  ├─ {domain}/             # Example: the most complex feature (core project domain)
│  │  ├─ components/       # Feature-specific UI components
│  │  ├─ hooks/            # Feature-specific React Hooks
│  │  ├─ server/           # Server Actions
│  │  ├─ services/         # Domain logic, API clients, DB operations
│  │  ├─ schema/           # Zod schemas
│  │  ├─ types/            # Feature-specific type definitions
│  │  ├─ context/          # React Context (state sharing within the feature)
│  │  ├─ config/           # Feature-specific configuration
│  │  ├─ constants/        # Feature-specific constants
│  │  └─ utils/            # Feature-specific utilities
│  ├─ admin/
│  ├─ auth/
│  ├─ billing/
│  ├─ settings/
│  └─ ...                  # Other features
│
├─ components/             # Shared components
│  ├─ ui/                  # shadcn/ui primitives (do not modify)
│  ├─ common/              # App-wide common UI (EmptyState, LoadingButton, etc.)
│  ├─ layout/              # Layout-related (Sidebar, Header, etc.)
│  ├─ form/                # Shared form components
│  ├─ table/               # Shared table components
│  ├─ dialog/              # Shared dialogs
│  ├─ filter/              # Shared filter UI
│  ├─ card/                # Shared cards
│  ├─ shared/              # Components shared across multiple features
│  ├─ providers/           # Global Providers
│  ├─ admin/               # Admin panel shared
│  ├─ analytics/           # Analytics / chart shared
│  ├─ compliance/          # Compliance shared
│  └─ dashboard/           # Dashboard shared
│
├─ lib/                    # Shared utility layer (no business logic allowed)
│  ├─ auth/                # NextAuth.js configuration
│  ├─ prisma/              # Prisma Client singleton
│  ├─ actions/             # Server Actions shared helpers (ActionResult, etc.)
│  ├─ errors/              # DomainError / error code definitions
│  ├─ api/                 # CORS, rate limiting, API clients
│  ├─ security/            # CSP, sanctioned countries, IP restrictions
│  ├─ config/              # Environment variable validation
│  ├─ format/              # Date / number formatting
│  ├─ schemas/             # Shared Zod schemas (pagination, etc.)
│  ├─ utils/               # General-purpose utilities
│  ├─ crypto/              # Encryption (AES-256-GCM)
│  ├─ cron/                # Cron job shared processing
│  ├─ external/            # External service clients
│  ├─ storage/             # LocalStorage key management
│  ├─ logger.ts            # Server-side logger (Pino)
│  ├─ client-logger.ts     # Client-side logger
│  ├─ email.ts             # Email sending
│  └─ utils.ts             # cn() utility
│
├─ hooks/                  # General-purpose React Hooks (useAsyncAction, useListData, etc.)
├─ config/                 # App-wide configuration
├─ types/                  # App-wide shared type definitions
├─ i18n/                   # next-intl configuration
├─ middleware.ts           # Edge Middleware
└─ instrumentation.ts     # OpenTelemetry instrumentation
```

---

# 3. Vertical Slice Design (Feature-based Architecture)

## 3.1 Internal Structure of a Feature

Select subdirectories based on the scale of the feature. Not all are required.

```
features/<feature-name>/
├─ components/       # Feature-specific UI components (required)
├─ server/           # Server Actions (required)
├─ schema/           # Zod validation schemas
├─ services/         # Domain logic, DB operations, external API calls
├─ types/            # Feature-specific type definitions
├─ hooks/            # Feature-specific React Hooks
├─ context/          # React Context (state sharing within the feature)
├─ config/           # Feature-specific configuration values
├─ constants/        # Feature-specific constants
└─ utils/            # Feature-specific utilities
```

## 3.2 Structure Examples by Scale

**Small-scale feature** (auth, contact, etc.):
```
auth/
├─ components/       # Login form, etc.
└─ server/           # Authentication Server Actions
```

**Medium-scale feature** (settings, admin, etc.):
```
settings/
├─ components/
├─ schema/
├─ server/
└─ utils/
```

**Large-scale feature** (core project domain, etc.):
```
{domain}/
├─ components/       # 50+ components
├─ hooks/            # 30+ hooks
├─ server/           # 20+ Server Actions
├─ services/         # 15+ services
├─ schema/
├─ types/
├─ context/
├─ config/
├─ constants/
└─ utils/
```

### Benefits
- Related code is consolidated in one place → easier to understand
- Extensions do not pollute other directories
- Easy to refactor or delete on a per-feature basis

---

# 4. Horizontal Slicing (Shared Layers)

| Folder | Clear Role |
|--------|--------|
| components/ui/ | **shadcn/ui primitives** (Button, Card, etc. — breaking changes prohibited) |
| components/common/ | **App-wide common UI** (EmptyState, LoadingButton, Pagination, etc.) |
| components/layout/ | **Layout** (Sidebar, Header, etc.) |
| components/shared/ | **Components shared across multiple features** |
| lib/ | **Shared processing not dependent on any specific domain** (dates, auth config, CORS, etc.)<br>* Data fetching or processing logic is prohibited |
| hooks/ | **General-purpose React Hooks** (useAsyncAction, useListData, etc.) |
| types/ | App-wide shared types |
| i18n/ | next-intl configuration |
| config/ | App-wide configuration |

---

# 5. Dependency Rules (Important)
## 5.1 Prohibited Practices
- **Cross-feature dependencies are prohibited** — if two features need shared logic, extract it to `lib/` or `components/shared/`
- **lib → features dependencies are prohibited**
- **components → features dependencies are prohibited**
- **app having deep dependencies on internal logic is prohibited** — `page.tsx` should call a service function or Server Action, not reach into feature internals

---

# 6. Server Actions Placement Rules (Strict)
- **Must be placed in `features/*/server/`**
- `src/server/` is **limited to the bare minimum for app-wide concerns** such as authentication and authorization
- Business logic should be consolidated in `services/`, and Server Actions should serve **only as the invocation gateway**

---

# 7. Next.js Role Separation Enhancement

| Element | Responsibility |
|-----|------|
| `page.tsx` (Server Component) | **Act solely as a data pass-through**:<br>Call functions from services/ or server/ and pass results to UI only |
| Client Component | UI / event handling |
| services/ | Domain logic, DB/external API access |
| server/ | Server Actions (invocation gateway from client) |

---

# 8. Guidelines for Extension

1. Create a `src/features/<new-feature>` directory
2. Keep components / server / schema, etc. **self-contained within it**
3. Add the UI entry point at `app/(protected)/<feature>/page.tsx`

---

# 9. Guidelines Summary

- **Vertical slice structure is the default**
- **Business logic must always be contained within features**
- **Server Actions placement responsibilities are strictly enforced**
- **lib/ must never contain domain-specific logic** — `lib/` is for infrastructure utilities (auth config, DB client, formatting, encryption). Domain logic (e.g., "calculate project completion percentage") belongs in `features/*/services/` because it changes with business requirements and should be co-located with related UI and schemas
- **page.tsx serves only as a data pass-through to the UI**
