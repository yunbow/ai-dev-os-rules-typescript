# Rate Limiting Guidelines

This document defines the implementation patterns for API and action rate limiting.

---

## 1. Core Policy

- **Serverless-compatible**: Use a memory-based store by default. Migrate to Redis when any of these conditions are met:
  * Running 2+ server instances (memory stores are per-instance, so limits are not shared)
  * Sustained traffic exceeds 100 requests/second (memory cleanup overhead becomes significant)
  * Rate limit accuracy is business-critical (e.g., billing-related quotas where approximate counts are unacceptable)
- **Preset configurations**: Provide default settings by use case
- **User identification**: Limit by IP address or user ID

---

## 2. Implementation Patterns

### 2.1 Memory-Based Store

```ts
// lib/api/rate-limit.ts

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

// Memory store (each instance is independent in serverless environments)
const store = new Map<string, RateLimitEntry>();

// Periodic cleanup (every 1 minute)
const CLEANUP_INTERVAL = 60 * 1000;
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of store.entries()) {
    if (entry.resetTime < now) {
      store.delete(key);
    }
  }
}, CLEANUP_INTERVAL);
```

### 2.2 Preset Configurations

```ts
export const RateLimitPresets = {
  /** Auth: 10 requests/minute (brute force prevention) */
  auth: { limit: 10, windowMs: 60 * 1000 },

  /** AI generation: 30 requests/hour */
  generation: { limit: 30, windowMs: 60 * 60 * 1000 },

  /** General API: 100 requests/minute */
  api: { limit: 100, windowMs: 60 * 1000 },

  /** Webhook: 50 requests/minute */
  webhook: { limit: 50, windowMs: 60 * 1000 },

  /** Strict: 5 requests/minute (password reset, etc.) */
  strict: { limit: 5, windowMs: 60 * 1000 },
} as const;

export type RateLimitPreset = keyof typeof RateLimitPresets;
```

### 2.3 Rate Limit Check

```ts
export interface RateLimitResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetTime: number;  // Unix timestamp (seconds)
  retryAfter?: number; // seconds
}

export function checkRateLimit(
  identifier: string,
  preset: RateLimitPreset | { limit: number; windowMs: number }
): RateLimitResult {
  const config = typeof preset === "string" ? RateLimitPresets[preset] : preset;
  const now = Date.now();
  const key = `${identifier}:${config.limit}:${config.windowMs}`;

  let entry = store.get(key);

  // Reset if no entry exists or window has elapsed
  if (!entry || entry.resetTime < now) {
    entry = {
      count: 0,
      resetTime: now + config.windowMs,
    };
    store.set(key, entry);
  }

  const allowed = entry.count < config.limit;
  if (allowed) {
    entry.count++;
  }

  return {
    allowed,
    limit: config.limit,
    remaining: Math.max(0, config.limit - entry.count),
    resetTime: Math.ceil(entry.resetTime / 1000),
    retryAfter: allowed ? undefined : Math.ceil((entry.resetTime - now) / 1000),
  };
}
```

---

## 3. Client IP Retrieval

### 3.1 Proxy Support

```ts
// lib/api/client-ip.ts

export function getClientIp(request: Request): string {
  const headers = request.headers;

  // Vercel
  const xForwardedFor = headers.get("x-forwarded-for");
  if (xForwardedFor) {
    return xForwardedFor.split(",")[0].trim();
  }

  // Cloudflare
  const cfConnectingIp = headers.get("cf-connecting-ip");
  if (cfConnectingIp) {
    return cfConnectingIp;
  }

  // AWS ALB / API Gateway
  const xRealIp = headers.get("x-real-ip");
  if (xRealIp) {
    return xRealIp;
  }

  // Fallback
  return "unknown";
}
```

### 3.2 Identifier Generation

```ts
/**
 * Generate an identifier for rate limiting.
 * Prioritize user ID if available, otherwise use IP address.
 */
export function getRateLimitIdentifier(
  request: Request,
  userId?: string
): string {
  if (userId) {
    return `user:${userId}`;
  }
  return `ip:${getClientIp(request)}`;
}
```

---

## 4. HTTP Headers

### 4.1 Setting Standard Headers

```ts
export function setRateLimitHeaders(
  headers: Headers,
  result: RateLimitResult
): void {
  headers.set("X-RateLimit-Limit", result.limit.toString());
  headers.set("X-RateLimit-Remaining", result.remaining.toString());
  headers.set("X-RateLimit-Reset", result.resetTime.toString());

  if (result.retryAfter) {
    headers.set("Retry-After", result.retryAfter.toString());
  }
}
```

### 4.2 Usage in Route Handlers

```ts
// app/api/generate/route.ts

import { checkRateLimit, getRateLimitIdentifier, setRateLimitHeaders } from "@/lib/api/rate-limit";
import { getClientIp } from "@/lib/api/client-ip";

export async function POST(request: Request) {
  const identifier = getRateLimitIdentifier(request);
  const rateLimitResult = checkRateLimit(identifier, "generation");

  if (!rateLimitResult.allowed) {
    const response = Response.json(
      {
        error: {
          code: "RATE_LIMIT_EXCEEDED",
          message: "Too many requests. Please try again later.",
          retryAfter: rateLimitResult.retryAfter,
        },
      },
      { status: 429 }
    );

    setRateLimitHeaders(response.headers, rateLimitResult);
    return response;
  }

  // Normal processing...
  const response = Response.json({ success: true });
  setRateLimitHeaders(response.headers, rateLimitResult);
  return response;
}
```

---

## 5. Usage in Server Actions

