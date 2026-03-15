# Logging Guidelines

This document outlines the **monitoring / logging / tracing (observability) strategy** for large-scale Next.js applications. Cloud service: **Vercel**

---

## Purpose of Observability

Observability in this project means the ability to answer "why is this request slow/failing?" within 5 minutes using logs, traces, and metrics. Specifically:

* Early detection and automated alerting for incidents
* Identify performance degradation trends
* Rapidly pinpoint the source of API, DB, and external API issues
* Safely visualize production environment behavior
* Monitor user impact in real-time

Build a system capable of observing performance issues that arise in
Next.js (Server Components / Edge Functions / Route Handlers).

---

## 1. Monitoring
### Vercel Monitoring
**The monitoring platform with the highest integration with Next.js.**
* **Vercel Analytics**
  * Web Vitals measurement (TTFB / FCP / LCP / CLS / FID)
  * Real user measurements from user devices (RUM)
  * Per-page performance visualization
* **Speed Insights**
  * Lighthouse-based measurements
  * Auto-suggests improvements (image optimization, script minification, webfont optimization)
* **Edge / Serverless Function Logs & Metrics**
  * Error rates
  * Processing time
  * Cold start detection

**Monitoring targets:**
* Route Handlers (API)
* Edge Middleware
* ISR regeneration (revalidate) timing
* **Server Components (RSC)** execution time and data fetch latency monitoring (often overlooked, requires attention)

---

## 2. Logging

### Next.js: Server Log Standards

```ts
console.info("[route] creating user", { email });
console.warn("[route] slow response", { ms });
console.error("[route] external api error", { provider, message });
```

**Classification:**

* info: Normal flow (metrics support)
* warn: Latency, retries, slow external API responses
* error: Handled failures

### Recommended Log Management Tools

| Purpose | Tool |
| --- | --- |
| Error monitoring | Sentry |
| Request logs / JSON structured logs | Logtail / DataDog |

---

## 3. Tracing

### Purpose of Distributed Tracing

* Identify the source of latency from API → DB → external API
* Track by specific user request
* Flexible alert configuration

### Trace ID / Request ID Propagation Strategy

Trace ID propagation is what enables correlating a user-visible error with the exact server-side log entry, DB query, and external API call that caused it. Without it, debugging production issues requires manually searching logs by timestamp — which is slow and error-prone at scale.

* Attach Trace IDs to all API / Server Components / Edge Functions / Prisma / external API calls
* Insufficient propagation makes it difficult to correlate logs and traces, hindering rapid problem identification

### 3.1 Trace ID Generation and Propagation (Implementation Examples)

#### Logger Factory

```ts
// src/lib/logger.ts
import pino from "pino";

const baseLogger = pino({
  level: process.env.LOG_LEVEL || "info",
  formatters: {
    level: (label) => ({ level: label }),
  },
});

// Logger for Server Actions
export function createActionLogger(actionName: string) {
  return baseLogger.child({
    service: "server-action",
    action: actionName,
  });
}

// Logger for API Routes
export function createApiLogger(routeName: string) {
  return baseLogger.child({
    service: "api-route",
    route: routeName,
  });
}

// Logger with request context
export function createRequestLogger(
  base: pino.Logger,
  requestId: string,
  userId?: string
) {
  return base.child({
    requestId,
    userId,
  });
}
```

#### Request ID Middleware

```ts
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { nanoid } from "nanoid";

export function middleware(request: NextRequest) {
  const requestId = request.headers.get("x-request-id") || nanoid();

  // Also attach to response headers
  const response = NextResponse.next();
  response.headers.set("x-request-id", requestId);

  return response;
}
```

#### Log Usage in Server Actions

```ts
// src/features/project/server/project-actions.ts

const logger = createActionLogger("project-actions");

export async function createProject(
  title?: string
): Promise<ActionResult<{ projectId: string }>> {
  const requestId = headers().get("x-request-id") ?? nanoid();
  const reqLogger = createRequestLogger(logger, requestId);

  reqLogger.info({ title }, "Creating project");

  try {
    const authResult = await requireAuth();
    if (!authResult.success) {
      reqLogger.warn("Authentication failed");
      return authResult.error;
    }

    const project = await prisma.project.create({
      data: { userId: authResult.user.id, title },
    });

    reqLogger.info({ projectId: project.id }, "Project created successfully");

    return createActionSuccess({ projectId: project.id });
  } catch (error) {
    reqLogger.error({ error }, "Failed to create project");
    throw error;
  }
}
```

