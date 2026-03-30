# Security Guidelines

This document summarizes the **security and privacy strategy** for large-scale Next.js applications.
Cloud service used: **Vercel**

---

## Purpose of the Security Strategy

* Handle sensitive data securely
* Prevent authentication and authorization vulnerabilities
* Minimize attack vectors for APIs, databases, and external integrations
* Implement privacy measures in compliance with applicable laws (e.g., data protection regulations, GDPR)
* Prevent misconfigurations and secret leaks during operations

---

## 1. Fundamental Principles (Zero Trust Architecture)

* Default deny: grant only the necessary permissions
* Separate responsibilities across each layer: Client -> Server -> DB
* Minimize scope of sessions, cookies, and tokens
* Require validation (Zod) for all input data
* Never include secrets in code
* Use minimal scopes for external API integrations (payment services, AI APIs, etc.)

---

## 2. Client-Side Security

## CSRF Prevention

* SameSite=Lax or stricter
* Enforce HTTPS
* Perform **Origin / Referer checks** in API Routes
* Allow only POST/PUT/DELETE for state-changing APIs

## Clickjacking Prevention

HTTP Headers:

```text
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none';
```

---

## 3. API / Route Handler Security

## Authorization

* Introduce RBAC/ABAC (role-based or attribute-based access control)
* Perform authorization checks at the Route Handler layer
* **Require IDOR prevention**: When accessing resources (e.g., `GET /api/users/:id`), always verify that the requesting user is the owner of that resource
* Verify through unit tests and integration tests that horizontal and vertical privilege escalation does not occur in authorization logic

## Rate Limiting

* Apply IP-based rate limiting via Vercel Edge Middleware
* When using an API Gateway, apply WAF + Throttling
* For external APIs (payment services, AI APIs, etc.), leverage each service's built-in rate limiting

---

## 3.1 IDOR Prevention Pattern (Implementation Examples)

> **Reference:** See frameworks/nextjs/server-actions.md for details on the ActionResult pattern and requireOwnership()

## Basic Pattern: Ownership Verification Helper

```ts
// src/lib/actions/auth-helpers.ts

export async function requireProjectOwnership(
  projectId: string
): Promise<AuthResult & { project: Project }> {
  const authResult = await requireAuth();
  if (!authResult.success) return authResult;

  const project = await prisma.project.findUnique({
    where: { id: projectId },
  });

  if (!project) {
    return {
      success: false,
      error: ActionErrors.notFound("Project"),
    };
  }

  // IDOR prevention: verify ownership
  if (project.userId !== authResult.user.id) {
    logger.warn(
      { userId: authResult.user.id, projectId, ownerId: project.userId },
      "IDOR attempt detected: user tried to access another user's project"
    );
    return {
      success: false,
      error: ActionErrors.forbidden(),
    };
  }

  return { ...authResult, project };
}
```

## Usage Example in Server Actions

```ts
// ❌ BAD: No ownership verification
export async function updateProject(projectId: string, data: UpdateData) {
  await prisma.project.update({
    where: { id: projectId }, // Can update other users' projects
    data,
  });
}

// ✅ GOOD: With ownership verification
export async function updateProject(projectId: string, data: UpdateData) {
  const ownershipResult = await requireProjectOwnership(projectId);
  if (!ownershipResult.success) return ownershipResult.error;

  await prisma.project.update({
    where: { id: projectId },
    data,
  });
}
```

## Query Filter Pattern

```ts
// Query pattern to retrieve only the user's own resources
export async function getUserProjects(): Promise<ActionResult<Project[]>> {
  const authResult = await requireAuth();
  if (!authResult.success) return authResult.error;

  // ✅ Filter by userId in the WHERE clause
  const projects = await prisma.project.findMany({
    where: { userId: authResult.user.id },
  });

  return createActionSuccess(projects);
}
```

---

## 3.2 Rate Limiting

> **Reference:** See common/rate-limiting.md for complete implementation patterns

## Presets

| Preset | Limit | Use Case |
|--------|-------|----------|
| auth | 10/min | Login, password reset |
| generation | 30/hour | AI generation |
| api | 100/min | General API |
| strict | 5/min | Critical operations |

## Implementation Approach

