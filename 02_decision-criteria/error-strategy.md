$NOTE
# Error Strategy Decision Criteria

Defines error handling policies, retry decisions, and how to communicate errors to users.

---

## Fundamental Principle

**"Don't try to prevent all failures — detect, contain, and communicate them."**

---

## 1. Error Classification and Response Policies

| Error Type | Characteristics | Log Level | Display to User | Retry |
|----------|------|----------|-------------|---------|
| **System** | DB failure, uncaught exception, external API down | FATAL / ERROR | Generic error message | Automatic (backoff) |
| **Application** | Validation failure, domain rule violation, authentication error | WARN / ERROR | Specific error code + message | Don't retry |
| **User Operation** | Input format mistake, double click | — (no logging needed) | Prevent at UI level | Don't retry |

### Decision Flow

The boundary between System and Application errors: "Could the developer have predicted it?" means — is this error a known, enumerable case in the domain logic? If yes (e.g., "user not found", "insufficient balance"), it's an Application error that should be handled with a specific code path. If no (e.g., database connection dropped, OOM), it's a System error that gets generic handling.

```
Error Occurs
  │
  ├─ Is this a known, enumerable domain case?
  │    ├─ No → System Error (FATAL/ERROR, generic message, alert)
  │    └─ Yes ↓
  │
  ├─ Can the user fix it?
  │    ├─ Yes → User Operation Error (prevent in UI, no logging needed)
  │    └─ No → Application Error (specific message, WARN)
```

---

## 2. Retry Decisions

| Scenario | Auto-retry | Strategy |
|---------|------------|------|
| Network failure / offline → recovery | ✔ | Exponential backoff (1s → 2s → 4s) |
| Temporary 500 / 503 | ✔ | Exponential backoff, max N attempts |
| Validation error (400) | ✖ | Return fieldErrors to the user |
| Authentication error (401) | ✖ | Redirect to login screen |
| Authorization error (403) / Not Found (404) | ✖ | Display error, no retry needed |
| Conflict (409) | ✖ | Notify user of the conflict |
| Rate limit (429) | △ | Follow the Retry-After header |

### Retry Implementation Criteria

```
Should we retry?
  │
  ├─ Is the status code 5xx?
  │    ├─ Yes → Retry (max 3 times, exponential backoff)
  │    └─ No ↓
  │
  ├─ Is it a network error (timeout, etc.)?
  │    ├─ Yes → Retry (max 3 times, exponential backoff)
  │    └─ No → Don't retry (return result to the user)
```

**Why max 3 retries**: 3 attempts with exponential backoff (1s → 2s → 4s = 7s total) covers most transient failures (network blips, brief deployments) without making the user wait unreasonably. Beyond 3 retries, if the service is still failing, it's likely a sustained outage that retrying won't fix.

**Why exponential backoff starting at 1s**: Linear retry hammers a recovering service. Doubling the interval (1s → 2s → 4s) gives the failing service progressively more recovery time. Starting at 1s (not 100ms) avoids contributing to thundering herd problems while still being responsive for quick recoveries.

---

## 3. User-Facing Error Display Decisions

| Error Content | Display Method | Display Content |
|------------|---------|---------|
| Non-critical operation failure | Toast notification | Concise error message |
| Error affecting the entire page | Error Boundary | Fallback UI |
| Authentication expired | Redirect | To login screen |

### What Must NOT Be Displayed

- Stack traces
- DB query details
- Internal error codes (Prisma error codes, etc.)
- Environment variables / secrets

---

## 4. Non-Critical Feature Failure Decisions

| Feature Importance | Behavior on Failure |
|------------|--------------|
| Critical (authentication, payment) | Show error explicitly, abort processing |
| Important (data saving, generation) | Retry → display error on failure |
| Auxiliary (analytics, suggestions) | Fail silently, show fallback |
| Decorative (animations, non-essential UI) | Ignore, degrade gracefully |

**Principle**: Design so that auxiliary feature failures don't take down critical features.

---

## 5. External API Error Decisions

| External API Response | Action |
|---------------|------|
| Normal response (200) | Continue processing |
| Rate limit (429) | Wait according to Retry-After |
| Temporary failure (500, 503) | Retry with exponential backoff |
| Authentication error (401, 403) | Refresh key/token, alert |
| Timeout | Appropriate timeout value + retry |
| Specification change (unexpected response shape) | Detect with Contract Test, log + alert |

---

## 6. ActionResult Pattern Decisions

All Server Actions return results as a discriminated union:

```ts
type ActionResult<T> =
  | { success: true; data: T }
  | { success: false; error: ActionError }
```

### Why Express Errors as Types Instead of Exceptions

| Comparison | try-catch (exceptions) | ActionResult (types) |
|---------|-----------------|------------------|
| Forced handling | ✖ Can be forgotten | ✔ Enforced by the type system |
| Type-safe errors | ✖ catch is any | ✔ ActionError type |
| Field error representation | △ Custom implementation | ✔ Structured via fieldErrors |
| Component integration | △ Manual conversion | ✔ Directly consumed by Hooks |

### Server Action Checklist

```
✅ Use withAction() wrapper
✅ Authentication check with requireAuth()
✅ Resource ownership check with requireOwnership() (IDOR prevention)
✅ Input validation with Zod schema
✅ Error mapping with handleActionError()
✅ Return ActionResult<T>
```