#### Logging External API Calls

```ts
// src/lib/api/external-api-client.ts

export async function callExternalApi<T>(
  url: string,
  options: RequestInit,
  context: { requestId: string; logger: pino.Logger }
): Promise<T> {
  const { requestId, logger } = context;
  const startTime = performance.now();

  logger.info({ url, requestId }, "External API call started");

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        ...options.headers,
        "x-request-id": requestId, // Propagate to external API
      },
    });

    const durationMs = performance.now() - startTime;

    if (!response.ok) {
      logger.error(
        { url, status: response.status, durationMs, requestId },
        "External API call failed"
      );
      throw new ExternalApiError(response.status);
    }

    logger.info(
      { url, status: response.status, durationMs, requestId },
      "External API call completed"
    );

    return response.json();
  } catch (error) {
    const durationMs = performance.now() - startTime;
    logger.error(
      { url, error, durationMs, requestId },
      "External API call error"
    );
    throw error;
  }
}
```

### 3.2 Structured Log Format Standard

#### Recommended Fields

| Field | Description | Example |
|-----------|------|-----|
| `userId` | User ID | "user_xyz" |
| `action` | Action name | "createProject" |
| `durationMs` | Processing time | 150 |
| `error` | Error information | { code, message, stack } |

#### Log Output Examples

```json
{
  "level": "info",
  "service": "server-action",
  "action": "createProject",
  "requestId": "req_abc123",
  "userId": "user_xyz",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "message": "Project created successfully",
  "projectId": "proj_456",
  "durationMs": 150
}
```

```json
{
  "level": "error",
  "service": "api-route",
  "route": "/api/resource",
  "requestId": "req_def456",
  "userId": "user_xyz",
  "timestamp": "2024-01-15T10:31:00.000Z",
  "message": "External API call failed",
  "error": {
    "code": "RATE_LIMITED",
    "message": "API rate limit exceeded",
    "retryAfter": 60
  }
}
```

### 3.3 External API Call Logs

Record calls to external services such as AI APIs and payment APIs in a dedicated log format.

```ts
// lib/api/external-api-logger.ts

export interface ExternalApiLogParams {
  provider: string; // e.g., "ai-api", "payment", "vision"
  operation: string;
  latencyMs: number;
  status: "success" | "error";
  // API-specific metrics
  promptTokens?: number;
  responseTokens?: number;
  model?: string;
  errorCode?: string;
}

export function logExternalApiCall(
  logger: pino.Logger,
  params: ExternalApiLogParams,
  context?: { requestId?: string; userId?: string }
): void {
  const logData = {
    ...params,
    ...context,
    type: "external_api_call",
  };

  if (params.status === "success") {
    logger.info(logData, `${params.provider}:${params.operation} completed`);
  } else {
    logger.error(logData, `${params.provider}:${params.operation} failed`);
  }
}
```

#### Usage Example

```ts
const startTime = Date.now();

try {
  const result = await aiClient.generateText(prompt);

  logExternalApiCall(logger, {
    provider: "ai-api",
    operation: "generateText",
    latencyMs: Date.now() - startTime,
    status: "success",
    model: "model-name",
    promptTokens: result.usageMetadata?.promptTokenCount,
    responseTokens: result.usageMetadata?.candidatesTokenCount,
  }, { requestId, userId });

  return result;
} catch (error) {
  logExternalApiCall(logger, {
    provider: "ai-api",
    operation: "generateText",
    latencyMs: Date.now() - startTime,
    status: "error",
    errorCode: error.code,
  }, { requestId, userId });

  throw error;
}
```

### 3.4 Fire-and-Forget Log Pattern

For cases where you want to avoid blocking API calls, record logs asynchronously.

```ts
// lib/api/api-call-file-logger.ts

/**
 * Fire-and-Forget log recording
 * Does not block API responses
 */
export function logApiCallAsync(
  params: ApiCallLogParams,
  context: ApiCallContext
): void {
  // Return immediately, process in background
  setImmediate(async () => {
    try {
      await writeLogToFile(params, context);
    } catch (error) {
      // Don't swallow log write failures, only console.error
      console.error("Failed to write API call log:", error);
    }
  });
}

// Usage example
const response = await generateText(prompt);

// Non-blocking log recording
logApiCallAsync({
  prompt,
  response: response.text,
  tokens: response.usageMetadata,
}, { requestId, userId });

return response;  // Return without waiting for log completion
```