* **Development / single instance**: Memory-based store
* **Production / multiple instances**: Redis (Upstash)
* **Standard headers**: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`

## MUST: Apply Rate Limiting to Auth Server Actions

MUST apply rate limiting to ALL Server Actions that handle authentication — not just API routes. Server Actions for `register`, `login`, `requestPasswordReset`, and `resetPassword` MUST check rate limits per IP before processing:

```ts
"use server";
export async function registerUser(formData: FormData): Promise<ActionResult> {
  // ✅ MUST: Rate limit before any auth processing
  const ip = (await headers()).get("x-forwarded-for") ?? "unknown";
  const { success } = await checkRateLimit(`auth:register:${ip}`, { maxRequests: 5, windowMs: 60_000 });
  if (!success) return { success: false, error: "Too many attempts. Try again later." };
  // ... rest of registration logic
}
```

---

## 3.3 Webhook Security

## Signature Verification Pattern

```ts
// Webhook signature verification (generic pattern)
export async function verifyWebhookSignature(
  req: Request
): Promise<{ valid: boolean; body?: WebhookEvent }> {
  const body = await req.text();
  const headers = Object.fromEntries(req.headers.entries());

  // Signature verification using each service's SDK
  // * Refer to project-specific guidelines for implementation details
  const isValid = await webhookService.verifySignature(
    headers,
    body,
    process.env.WEBHOOK_SECRET!
  );

  if (!isValid) {
    logger.warn({ headers }, "Invalid webhook signature");
    return { valid: false };
  }

  return { valid: true, body: JSON.parse(body) };
}
```

## Replay Attack Prevention

```ts
export async function processWebhook(eventId: string): Promise<boolean> {
  // Check if already processed
  const existing = await prisma.webhookEvent.findUnique({
    where: { externalId: eventId },
  });

  if (existing) {
    logger.info({ eventId }, "Webhook already processed, skipping");
    return false; // Ensure idempotency
  }

  // Record the start of processing
  await prisma.webhookEvent.create({
    data: {
      externalId: eventId,
      status: "processing",
    },
  });

  return true;
}
```

## Timestamp Validation

```ts
// Reject webhooks that are too old (replay attack prevention)
const WEBHOOK_MAX_AGE = 5 * 60 * 1000; // 5 minutes

