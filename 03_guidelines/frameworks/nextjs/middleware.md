# Middleware Design Guidelines

This document defines the design policy and implementation patterns for **Edge Middleware** in Next.js App Router.
Since Middleware executes at the beginning of the request lifecycle, it serves as a cornerstone for authentication, security, and observability.

---

## 1. Core Principles

- **Single file design**: All middleware logic is consolidated in `src/middleware.ts`
- **Clear processing order**: Execute in the order of Security → Authentication → Routing → Header configuration
- **Edge Runtime compatible**: Use Web Standard APIs without depending on Node.js APIs

---

## 2. Middleware Processing Flow

```text
Request received
  │
  ▼
┌────────────────────────────────────────────┐
│ 1. Request ID generation                   │
│    Reuse existing header if present        │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 2. Security checks (early return)          │
│    - Sanctioned country block → 403        │
│    - Admin panel IP restriction → 403      │
│    - Maintenance mode → redirect           │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 3. Authentication check                    │
│    - Protected route auth check → login    │
│    - 2FA verification flow control         │
│    - Authenticated user redirect           │
└─────────────────────┬──────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ 4. Response header configuration           │
│    - CSP nonce generation                  │
│    - x-request-id                          │
│    - x-pathname / x-url                    │
│    - x-user-country                        │
└────────────────────────────────────────────┘
```

---

## 3. Request ID Generation and Propagation

### Purpose

- **Distributed tracing**: Link server logs, API logs, and external API calls to a single request
- **User support**: Users can provide the requestId to help identify logs for inquiries

### Implementation Pattern

```ts
// middleware.ts
function generateRequestId(): string {
  const timestamp = Date.now().toString(36);
  const randomPart = Math.random().toString(36).substring(2, 10);
  return `req_${timestamp}_${randomPart}`;
}

// Reuse existing header if present (e.g., set by external load balancer)
const requestId = req.headers.get("x-request-id") || generateRequestId();

// Set in response headers
response.headers.set("x-request-id", requestId);
```

### Rules

- While `crypto.randomUUID()` is available in Edge Runtime, a **short ID with prefix** is advantageous for readability and log searching
- Attach requestId to redirect responses as well

---

## 4. Security Checks

### 4.1 Sanctioned Country Blocking

Block access from specific countries based on international sanctions. **OFAC** (Office of Foreign Assets Control) is a U.S. Treasury Department agency that administers trade sanctions programs. Services accessible to users in sanctioned countries can expose the company to severe legal penalties (fines, criminal prosecution) under U.S. law, even for non-U.S. companies that process USD transactions or have U.S. nexus.

```ts
// lib/security/sanctioned-countries.ts
export const SANCTIONED_COUNTRIES = ["CU", "IR", "KP", "SY", "RU"] as const;

export function isSanctionedCountry(countryCode: string): boolean {
  if (!countryCode) return false;
  return SANCTIONED_COUNTRIES.includes(countryCode.toUpperCase());
}
```

```ts
// Usage in middleware.ts
const country =
  req.headers.get("x-vercel-ip-country") ||
  req.headers.get("cf-ipcountry") ||
  "";

if (isSanctionedCountry(country)) {
  return new NextResponse("Access denied", { status: 403 });
}
```

**Country code source (priority order)**:

1. `x-vercel-ip-country` (automatically set by Vercel)
2. `cf-ipcountry` (automatically set by Cloudflare)
3. Custom headers (AWS ALB, etc.)

### 4.2 Admin Panel IP Restriction

Restrict access to the admin panel (`/admin`) to allowed IP addresses only.

```ts
// lib/security/admin-ip-restriction.ts

export function isAdminIpAllowed(clientIp: string | null): boolean {
  const allowedIps = getAllowedIps(); // Environment variable ADMIN_ALLOWED_IPS

  // No restriction if not configured
  if (!allowedIps) return true;

  // Block if IP cannot be obtained
  if (!clientIp) return false;

  // Treat IPv6 loopback as IPv4 loopback
  const normalizedIp = clientIp === "::1" ? "127.0.0.1" : clientIp;

  for (const allowed of allowedIps) {
    if (allowed.includes("/")) {
      if (matchesCidr(normalizedIp, allowed)) return true;
    } else {
      if (normalizedIp === allowed) return true;
    }
  }

  return false;
}
```

**Key points**:

