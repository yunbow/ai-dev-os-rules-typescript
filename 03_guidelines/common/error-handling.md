# Error Handling Guidelines

This document covers **only content that does not overlap with other documents**, focusing on error design, notification, user-facing experience, log levels, and error classification.

It also **systematizes error classification and handling methods**, defining what messages to display and how to log for each error type: validation errors, authentication errors, system errors, etc.

---

## 1. Error Taxonomy

### 1.1 System Errors (Server Internal)

* DB connection failures
* Uncaught exceptions
* Runtime exceptions
* External API outages

**Characteristics:**
Unpredictable / unrecoverable → Notify administrators + monitor
**Logging:** Record at FATAL level, do not include sensitive information

---

### 1.2 Application Errors (Expected Errors)

* Validation errors
* Domain logic errors (e.g., 409 Conflict)
* Authorization errors (insufficient permissions)
* Rate limit reached

**Characteristics:**
Predictable / handling required → Provide clear feedback to users
**Logging:** Record at ERROR or WARN level

---

### 1.3 User Operation Errors (User Mistakes)

* Missing input
* Unexpected operations (double clicks, etc.)
* **Input format errors preventable on the UI side** — specifically:
  * Errors caught by HTML input attributes (`type`, `min`, `max`, `maxLength`, `pattern`)
  * Errors caught by Zod schemas bound to React Hook Form via `zodResolver`
  * Errors prevented by UI controls (dropdowns instead of free text, date pickers instead of text input)
  * Criteria: if the UI can make the invalid state unrepresentable or provide instant feedback before submission, it qualifies

**Characteristics:**
Display messages and guide retry on the client side (UI)
※ Cases where the server returns error codes (e.g., 409 Conflict) are reclassified as 1.2

---

### 1.4 Error Propagation Flow

```text
┌──────────────────────────────────────────────────────────────────┐
│                        Error Source                               │
├──────────────────────────────────────────────────────────────────┤
│  External API  │   Prisma DB    │  Zod Validation │  Domain Logic │
│  (Integration) │   (Query)      │  (Input)        │  (Business    │
│                │                │                 │   Rules)      │
└─────┬──────────┴───────┬────────┴──────┬──────────┴──────┬───────┘
      │                  │               │                 │
      ▼                  ▼               ▼                 ▼
┌──────────────────────────────────────────────────────────────────┐
│              handleActionError() / classifyExternalError()        │
│              Error Classification & ActionError Conversion         │
│              → ※Project-specific integration guidelines,          │
│                frameworks/nextjs/server-actions.md                │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                      ActionResult Return                          │
│         { success: false, error: { code, message } }             │
│              → frameworks/nextjs/server-actions.md               │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                      UI Display Layer                             │
│   - toast.error() - Temporary notification                       │
│   - form.setError() - Field-level error                          │
│   - ErrorBoundary - Critical error                               │
│              → frameworks/nextjs/form.md, frameworks/nextjs/ui.md │
└──────────────────────────────────────────────────────────────────┘
```

**Related Documents:**

* External API error classification → ※Refer to project-specific integration guidelines
* ActionResult pattern → frameworks/nextjs/server-actions.md
* Form error display → frameworks/nextjs/form.md
* Toast/UI errors → frameworks/nextjs/ui.md
* Logging → common/logging.md

---

## 2. UI / UX Error Handling

### 2.1 Global Error Page (Layout Level)

* Unexpected exceptions → `app/error.tsx`
* Provide automatic recovery (reset)

### 2.2 Page-Level Error Display

* Provide fallback content
* Example: Feed fetch failure → Display retry button

### 2.3 Component-Level Fallback

* Combine Suspense + ErrorBoundary (client-side)
* Prevent small UI breakages from cascading to the entire page
* Forward client-side errors to server/external logging services
  * Typically treated as ERROR level
  * Forwarding methods: Fetch / Beacon API / dedicated SDK

---

## 3. API Error Policy (Next.js Route Handler)

### 3.1 Unified Response Format

```json
{
  "error": {
    "code": "INVALID_INPUT",
    "message": "The input is invalid."
  }
}
```

### 3.2 HTTP Status Code Rules

| Condition | Status | Example |
| --- | --- | --- |
| Success | 200, 201 | Create, update succeeded |
| User operation error | 400 | Validation failed |
| Authentication | 401 | Login required |
| Authorization | 403 | Insufficient permissions |
| Resource not found | 404 | Data does not exist |
| Conflict | 409 | Duplicate registration / domain logic violation |
| Temporary load / external service outage | 503 | Client should retry |
| Server | 500 | Internal error |