function validateTimestamp(timestamp: string): boolean {
  const eventTime = new Date(timestamp).getTime();
  const now = Date.now();

  if (now - eventTime > WEBHOOK_MAX_AGE) {
    logger.warn({ timestamp, age: now - eventTime }, "Webhook too old");
    return false;
  }

  return true;
}
```

---

## 3.4 CSP Nonce Header

Generate a CSP nonce per request to control inline script execution.

```typescript
// middleware.ts
const nonce = Buffer.from(crypto.randomUUID()).toString("base64");
const csp = `script-src 'nonce-${nonce}' 'strict-dynamic'; ...`;
response.headers.set("Content-Security-Policy", csp);
response.headers.set("x-nonce", nonce);
```

* Prohibit the use of `'unsafe-inline'`
* Establish a trust chain with `'strict-dynamic'`
* Inline scripts such as next-themes require nonce propagation

---

## 3.5 Webhook Certificate URL SSRF Prevention

When using certificate URLs for webhook signature verification, prevent SSRF attacks.

```typescript
// src/lib/external/webhook-utils.ts
function isValidWebhookCertUrl(certUrl: string, allowedHosts: string[]): boolean {
  const url = new URL(certUrl);
  if (url.protocol !== "https:") return false;
  // allowedHosts example: ["api.example.com", "api.sandbox.example.com"]
  return allowedHosts.some(
    (host) => url.hostname === host || url.hostname.endsWith(`.${host}`)
  );
}
```

* Use a domain allowlist approach (safer than IP blocklists)
* Call at the beginning of `verifyWebhookSignature()`

---

## 3.6 Email Template HTML Injection Prevention

Always escape user-derived data when embedding it in HTML emails.

```typescript
// src/lib/email.ts
function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
```

* Trusted values such as translation results, plan names, UUIDs, and numbers do not need escaping
* Free-text fields such as admin-entered notes must always be escaped

---

## 3.7 Error Page Information Leakage Prevention

* Never display stack traces in `error.tsx` / `global-error.tsx`
* Only `error.digest` (a safe hash) may be displayed
* Exclude `error.message` / `error.stack` from API Route error responses

---

## 3.8 Session Management

* Maximum concurrent sessions: 5 (per user)
* Session list UI: display device, IP, and location information
* Bulk logout functionality
* TOTP 2FA: lock for 15 minutes after 5 failed attempts, send lock notification email

### Suspicious Login Detection and Notification

```typescript
// src/lib/security/suspicious-login-detector.ts
export async function detectSuspiciousLogin(params: {
  userId: string;
  currentCountry: string | null;
}): Promise<SuspiciousLoginResult>
// Returns: { isSuspicious, reasons, currentCountry, knownCountries }
```

* Compare the current country against successful login history from the past 30 days
* Return `isSuspicious: true` when a login is from a new country
* `LoginHistory` model has a `country` column (ISO 3166-1 alpha-2)
* Country information is obtained from `x-user-country` / `x-vercel-ip-country` / `cf-ipcountry` headers
* On detection, send email notification via `sendSuspiciousLoginEmail()` (including IP, country, browser, and OS information)
* **Asynchronous sending**: do not block the login flow
* **Fail-safe**: on error, assume "not suspicious" (do not block legitimate users)
* First login (no history) is not treated as suspicious

---

## 3.9 OSS License Policy

> **Reference:** Refer to project-specific legal and compliance guidelines

* **Prohibited**: AGPL, GPL-2.0, GPL-3.0 (SaaS source code disclosure obligation)
* **Permitted**: MIT, Apache-2.0, ISC, BSD variants, CC0, Unlicense, MPL-2.0
* Run `npx license-checker` when adding dependency packages

---

## 3.10 Admin Panel IP Restriction

```typescript
// src/lib/security/admin-ip-restriction.ts
export function isAdminIpAllowed(clientIp: string | null): boolean
```

* Set IP allowlist via the `ADMIN_ALLOWED_IPS` environment variable
* Multiple IPs can be specified with comma separation (e.g., `203.0.113.1,192.168.1.0/24`)
* **CIDR notation support**: subnet-level authorization (mask comparison via bitwise operations)
* **IPv6 normalization**: `::1` is converted to `127.0.0.1`
* If undefined, no restriction is applied (all IPs can access)
* Block access if IP cannot be determined
* Check in `src/middleware.ts` when accessing `/admin` paths

---

## 3.12 Path Traversal Prevention

When a tool or API endpoint accepts file paths as input (`source_path`, `output_path`, `file_name`, etc.), prevent access outside the allowed base directory:

```typescript
import path from "path";

/**
 * Resolve and validate that the given path stays within the allowed base directory.
 * Throws if a path traversal is detected.
 */
function validatePath(inputPath: string, allowedBase: string): string {
  const resolved = path.resolve(inputPath);
  const base = path.resolve(allowedBase);

  if (!resolved.startsWith(base + path.sep) && resolved !== base) {
    throw new Error(`Path traversal detected: ${inputPath}`);
  }
  return resolved;
}
```

```typescript
// ❌ BAD: directly using user-supplied path
const content = await fs.readFile(userSuppliedPath, "utf8");

