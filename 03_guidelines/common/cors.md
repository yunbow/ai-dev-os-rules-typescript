# CORS Design Guidelines

This document defines the design policy and implementation patterns for **CORS (Cross-Origin Resource Sharing)** in Next.js App Router.
It provides a unified CORS utility for securely accepting requests from external origins in API Routes.

---

## 1. Core Policy

- **Configurable via environment variables**: Permitted origins can vary by deployment environment
- **Wildcard subdomain support**: Use `*.example.com` format to allow multiple subdomains at once
- **Webhook protection**: Replay attack prevention via timestamp validation
- **Referer validation**: Referer header validation as a CSRF countermeasure

---

## 2. Directory Structure

```
src/
  lib/
    api/
      cors.ts              # CORS utility (scope of this guideline)
  app/
    api/
      webhook/
        [service]/route.ts # Webhook endpoints (CORS usage example)
```

---

## 3. Allowed Origin Management

### Configuration via Environment Variables

```ts
// lib/api/cors.ts

const getAllowedOrigins = (): string[] => {
  const envOrigins = process.env.ALLOWED_ORIGINS?.split(",").map((o) =>
    o.trim()
  );

  // Default allowlist: used when ALLOWED_ORIGINS env var is not set.
  // Includes localhost for development and auto-detected deployment URLs.
  const defaultOrigins = [
    "http://localhost:3000",
    "http://localhost:3001",
    process.env.NEXT_PUBLIC_APP_URL,
    process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : null,
  ].filter((o): o is string => Boolean(o));

  return envOrigins ?? defaultOrigins;
};
```

**Key points:**
- Specify via comma-separated `ALLOWED_ORIGINS` environment variable (e.g., `https://app.example.com,https://admin.example.com`)
- When `ALLOWED_ORIGINS` is not set, falls back to: localhost:3000, localhost:3001, `NEXT_PUBLIC_APP_URL`, and auto-detected `VERCEL_URL`
- Automatically allow `VERCEL_URL` during Vercel deployments

---

## 4. Origin Validation

### Validation Function

```ts
export function validateOrigin(
  req: Request,
  options: { allowedOrigins?: string[] } = {}
): { valid: boolean; origin: string | null } {
  const origin = req.headers.get("origin");
  const allowedOrigins = options.allowedOrigins ?? getAllowedOrigins();

  // Allow requests without an origin (same-origin requests, etc.)
  if (!origin) {
    return { valid: true, origin: null };
  }

  // Wildcard support (*.example.com)
  const isAllowed = allowedOrigins.some((allowed) => {
    if (allowed.startsWith("*.")) {
      const domain = allowed.slice(2);
      return origin.endsWith(domain);
    }
    return origin === allowed;
  });

  return { valid: isAllowed, origin };
}
```

### Wildcard Subdomains

```
ALLOWED_ORIGINS=https://app.example.com,*.example.com
```

Specifying `*.example.com` allows all subdomains such as `staging.example.com`, `preview-123.example.com`, etc.

---

## 5. CORS Response Header Generation

```ts
export function corsHeaders(
  req: Request,
  options: {
    allowedMethods?: string[];
    allowedHeaders?: string[];
    maxAge?: number;
    credentials?: boolean;
  } = {}
): HeadersInit {
  const {
    allowedMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders = ["Content-Type", "Authorization", "X-Request-ID"],
    maxAge = 86400,
    credentials = true,
  } = options;

  const origin = req.headers.get("origin");
  const allowedOrigins = getAllowedOrigins();

  // Only return the origin if it's in the allowlist
  const allowOrigin = origin && allowedOrigins.some((allowed) => {
    if (allowed.startsWith("*.")) {
      return origin.endsWith(allowed.slice(2));
    }
    return origin === allowed;
  })
    ? origin
    : allowedOrigins[0] ?? "";

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": allowedMethods.join(", "),
    "Access-Control-Allow-Headers": allowedHeaders.join(", "),
    "Access-Control-Max-Age": maxAge.toString(),
    ...(credentials && { "Access-Control-Allow-Credentials": "true" }),
  };
}
```

**Key points:**
- `Access-Control-Allow-Origin` returns the request's origin as-is (not `*`)
- When `credentials: true`, `*` cannot be used (browser will reject it)
- `Max-Age` caches preflight results (default: 24 hours)

---

## 6. Preflight Request Handling

```ts
export function handleCorsPreflightRequest(req: Request): Response {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(req),
  });
}
```

### Usage Example in API Routes

```ts
// app/api/webhook/route.ts
import { validateOrigin, corsHeaders, handleCorsPreflightRequest } from "@/lib/api/cors";

export async function OPTIONS(req: Request) {
  return handleCorsPreflightRequest(req);
}

export async function POST(req: Request) {
  const originCheck = validateOrigin(req);
  if (!originCheck.valid) {
    return new Response("Forbidden", {
      status: 403,
      headers: corsHeaders(req),
    });
  }

  // ... business logic

  return Response.json(result, {
    headers: corsHeaders(req),
  });
}
```