- Specify via environment variable `ADMIN_ALLOWED_IPS` as comma-separated values (e.g., `203.0.113.1,192.168.1.0/24`)
- **CIDR notation support**: Allows subnet-level permissions
- No restriction when unset (convenience for development environments)
- Defaults to blocking when IP cannot be obtained (fail-safe)

### 4.3 Maintenance Mode

Enable maintenance mode via environment variable and redirect all users to the maintenance page.

```ts
// middleware.ts
if (
  process.env.MAINTENANCE_MODE === "true" &&
  pathname !== "/maintenance" &&
  !isAdminIpAllowed(clientIp)
) {
  return NextResponse.redirect(new URL("/maintenance", req.url));
}
```

**Key points**:

- **Admin IPs bypass**: Normal access is possible from IPs included in `ADMIN_ALLOWED_IPS`
- Prevent infinite redirects to the maintenance page itself
- Switchable via environment variable only (no deployment needed)

### 4.4 Client IP Retrieval

Obtain the correct client IP even behind proxies.

```ts
const clientIp =
  req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
  req.headers.get("x-real-ip") ||
  null;
```

| Header | Set By |
|--------|--------|
| `x-forwarded-for` | Vercel / AWS ALB / Nginx |
| `cf-connecting-ip` | Cloudflare |
| `x-real-ip` | Nginx |

---

## 5. Authentication Checks

### 5.1 Protected Route Definition

```ts
const protectedRoutes = [
  "/dashboard",
  "/project",
  "/settings",
  "/quick-start",
];

const isProtectedRoute = protectedRoutes.some((route) =>
  pathname.startsWith(route),
);

if (isProtectedRoute && !isLoggedIn) {
  return redirectTo("/login");
}
```

### 5.2 2FA Flow Control

Restrict access to protected routes for users with 2FA enabled until verification is complete.

```ts
// Get 2FA requirement flag from session
const requiresTwoFactor = req.auth?.requiresTwoFactor === true;

// Get 2FA verification completion status from cookie
const twoFactorVerified = req.cookies.get("2fa-verified")?.value === "true";

// 2FA verification required but not completed → redirect to verification page
if (isLoggedIn && requiresTwoFactor && !twoFactorVerified) {
  if (pathname !== "/verify-2fa") {
    return redirectTo("/verify-2fa");
  }
}
```

**Why a cookie for 2FA status instead of the session/JWT**: The 2FA verification happens *after* the initial login, so the session already exists with `requiresTwoFactor: true`. Storing the verification result back into the JWT would require re-signing the token on every 2FA completion, which is not possible in Edge Middleware (no DB access). A short-lived, httpOnly, secure cookie provides a lightweight signal that the second factor has been verified for this browser session, without modifying the JWT.

**Flow**:

1. Login succeeds → Set `requiresTwoFactor: true` in session
2. Middleware redirects to 2FA verification page
3. 2FA code input and verification succeeds → Set `2fa-verified` cookie
4. Subsequent requests proceed with normal access

### 5.3 Authenticated User Redirect

```ts
// Logged in user accessing login page → redirect to dashboard
if (pathname === "/login" && isLoggedIn) {
  if (requiresTwoFactor && !twoFactorVerified) {
    return redirectTo("/verify-2fa");
  }
  return redirectTo("/dashboard");
}
```

---

## 6. CSP (Content Security Policy) Nonce

### Purpose

- Prevent XSS attacks
- Eliminate `'unsafe-inline'` and transition to nonce-based script authorization

### Implementation Pattern

```ts
// middleware.ts
const nonce = Buffer.from(crypto.randomUUID()).toString("base64");
const cspHeader = buildCspHeader(nonce);

// Add nonce to request headers (to make it accessible in Server Components)
const requestHeaders = new Headers(req.headers);
requestHeaders.set("x-nonce", nonce);

const response = NextResponse.next({
  request: { headers: requestHeaders },
});

response.headers.set("Content-Security-Policy", cspHeader);
```

```ts
// lib/security/csp.ts
export function buildCspHeader(nonce: string): string {
  const directives: Record<string, string[]> = {
    "default-src": ["'self'"],
    "script-src": [
      "'self'",
      `'nonce-${nonce}'`,
      "'strict-dynamic'",
      ...(isProduction ? [] : ["'unsafe-eval'"]),
    ],
    "style-src": ["'self'", "'unsafe-inline'"],
    "img-src": ["'self'", "data:", "blob:", ...allowedImageHosts],
    "frame-ancestors": ["'none'"],
    "form-action": ["'self'"],
    "base-uri": ["'self'"],
    "object-src": ["'none'"],
  };

  return Object.entries(directives)
    .map(([key, values]) => `${key} ${values.join(" ")}`)
    .join("; ");
}
```