#### JSONL File Logging (For Development)

```ts
// Detailed logging for development environment debugging
const LOG_DIR = path.join(process.cwd(), "logs", "api-calls");

interface ApiCallLog {
  timestamp: string;
  requestId: string;
  provider: string;
  operation: string;
  prompt: string;
  response: string;
  latencyMs: number;
  tokens?: { input: number; output: number };
}

async function writeLogToFile(log: ApiCallLog): Promise<void> {
  if (process.env.NODE_ENV !== "development") return;

  const filename = `${new Date().toISOString().slice(0, 10)}.jsonl`;
  const filepath = path.join(LOG_DIR, filename);

  await fs.mkdir(LOG_DIR, { recursive: true });
  await fs.appendFile(filepath, JSON.stringify(log) + "\n");
}
```

### 3.5 Performance Measurement Pattern

```ts
// Performance measurement utility
export async function withPerformanceLog<T>(
  logger: pino.Logger,
  operation: string,
  fn: () => Promise<T>
): Promise<T> {
  const startTime = performance.now();

  try {
    const result = await fn();
    const durationMs = performance.now() - startTime;

    logger.info({ operation, durationMs }, `${operation} completed`);

    // Warn when threshold is exceeded
    if (durationMs > 1000) {
      logger.warn(
        { operation, durationMs },
        `${operation} exceeded 1s threshold`
      );
    }

    return result;
  } catch (error) {
    const durationMs = performance.now() - startTime;
    logger.error({ operation, durationMs, error }, `${operation} failed`);
    throw error;
  }
}

// Usage example
const project = await withPerformanceLog(
  reqLogger,
  "createProject",
  () => prisma.project.create({ data })
);
```

### Next.js × OpenTelemetry (OTEL)

**Tracing targets:**

* Route Handlers / Server Actions / Edge Functions
* DB access (Prisma middlewares)
* Payment API / AI API / RSS / External APIs
* **Server Components execution time and data fetch latency** — measure at the page-level RSC boundary (each `page.tsx` or layout data fetch), not individual components. Use `withPerformanceLog()` wrapping the top-level data fetch calls in each Server Component page.

**Tracing architecture example:**

```
User Request
  → Next.js Route Handler
    → Server Component (RSC)
    → Prisma (DB)
    → External API (Payment / AI, etc.)
    → Export to Sentry / DataDog
```

**Export destinations:**

| Purpose | Recommended Service |
| --- | --- |
| Frontend & Server unified tracing | Sentry |
| Server-centric distributed tracing | DataDog |

---

## 4. Alert Configuration
### Vercel

* Edge / Serverless error rate increase
* Response time threshold exceeded
* Build failure
* ISR regeneration error loops

### Sentry

* Exception occurrence
* Performance anomalies (Transactions)
* Version regression detection

---

## 5. SLO/SLA Definition and Metrics Mapping

* **Clarify what constitutes normal operation**
* Clarify the basis for incident detection and alerting
* Example: Define API latency 95th percentile < 300ms as SLO, error rate < 1% as SLA

---

## 6. Cost Optimization Strategy

* Log volume and trace volume for Logtail / Sentry / DataDog can lead to cost escalation
* **Mitigations:**

  * Sampling configuration (e.g., trace 10% of requests)
  * Clear log retention periods
  * Suppress unnecessary detailed logs

---

## 7. Observability Standardization Guidelines

### Logging

* JSON structured logs
* requestId / traceId required
* Error logs include stacktrace

### Tracing

* Attach Trace ID to all APIs
* Track DB queries via Prisma middleware
* External APIs (payment services / AI APIs, etc.) also generate spans
* Add Server Component measurements at page-level RSC boundaries — wrap top-level data fetch calls in `page.tsx` with `withPerformanceLog()` to capture RSC rendering + data fetch latency per page

### Monitoring

* Continuous Web Vitals measurement
* Enable RUM in staging environments as well
* Preserve performance comparisons for each deployment

---

## 8. Client-Side Logging

### Client Logger

```ts
// lib/client-logger.ts

type LogContext = Record<string, unknown>;

/**
 * Log warnings on the client side
 */
export function logClientWarn(message: string, context?: LogContext): void {
  if (process.env.NODE_ENV === "development") {
    console.warn(`[Client Warn] ${message}`, context);
  }
}
```