---

## 7. Timestamp Validation (Replay Attack Prevention)

Prevent replay attacks from old request resends in Webhook and external API integrations.

```ts
export function validateTimestamp(
  timestamp: string | number,
  maxAgeMs: number = 5 * 60 * 1000 // Default: 5 minutes
): { valid: boolean; error?: string } {
  const eventTime =
    typeof timestamp === "number"
      ? timestamp
      : new Date(timestamp).getTime();

  if (isNaN(eventTime)) {
    return { valid: false, error: "Invalid timestamp format" };
  }

  const now = Date.now();
  const age = now - eventTime;

  // Reject requests that are too old
  if (age > maxAgeMs) {
    return {
      valid: false,
      error: `Timestamp too old: ${Math.round(age / 1000)}s ago`,
    };
  }

  // Also reject future timestamps
  if (age < -maxAgeMs) {
    return {
      valid: false,
      error: `Timestamp in future: ${Math.round(-age / 1000)}s ahead`,
    };
  }

  return { valid: true };
}
```

**Key points:**
- Reject not only past but also future timestamps (timestamp tampering prevention)
- Default tolerance is 5 minutes (accounting for network latency)
- Supports both ISO 8601 strings and Unix milliseconds

---

## 8. Referer Validation

Validate Referer headers as a CSRF countermeasure.

```ts
export function validateReferer(
  req: Request,
  options: { allowedDomains?: string[] } = {}
): { valid: boolean; referer: string | null } {
  const referer = req.headers.get("referer");
  const allowedDomains =
    options.allowedDomains ?? getAllowedOrigins().map((o) => new URL(o).host);

  if (!referer) {
    return { valid: true, referer: null };
  }

  try {
    const refererUrl = new URL(referer);
    const isAllowed = allowedDomains.some(
      (domain) =>
        refererUrl.host === domain || refererUrl.host.endsWith(`.${domain}`)
    );
    return { valid: isAllowed, referer };
  } catch {
    return { valid: false, referer };
  }
}
```

---

## 9. Webhook Signature Verification

Type definitions for implementing service-specific signature verification:

```ts
export interface WebhookValidationResult {
  valid: boolean;
  error?: string;
}
```

### Webhook Signature Verification Implementation Example

```ts
// lib/external/webhook-verify.ts
export async function verifyWebhookSignature(
  headers: Headers,
  body: string,
  webhookSecret: string
): Promise<WebhookValidationResult> {
  // 1. Certificate URL validation (SSRF prevention) ※when the service uses certificate URLs
  const certUrl = headers.get("x-cert-url");
  if (certUrl && !isValidCertUrl(certUrl, allowedHosts)) {
    return { valid: false, error: "Invalid certificate URL" };
  }

  // 2. Timestamp validation
  const timestamp = headers.get("x-webhook-timestamp");
  if (timestamp) {
    const tsCheck = validateTimestamp(timestamp);
    if (!tsCheck.valid) return tsCheck;
  }

  // 3. Service-specific signature verification
  // ※Refer to project-specific guidelines
  // ...
}
```

**SSRF prevention**: When accessing URLs received via Webhook, always validate the domain.

---

## 10. Best Practices

### DO (Recommended)

```ts
// ✅ Use origin validation + CORS headers as a set
const originCheck = validateOrigin(req);
if (!originCheck.valid) {
  return new Response("Forbidden", { status: 403, headers: corsHeaders(req) });
}

// ✅ Restrict allowed methods per endpoint
corsHeaders(req, { allowedMethods: ["POST"] })

// ✅ Manage allowed origins via environment variables
// ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com

// ✅ Add timestamp validation for webhooks
const tsResult = validateTimestamp(req.headers.get("x-webhook-timestamp"));
```

### DON'T (Not Recommended)

```ts
// ❌ Return CORS headers without origin validation
return Response.json(data, { headers: corsHeaders(req) });

// ❌ Access webhook certificate URL without validation (SSRF)
const cert = await fetch(headers.get("cert-url")); // Dangerous
```

---

## 11. Summary

| Feature | Implementation | Purpose |
|------|---------|------|
| Origin validation | `validateOrigin()` | Only allow permitted origins |
| CORS header generation | `corsHeaders()` | Standards-compliant response headers |
| Preflight handling | `handleCorsPreflightRequest()` | Unified OPTIONS request processing |
| Timestamp validation | `validateTimestamp()` | Replay attack prevention |
| Referer validation | `validateReferer()` | CSRF countermeasure |
| Wildcard | `*.example.com` | Batch subdomain allowance |