// ✅ GOOD: validate before use
const safePath = validatePath(userSuppliedPath, process.env.DATA_DIR!);
const content = await fs.readFile(safePath, "utf8");
```

**Apply to:** any endpoint or CLI flag that receives a file path (`--output`, `source_path`, `import_file`, etc.). Even in local CLI tools, path traversal can expose unintended files when inputs come from external sources (MCP tool args, config files, user prompts).

---

## 3.11 Maintenance Mode

```typescript
// src/middleware.ts
if (
  process.env.MAINTENANCE_MODE === "true" &&
  pathname !== "/maintenance" &&
  !isAdminIpAllowed(clientIp)
) {
  return NextResponse.redirect(new URL("/maintenance", req.url));
}
```

* Enable with the environment variable `MAINTENANCE_MODE=true`
* Redirect all users to the `/maintenance` page
* **Admin IP bypass**: IPs listed in `ADMIN_ALLOWED_IPS` can access normally
* Maintenance page: `/app/maintenance/page.tsx`
* GCP downtime guide: `docs/setup/gcp/12_downtime-and-maintenance.md`

---

## 4. Database Security

## Prisma + DB Protection

* Use minimum privileges for DB users (consider introducing read-only users). "Minimum privileges" means:
  * Application DB user: only `SELECT`, `INSERT`, `UPDATE`, `DELETE` on application tables — no `CREATE`, `DROP`, `ALTER`, or `GRANT`
  * Read-only DB user (for analytics/reporting): only `SELECT`
  * Migration DB user (CI only): full DDL permissions, never used at runtime
* Store DB credentials in `.env` or cloud secret management

## Data Encryption

* Set appropriate **file access permissions** for the database (SQLite)
* Consider application-layer encryption for personal data (e.g., AES-256)
* **Encryption key management**: Manage keys in a dedicated secret management service rather than Vercel environment variables, retrieving them only at runtime
* **Key rotation**: Require periodic key rotation

---

## 5. Secrets / Environment Variable Management

## Vercel

* Project Settings -> Environment Variables
* Manage separately for Development / Preview / Production
* Never include in Git
* Recommended: introduce Protected Environments

## GitHub

* Manage with GitHub Actions Secrets
* Rule: do not pass production environment variables to PR environments

---

## 6. HTTPS / Communication Security

* **Vercel provides HTTPS automatically**
* Enforce wss:// when using WebSockets
* API calls must use HTTPS only
* Set the Secure attribute on cookies

---

## 7. External Service Integration Security

## Payment Services

* Protect webhooks with Vercel Serverless Functions
* Always verify webhook signatures (see Section 3.3)
* Strictly separate Client ID and Secret

## AI API / OAuth

* Minimize OAuth authorization scopes
* Use short-lived Access Tokens (encrypt Refresh Tokens for storage)

## RSS / Markdown

* Validate external RSS URLs with Zod
* Fetch on SSR and render with sanitization to prevent XSS
* Recommended: GitHub Flavored Markdown + `remark-gfm`

---

## 8. Session Management (NextAuth.js)

* Cookie-based sessions (Secure / HttpOnly / SameSite)
* Store encryption keys as Secrets even when using JWT mode
* Do not include sensitive data in session information
* Always enable OAuth Provider state parameter validation

---

## 9. Privacy Protection (Privacy by Design)

## Minimize Collected User Data

* Collect only data with a clear purpose and necessity
* Establish data retention period policies
* Recommend anonymization / pseudonymization

## Cookie & Tracking Management

* Implement Cookie Policy / Consent Banner
* Use anonymized analytics (Vercel Analytics)

## GDPR / Data Protection Law Compliance

* Support data deletion requests (Right to Erasure)
* Support user data export (Right to Access)
* Maintain a privacy policy

---

## 10. CI/CD Security

* Inject secrets securely in GitHub Actions
* All PRs must go through review and CI
* Detect vulnerabilities with Dependabot / npm audit / Snyk
* **Vulnerability response SLA**: Patch Critical (CVSS 9.0+) within 24 hours, High (CVSS 7.0+) within 7 days
* When patching is difficult, introduce mitigation measures at the WAF / API Gateway level
* Do not include sensitive data in containers or build artifacts

---

## 11. Security Audit / Automated Checks

* Static analysis with CodeQL (GitHub)
* Vulnerability checks with npm audit / Snyk
* Regularly review Vercel Security Insights

---

## 12. Security Monitoring and Response

* **Log collection**: Record authentication failures, authorization failures (IDOR, etc.), and Zod validation errors at ERROR/CRITICAL level in Sentry / CloudWatch
* **Alert operations**:

  * Abnormal login attempts (e.g., 100+ in 10 minutes)
  * API authorization failures (e.g., 50+ in 5 minutes)
    -> Immediately notify the responsible team
* **Operational rules**: Establish regular reviews and incident response procedures

---

---

## 13. AI / LLM Integration Security

As applications increasingly integrate LLM capabilities (AI APIs, MCP servers, agent workflows), new attack surfaces emerge that traditional web security does not cover. Reference: **[OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)** / **[OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/)**.

---

### 13.1 Indirect Prompt Injection (XPIA)

External content retrieved by the application (web pages, documents, API responses, database records) may contain hidden instructions that the LLM interprets as legitimate commands.

```typescript
// ❌ BAD: passing raw external content directly into a prompt
const pageContent = await fetchWebPage(url);
const prompt = `Summarize this page: ${pageContent}`;