```ts
// features/generation/server/actions.ts

import { checkRateLimit, getRateLimitIdentifier } from "@/lib/api/rate-limit";
import { headers } from "next/headers";

export async function generateImage(
  input: GenerateInput
): Promise<ActionResult<GenerationResult>> {
  return withAction({ logger }, async ({ errors }) => {
    const authResult = await requireAuth();
    if (!authResult.success) return authResult.error;

    // Rate limit by user ID
    const rateLimitResult = checkRateLimit(
      `user:${authResult.user.id}`,
      "generation"
    );

    if (!rateLimitResult.allowed) {
      return {
        success: false,
        error: {
          code: "RATE_LIMIT_EXCEEDED",
          message: `Rate limit reached. Please retry after ${rateLimitResult.retryAfter} seconds.`,
        },
      };
    }

    // Generation processing...
  });
}
```

---

## 6. Protecting Authentication Endpoints

```ts
// app/api/auth/login/route.ts

export async function POST(request: Request) {
  const ip = getClientIp(request);

  // Rate limit login attempts
  const rateLimitResult = checkRateLimit(`login:${ip}`, "auth");

  if (!rateLimitResult.allowed) {
    logger.warn({ ip }, "Login rate limit exceeded");

    return Response.json(
      { error: { code: "TOO_MANY_ATTEMPTS", message: "Too many login attempts" } },
      { status: 429 }
    );
  }

  // Login processing...
}
```

---

## 7. Scaling: Migration to Redis

### 7.1 Migration Criteria

| Metric | Continue with memory store | Consider Redis |
|------|-----------------|-----------|
| Number of instances | 1 | 2+ |
| Requests/second | < 100 | > 100 |
| Accuracy requirements | Approximate is acceptable | Strict accuracy needed |

### 7.2 Redis Implementation Example (Upstash)

```ts
// lib/api/rate-limit-redis.ts

import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

// Create instances per preset
export const rateLimiters = {
  auth: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(10, "60 s"),
    analytics: true,
    prefix: "ratelimit:auth",
  }),

  generation: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(30, "1 h"),
    analytics: true,
    prefix: "ratelimit:generation",
  }),

  api: new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(100, "60 s"),
    analytics: true,
    prefix: "ratelimit:api",
  }),
};

export async function checkRateLimitRedis(
  identifier: string,
  preset: keyof typeof rateLimiters
): Promise<RateLimitResult> {
  const limiter = rateLimiters[preset];
  const { success, limit, remaining, reset } = await limiter.limit(identifier);

  return {
    allowed: success,
    limit,
    remaining,
    resetTime: Math.ceil(reset / 1000),
    retryAfter: success ? undefined : Math.ceil((reset - Date.now()) / 1000),
  };
}
```

### 7.3 Environment Variables

```env
# Upstash Redis (optional)
UPSTASH_REDIS_REST_URL=https://xxx.upstash.io
UPSTASH_REDIS_REST_TOKEN=xxx
```

---

## 8. Testing

```ts
describe("Rate Limiting", () => {
  beforeEach(() => {
    // Clear the store
    store.clear();
  });

  it("allows requests within the limit", () => {
    const result = checkRateLimit("test-user", { limit: 5, windowMs: 60000 });
    expect(result.allowed).toBe(true);
    expect(result.remaining).toBe(4);
  });

  it("rejects requests exceeding the limit", () => {
    for (let i = 0; i < 5; i++) {
      checkRateLimit("test-user", { limit: 5, windowMs: 60000 });
    }

    const result = checkRateLimit("test-user", { limit: 5, windowMs: 60000 });
    expect(result.allowed).toBe(false);
    expect(result.remaining).toBe(0);
    expect(result.retryAfter).toBeGreaterThan(0);
  });

  it("counts independently for different users", () => {
    for (let i = 0; i < 5; i++) {
      checkRateLimit("user-a", { limit: 5, windowMs: 60000 });
    }

    const result = checkRateLimit("user-b", { limit: 5, windowMs: 60000 });
    expect(result.allowed).toBe(true);
  });
});
```

---

## 9. Monitoring and Alerting

```ts
// Log rate limit exceeded events
if (!rateLimitResult.allowed) {
  logger.warn({
    identifier,
    preset,
    remaining: rateLimitResult.remaining,
    resetTime: rateLimitResult.resetTime,
  }, "Rate limit exceeded");
}

// Metrics (optional)
// Upstash Analytics or custom aggregation
```

---

## 10. Summary

| Pattern | Usage |
|---------|------|
| Memory store | Development environment, single instance |
| Redis (Upstash) | Production environment, multiple instances |
| Presets | Default settings by use case |
| HTTP headers | Information provision to clients |

| Preset | Limit | Use Case |
|-----------|------|-------------|
| auth | 10/min | Login, password reset |
| generation | 30/hour | AI generation |
| api | 100/min | General API |
| webhook | 50/min | Webhook reception |
| strict | 5/min | Critical operations |

## Before/After Example

```typescript
// ❌ Before: No rate limiting on sensitive endpoint
export async function POST(request: Request) {
  const body = await request.json();
  return Response.json(await resetPassword(body.email));
}
```

```typescript
// ✅ After: Rate limiting applied before processing
export async function POST(request: Request) {
  const ip = getClientIp(request);
  const result = checkRateLimit(`password-reset:${ip}`, "strict");
  if (!result.allowed) {
    return Response.json({ error: { code: "RATE_LIMIT_EXCEEDED" } }, { status: 429 });
  }
  const body = await request.json();
  return Response.json(await resetPassword(body.email));
}
```
