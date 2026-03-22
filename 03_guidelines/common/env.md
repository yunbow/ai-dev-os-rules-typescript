# Environment Variables Guidelines

This document defines a design based on **server-only environment variables** for large-scale Next.js applications, ensuring no confidential information is ever passed to the client side. The deployment environment assumes **Vercel**, maximizing its security features.

---

## 1. Management Policy (Core Principles)

## 1. Enforce Server-Only

* `process.env.xxx` is used **only in Server Components / Route Handlers / Server Actions**
* Never directly expose to Client Components
* When Client needs data, **return only the minimum required via API Route** — "minimum" means: only public identifiers (e.g., payment Client ID) and non-sensitive configuration. Never return secrets, internal IDs, or data the client does not directly render.

---

## 2. .env Files for Local Only

* `.env.local`: Local use only (excluded from Git)
* `.env.production`: Generally not used; configure on the cloud side
* `.env.example`: List only the required key names (no values)

---

## 3. Application Code Separation

* Consolidate all external service configurations in `/src/lib/config/env.ts`
* **Validate with Zod**, outputting clear error messages on missing values

```ts
// lib/config/env.ts - Zod validation pattern (recommended)
import { z } from "zod";

const envSchema = z.object({
  // {AI_SERVICE}_API_KEY: AI API key used by the project
  AI_API_KEY: z.string().min(1, "AI_API_KEY is required"),
  OAUTH_CLIENT_ID: z.string().min(1, "OAUTH_CLIENT_ID is required"),
  DATABASE_URL: z.string().url("DATABASE_URL must be a valid URL"),
});

// Validate at startup (fail immediately on error)
export const env = envSchema.parse(process.env);
```

---

## 2. Primary Environment Variables

```bash
## Authentication (NextAuth)
NEXTAUTH_SECRET=
NEXTAUTH_URL=

## Database (Prisma)
DATABASE_URL=
DIRECT_URL=

## {Payment Service} (e.g., PayPal, Stripe, etc.)
{PAYMENT_SERVICE}_CLIENT_ID=
{PAYMENT_SERVICE}_CLIENT_SECRET=
{PAYMENT_SERVICE}_WEBHOOK_SECRET=

## OAuth
OAUTH_CLIENT_ID=
OAUTH_CLIENT_SECRET=

## {AI Service} (e.g., OpenAI, Gemini, etc.)
{AI_SERVICE}_API_KEY=
```

---

## 3. Development Environment (Local)

## Use .env.local

* DB = SQLite connection information
* Use sandbox keys / OAuth keys for testing
* `.env.local` must **never be committed to Git**

---

## 4. Production Environment (Vercel)

## Use Secure Environment Variables

* Encrypted, restricted to server-only during build and runtime
* **Environment Variables locking** (access permission management) recommended
* Configure from Project Settings → Environment Variables

### Features

* Automatically applied as server-only for Edge Functions
* Webhook Secrets are stored in the **Vercel Dashboard** (never exposed to Client)

### Additional Policies

* Separate variables for Previews / Production
* Rotate Secrets (periodic key rotation)

---

## 5. Secure Secret Usage Rules

## 1. Never Pass Directly to Client Components

* Example: Passing a payment service's Client Secret as props → **absolutely prohibited**

## 2. Provide Only Minimum Information via Route Handlers

* Only Public Keys may be exposed (e.g., payment service's Client ID)

## 3. Keep Webhook Secrets Server-Only

* Configure in the Vercel dashboard
* Hardcoding in code is prohibited

## 4. Never Output Keys in Logs

* `console.log(process.env.X)` is also prohibited

---

## 6. Leveraging Next.js Built-in Variable Loading

* Next.js exposes variables prefixed with `NEXT_PUBLIC_` to the client by default
* To enforce server-only, **never use the NEXT_PUBLIC_ prefix** except for intentionally public variables
* When loading via env.ts, handle all without prefix

---

## 7. Secret and Production Key Rotation Strategy

* Secret rotation is a mandatory security measure
* Document the following as operational rules:

  1. Who updates the keys
  2. When they are updated (e.g., quarterly)
  3. How they are updated (set new keys in Vercel, update dependent services)

---

## 8. Directory Structure (Environment Variable Related)

```text
src/
  lib/
    config/
      env.ts        # server-only env loader
      env.schema.ts # Zod validation
  app/
    api/...
  features/
    billing/
    calendar/
```

---

## 9. Improvements and Operational Notes

### Reconsidering Non-Null Assertion Usage in env.ts

* `PAYMENT_CLIENT_SECRET: process.env.PAYMENT_CLIENT_SECRET!` — the `!` is unnecessary
* Since Zod has already validated, remove `!` and export the Zod result directly

### Reviewing Environment Variables (Section 2)

* Clearly distinguish public and server-only variables in the list
* Classify with comments or prefixes (e.g., `NEXT_PUBLIC_{PAYMENT_SERVICE}_CLIENT_ID`)

---

## 10. Summary

* **All environment variables are operated as server-only**
* Type-safe env loading via `env.ts + Zod`
* **Use Vercel Secure Environment Variables**
* `.env.local` is local only, never included in Git
* Webhooks and API keys are processed securely on the Route Handler side
* Use the NEXT_PUBLIC_ prefix only for intentionally public variables
* Key rotation is clearly documented as operational rules
* Fail-fast design ensures immediate process termination on missing environment variables

## Before/After Example

```typescript
// ❌ Before: Accessing env vars directly without validation
const apiKey = process.env.AI_API_KEY!;
const dbUrl = process.env.DATABASE_URL!;
// Crashes at runtime with cryptic errors if missing
```

```typescript
// ✅ After: Validating env vars at startup with Zod
import { z } from "zod";
const envSchema = z.object({
  AI_API_KEY: z.string().min(1, "AI_API_KEY is required"),
  DATABASE_URL: z.string().url("DATABASE_URL must be a valid URL"),
});
export const env = envSchema.parse(process.env);
// Fails immediately with a clear message on startup
```