// ✅ GOOD: sanitize external content before injecting into prompts
function sanitizeExternalContent(text: string, maxLength = 50_000): string {
  return text
    // Strip tags commonly used for instruction smuggling
    .replace(/<\/?(?:IMPORTANT|SYSTEM|INST|s|script)[^>]*>/gi, "")
    .replace(/<!--[\s\S]*?-->/g, "")
    // Strip zero-width and invisible unicode characters
    .replace(/[\u200B-\u200D\uFEFF\u00AD]/g, "")
    .slice(0, maxLength);
}

const safeContent = sanitizeExternalContent(await fetchWebPage(url));
const prompt = `Summarize this page: ${safeContent}`;
```

**Rule:** Treat all externally-sourced content as untrusted data — never as trusted instructions.

---

### 13.2 Tool / Plugin Poisoning

When an AI agent can invoke tools whose definitions (name, description, schema) are loaded from external or third-party sources, those definitions can be weaponized to exfiltrate data or perform unauthorized actions.

```typescript
// ✅ Verify tool definitions before registration
function verifyToolDefinition(tool: ToolDefinition, expectedHash: string): void {
  const actualHash = sha256(JSON.stringify(tool));
  if (actualHash !== expectedHash) {
    throw new Error(`Tool definition hash mismatch for "${tool.name}". Possible tampering.`);
  }
}
```

**Mitigations:**

* Pin external MCP server / plugin versions and verify via hash/checksum
* Validate that tool `description` fields do not contain instruction-like patterns (`"always"`, `"ignore previous"`, `"secretly"`, etc.)
* Never grant AI tools more permissions than required (principle of least privilege, Section 1)
* Log all tool invocations with parameters; alert on unexpected file access or external network calls

---

### 13.3 Secret Exposure via LLM

LLMs may inadvertently reproduce secrets present in their context (system prompts, tool responses, retrieved documents).

```typescript
// ✅ Redact secrets from all content before passing to LLM
const REDACT_PATTERNS = [
  /\b(sk-[A-Za-z0-9]{32,})/g,          // API keys
  /\b(Bearer\s+[A-Za-z0-9\-._~+/]+=*)/g, // Bearer tokens
  /([A-Za-z0-9+/]{40,}={0,2})/g,        // Base64-encoded secrets (heuristic)
];

function redactSecrets(text: string): string {
  return REDACT_PATTERNS.reduce(
    (t, pattern) => t.replace(pattern, "[REDACTED]"),
    text
  );
}
```

* Never include API keys, DB credentials, or PII in prompts, system messages, or tool response content
* Apply the same redact rules as server-side logging (Section 9 / common/logging.md PII Redaction)

---

### 13.4 Dependency Pinning for AI Packages

AI / MCP related packages (e.g., `@modelcontextprotocol/sdk`, `mcp-remote`, AI SDK wrappers) have a history of rapidly-introduced CVEs.

* Pin exact versions in `package.json` for all AI-related packages
* Run `npm audit` / Dependabot on every PR (same SLA as Section 10)
* For `mcp-remote` specifically: CVE-2025-6514 (RCE via unsanitized OAuth metadata) — upgrade to the patched version immediately if used

---

## Summary

* Authentication and authorization based on **Zero Trust principles**
* **Require input validation for all inputs** (Zod)
* Manage secrets securely with **Vercel / GitHub**
* Define explicit permission boundaries for API / DB / external API access; require IDOR prevention
* Manage encryption keys with a dedicated service and rotate them regularly
* Respond to CI/CD vulnerabilities promptly based on SLAs
* Ensure attack detection and response through logging, monitoring, and alerting
* Comply with privacy laws and minimize user data collection
* **Validate file paths** against an allowed base directory to prevent path traversal (Section 3.12)
* **Sanitize all external content** before injecting into LLM prompts; treat it as untrusted data (Section 13)