### 3.3 Indicate Retry Eligibility

* Specify via response headers or JSON fields

---

## 4. Log Levels and Recording Criteria (Non-overlapping with Observability)

### 4.1 Log Levels

| Level | Usage |
| --- | --- |
| DEBUG | Debugging only (minimize in production) |
| INFO | Normal operations (startup, completion, etc.) |
| WARN | Expected exceptions, retryable issues |
| ERROR | Application errors |
| FATAL | System-stopping events (notification target) |

### 4.2 Do Not Include Sensitive Information in Logs

* Passwords / tokens / raw email addresses

---

## 5. Tracing ID on Error Occurrence

> **Reference:** See common/logging.md for Trace ID implementation details

### 5.1 Assign `requestId` per Request

* Facilitates user support inquiries
* Example:

```yaml
x-request-id: abc123
```

### 5.2 Return requestId to the UI

* "Please provide this ID when contacting support"
* Enables easy cross-referencing with logs
* Reference: Can be used alongside traceparent or x-b3-traceid used by OpenTelemetry
  → Reason for adopting x-request-id: simple and easy to trace across microservices

---

## 6. User-Facing Message Strategy

### 6.1 Error Message Attributes

Each user-facing error message should address three dimensions:

* **Specificity** — State what failed in user terms, not technical terms. Bad: "Validation error". Good: "The email address format is invalid."
* **Action suggestion** — Tell the user what to do next. Include a concrete action: "Please check the email format and try again" or "Please try again in a few minutes."
* **Impact scope** — Clarify what was affected. "Your changes were not saved" or "The image was uploaded but processing failed — it will appear once processing completes."

---

## 7. Retry Strategy

### 7.1 Cases for Automatic Retry

* Network failures (offline → recovery)
* Temporary 500 / 503

### 7.2 Cases Where Retry Must Not Occur

* Validation errors
* 403 / 404
* Conflicts (409)

---

## 8. Handling Business Logic Errors (Domain Exceptions)

### 8.1 Handle Domain Rule Violations with Exception Classes

```ts
class DomainError extends Error {
  constructor(public code: string, message: string) {
    super(message);
  }
}
```

### 8.2 Convert Domain Errors to HTTP in the API

* `DomainError` → 400 or 409
* Handle as a separate layer from PrismaError

---

## 9. Error Visualization (UI)

### 9.1 Lightweight Error Display via Toast

* Communicate in a brief message, not lengthy text

### 9.2 Display Form Errors Per Field

* Presented from a UX perspective

---

## 10. Fail-Safe / Graceful Degradation

### 10.1 Non-Essential Feature Failures Should Maintain UI

* Page should still render even if sidebar notifications are down
* Alternative UI (skeleton / placeholder)

### 10.2 Cache Fallback on API Failure

* Local cache
* Use the most recent successful response

---

## 11. Debug / Developer-Facing Errors During Development

### 11.1 Dev Mode Displays Detailed Errors

* Suppressed in production

### 11.2 Error Testing in Storybook / Isolated Mode

* Enables testing error scenarios at the component level

---

## 12. QA / Testing (Non-overlapping Perspectives)

### 12.1 Error Scenario Tests Should Comprise 30-50%

* Success cases alone are insufficient

### 12.2 Chaos Testing (Limited Scope)

* Simulate API failures / latency

## 13. MUST: Error and Not-Found Boundaries (Next.js)

MUST place `error.tsx` in each route group and `not-found.tsx` at the app root:

```text
app/
├── error.tsx           ← MUST: root fallback
├── not-found.tsx       ← MUST: custom 404
├── global-error.tsx    ← MUST: catches root layout errors
├── (auth)/
│   └── error.tsx       ← MUST: auth errors
└── (protected)/
    ├── error.tsx       ← MUST: protected area fallback
    ├── tasks/error.tsx ← SHOULD: task-specific
    └── teams/error.tsx ← SHOULD: team-specific
```

## Before/After Example

```typescript
// ❌ Before: Leaking internal error details to the user
catch (error) {
  return Response.json(
    { error: { message: error.stack } },
    { status: 500 }
  );
}
```

```typescript
// ✅ After: Returning a safe user-facing message with a request ID
catch (error) {
  logger.error({ error, requestId }, "Unhandled error");
  return Response.json(
    { error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred", requestId } },
    { status: 500 }
  );
}
```