### Usage Examples

```tsx
// Error logging within components
import { logClientError, logClientWarn } from "@/lib/client-logger";

function ImageUploader() {
  const handleUpload = async (file: File) => {
    try {
      await uploadImage(file);
    } catch (error) {
      logClientError("Image upload failed", error, {
        fileName: file.name,
        fileSize: file.size,
      });
      toast.error("Upload failed");
    }
  };
}

// Logging within custom hooks
function useJobPolling() {
  const pollJobs = async () => {
    try {
      const result = await getJobStatus(jobId);
      // ...
    } catch (error) {
      logClientError("Failed to check job status", error);
    }
  };
}
```

### Sentry Integration (Future)

```ts
// lib/client-logger.ts (Sentry integration version)

import * as Sentry from "@sentry/nextjs";

export function logClientError(message: string, error?: unknown, context?: LogContext): void {
  if (process.env.NODE_ENV === "development") {
    console.error(`[Client Error] ${message}`, { error, ...context });
    return;
  }

  // Production: Send to Sentry
  if (error instanceof Error) {
    Sentry.captureException(error, {
      extra: { message, ...context },
    });
  } else {
    Sentry.captureMessage(message, {
      level: "error",
      extra: { error, ...context },
    });
  }
}
```

### Client/Server Log Usage Guidelines

| Situation | Logger to Use |
|------|---------------|
| Within Server Actions | `createActionLogger()` + `createRequestLogger()` |
| Within API Routes | `createApiLogger()` + `createRequestLogger()` |
| Client Components | `logClientError()` / `logClientWarn()` |
| Custom Hooks | `logClientError()` |
| React Error Boundary | `logClientError()` + Sentry |

---

## 9. PII Redaction (Pino redact Rules)

Use Pino logger for server-side logs and automatically redact sensitive information.

```typescript
// src/lib/logger.ts
const baseLogger = pino({
  redact: {
    paths: [
      "password", "*.password",
      "secret", "*.secret",
      "token", "*.token",
      "accessToken", "*.accessToken",
      "refreshToken", "*.refreshToken",
      "creditCard", "*.creditCard",
      "authorization", "*.authorization",
    ],
    censor: "[REDACTED]",
  },
});
```

**Rules:**
- Use `logger.error` instead of `console.error`
- `console.log(process.env.XXX)` is prohibited
- Error object stack traces are server logs only (never return to client)

---

## 10. Log Retention Policy

| Log Type | Retention Period | Storage |
|---------|---------|--------|
| Application logs | 30 days | Vercel Logs |
| API call logs (DB) | 90 days | `api_call_logs` table (auto-deleted via cron) |
| Audit logs | 1 year | `audit_logs` table |
| Security logs (auth failures, etc.) | 90 days | Vercel Logs + DB |
| Webhook event logs | 90 days | `webhook_events` table |

---

## 11. Cron Job Failure Alerts

Send email alerts on cron job failures.

```typescript
// src/lib/email.ts
export async function sendCronFailureAlert(
  cronName: string,
  error: unknown
): Promise<void> {
  // Send failure notification to admin email
}
```

**Usage pattern:**

```typescript
// /api/cron/xxx/route.ts
try {
  // ... cron processing ...
} catch (error) {
  await sendCronFailureAlert("cleanup", error);
  return NextResponse.json({ error: "Failed" }, { status: 500 });
}
```

All cron routes (cleanup, daily-report, process-jobs, etc.) should uniformly send alerts in the catch block.

---

## Summary

* **Vercel**: Next.js observability (Web Vitals, Serverless Logs, Preview)
* **Sentry / OTEL**: Error & tracing foundation
* **Logs are unified in JSON format**
* **Trace from API → Server Components → DB → External API** to pinpoint issues
* Trace ID / Request ID propagation and Server Component observation are the keys to observability
* SLO/SLA-based alert configuration and cost optimization should also be considered
* **Client-side**: Unify with `logClientError()` and prepare for Sentry integration

## Before/After Example

```typescript
// ❌ Before: Unstructured logging without request context
console.log("User created");
console.error("DB failed", error);
```

```typescript
// ✅ After: Structured JSON logging with request ID and context
const reqLogger = createRequestLogger(logger, requestId, userId);
reqLogger.info({ email }, "User created");
reqLogger.error({ error, durationMs }, "DB query failed");
```
