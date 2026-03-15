# Process Lifecycle Guidelines

This document defines how to manage exit codes, signal handling, stdin/stdout, and process cleanup for CLI tools.

---

# 1. Exit Codes

## 1.1 Standard Exit Codes

| Code | Meaning | When |
|------|---------|------|
| `0` | Success | All steps completed successfully |
| `1` | Partial failure | Some steps failed but process completed |
| `2` | Fatal error | Unrecoverable error (invalid input, unhandled exception) |

## 1.2 Implementation

```ts
// In CLI action handler
try {
  const results = await orchestrator.run();
  const hasFailure = results.some(r => !r.success);
  process.exit(hasFailure ? 1 : 0);
} catch (error) {
  if (error instanceof AppError) {
    console.error(`[${error.code}] Error: ${error.message}`);
  } else {
    console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
  }
  process.exit(2);
}
```

## 1.3 Rules
- **Always exit explicitly** — do not let the process hang
- **Use `process.exit()` only in the CLI layer** — core logic throws errors, CLI layer decides exit code
- **Never use `process.exit()` in library code** — it prevents proper cleanup and makes code untestable

---

# 2. Signal Handling

## 2.1 Graceful Shutdown

Handle termination signals to clean up resources:

```ts
const cleanup = async () => {
  logger.info("Shutting down...");
  await browser?.close();       // Close Playwright browser
  orchestrator.saveState();     // Persist pipeline state
  process.exit(130);            // 128 + SIGINT(2)
};

process.on("SIGINT", cleanup);   // Ctrl+C
process.on("SIGTERM", cleanup);  // kill command
```

## 2.2 Signal Exit Codes

| Signal | Exit Code | Meaning |
|--------|-----------|---------|
| SIGINT | 130 | User interrupted (Ctrl+C) |
| SIGTERM | 143 | Process terminated |

---

# 3. Error Hierarchy

## 3.1 Base Error Class

```ts
class AppError extends Error {
  readonly code: string;
  readonly severity: "fatal" | "warning" | "info";

  constructor(message: string, code: string, severity = "fatal") {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.severity = severity;
  }
}
```

## 3.2 Domain-Specific Errors

Create subclasses for each error domain:

```ts
class InputValidationError extends AppError {
  constructor(message: string) {
    super(message, "INPUT_VALIDATION", "fatal");
  }
}

class ConnectionError extends AppError {
  readonly url: string;
  constructor(url: string, cause?: string) {
    super(`Cannot connect to: ${url}${cause ? ` (${cause})` : ""}`, "CONNECTION_ERROR", "warning");
    this.url = url;
  }
}
```

## 3.3 Error Display

Format errors differently based on verbosity:

```ts
if (error instanceof AppError) {
  console.error(`[${error.code}] Error: ${error.message}`);
  if (verbose && error.stack) {
    console.error(error.stack);
  }
} else {
  console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
}
```

---

# 4. Standard I/O

## 4.1 Channel Separation

| Stream | Usage |
|--------|-------|
| `stdout` | Program output (results, data, reports) |
| `stderr` | Diagnostics (logs, progress, errors, warnings) |

This enables piping: `my-tool analyze > result.json 2> log.txt`

## 4.2 Logger Design

Module-scoped loggers write to `stderr`:

```ts
function createModuleLogger(moduleName: string, options: { level: LogLevel }): Logger {
  return {
    debug: (msg) => options.level === "DEBUG" && console.error(`[DEBUG][${moduleName}] ${msg}`),
    info:  (msg) => console.error(`[INFO][${moduleName}] ${msg}`),
    warn:  (msg) => console.error(`[WARN][${moduleName}] ${msg}`),
    error: (msg) => console.error(`[ERROR][${moduleName}] ${msg}`),
    progress: (current, total, msg) =>
      console.error(`[${current}/${total}] ${msg}`),
  };
}
```

---

# 5. Binary Entry Point

## 5.1 package.json Configuration

```json
{
  "type": "module",
  "bin": {
    "my-tool": "dist/cli/index.js"
  },
  "scripts": {
    "build": "tsc",
    "start": "tsx src/cli/index.ts",
    "dev": "tsx watch src/cli/index.ts"
  }
}
```

## 5.2 Shebang

The CLI entry point must include a shebang:

```ts
#!/usr/bin/env node
import { Command } from "commander";
// ...
```

## 5.3 tsconfig.json Essentials

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "dist",
    "declaration": true,
    "sourceMap": true,
    "strict": true
  }
}
```

---

# 6. Resource Cleanup

## 6.1 Cleanup Pattern

Use try/finally for resources that need cleanup:

```ts
const browser = await chromium.launch();
try {
  await collectData(browser, config);
} finally {
  await browser.close();
}
```

## 6.2 Cleanup Checklist

| Resource | Cleanup Action |
|----------|---------------|
| Browser instances (Playwright) | `browser.close()` |
| File handles | `handle.close()` |
| Temporary directories | `fs.rmSync(tmpDir, { recursive: true })` |
| Child processes | `child.kill()` |
| Pipeline state | `orchestrator.saveState()` |

---

# 7. Summary

- **Exit codes: 0 (success), 1 (partial failure), 2 (fatal)**
- **Handle SIGINT/SIGTERM** for graceful shutdown
- **`process.exit()` only in CLI layer** — never in library code
- **stdout for data, stderr for diagnostics**
- **Error hierarchy** with codes and severity levels
- **Always clean up resources** with try/finally
- **Module-scoped loggers** with configurable verbosity