**Key points**:

- Allow `'unsafe-eval'` in development environments (required for HMR)
- Establish trust chain with `'strict-dynamic'`
- Explicitly add external API domains to `connect-src`

---

## 7. Response Header Configuration

Standard headers attached to responses by Middleware:

| Header | Purpose | Example |
|--------|---------|---------|
| `x-request-id` | Distributed tracing | `req_m5k2j_a8b3c4d5` |
| `x-pathname` | Path retrieval in Server Components | `/dashboard` |
| `x-url` | Full URL retrieval | `https://example.com/dashboard?tab=1` |
| `x-nonce` | CSP nonce (on request header side) | `YTJlMzQ1...` |
| `x-user-country` | Geographic information | `JP` |
| `Content-Security-Policy` | CSP policy | `default-src 'self'; ...` |

---

## 8. Matcher Configuration

Define path patterns to which Middleware is applied.

```ts
export const config = {
  matcher: [
    // Exclude API, static files, image optimization, and favicon
    "/((?!api|_next/static|_next/image|favicon.ico).*)",
  ],
};
```

**Paths to exclude**:

- `/api/*` — API Routes have their own authentication
- `/_next/static/*` — Static assets
- `/_next/image/*` — Image optimization
- `/favicon.ico` — Favicon

---

## 9. Security Module Placement

```text
src/
  middleware.ts                           # Middleware body (invocation only)
  lib/
    security/
      csp.ts                             # CSP header generation
      sanctioned-countries.ts            # Sanctioned country list and determination
      admin-ip-restriction.ts            # Admin panel IP restriction
      suspicious-login-detector.ts       # Suspicious login detection
```

**Principles**:

- `middleware.ts` **does not contain decision logic** (invocation only)
- Decision and generation logic is placed in `/lib/security/`
- Unit tests are performed on individual modules

---

## 10. Best Practices

### DO (Recommended)

```ts
// ✅ Attach request ID to redirects as well
function createRedirectWithRequestId(url: URL, requestId: string) {
  const response = NextResponse.redirect(url);
  response.headers.set("x-request-id", requestId);
  return response;
}

// ✅ Separate decision logic into separate modules
import { isAdminIpAllowed } from "@/lib/security/admin-ip-restriction";

// ✅ Switch modes via environment variables (no deployment needed)
if (process.env.MAINTENANCE_MODE === "true") { ... }
```

### DON'T (Not Recommended)

```ts
// ❌ Hardcoding complex decision logic directly in Middleware
if (ip === "1.2.3.4" || ip === "5.6.7.8") { ... }

// ❌ Executing DB access in Middleware (limited in Edge Runtime)
const user = await prisma.user.findUnique({ ... });

// ❌ Executing heavy processing in Middleware (increases latency)
const result = await fetch("https://external-api.com/check", { ... });

// ❌ Making matcher too broad (impacts performance)
export const config = { matcher: ["/:path*"] };
```

---

## 11. Edge Runtime Constraints

Middleware runs in Edge Runtime, so the following constraints apply:

| Constraint | Resolution |
|-----------|-----------|
| Node.js APIs unavailable | `fs`, `path`, etc. cannot be used |
| No direct DB access | Prisma Client cannot be used |
| Execution time limit | Vercel: 25 seconds (Edge Functions) |
| Bundle size limit | Must be under 1MB |
| Encryption | `crypto.randomUUID()` is available |

---

## 12. Summary

| Feature | Implementation Location | Purpose |
|---------|------------------------|---------|
| Request ID | middleware.ts | Distributed tracing |
| Sanctioned country blocking | lib/security/sanctioned-countries.ts | Legal compliance |
| Admin panel IP restriction | lib/security/admin-ip-restriction.ts | Admin panel protection |
| Maintenance mode | middleware.ts | Operations management |
| Authentication check | middleware.ts + auth() | Route protection |
| 2FA flow control | middleware.ts | Multi-factor authentication |
| CSP nonce | lib/security/csp.ts | XSS prevention |
| Header configuration | middleware.ts | Observability / SEO |
