# Project Structure Guidelines

This document defines the directory layout and architecture guidelines for Node.js CLI tool projects.

---

## 1. Overall Principles

- Adopt **module-based (domain-based) structure**
  - Group types / services / utils per functional domain
- **Separate CLI layer from core logic**
  - `cli/` handles argument parsing and process control only
  - Core logic is importable as a library without CLI dependency
- **Barrel exports** via `src/index.ts` for library usage

---

## 2. Directory Structure

```text
src/
├─ cli/                      # CLI entry point (argument parsing, process control)
│  └─ index.ts               # #!/usr/bin/env node — Commander setup & subcommands
│
├─ pipeline/                 # Pipeline orchestration (multi-step processing)
│  └─ index.ts               # Orchestrator, step registration, state management
│
├─ {domain-a}/               # Domain module A (e.g., collector, scraper)
│  ├─ index.ts               # Public API for the module
│  ├─ {sub-module}.ts        # Internal implementation
│  └─ {sub-module}.test.ts   # Co-located unit tests
│
├─ {domain-b}/               # Domain module B (e.g., preprocessor, transformer)
│  ├─ index.ts
│  └─ *.test.ts
│
├─ {domain-c}/               # Domain module C (e.g., reporter, output generator)
│  ├─ index.ts
│  └─ *.test.ts
│
├─ extensions/               # Optional/pluggable modules
│  ├─ {extension-a}.ts
│  └─ {extension-b}.ts
│
├─ cache/                    # Caching system (TTL, hashing, invalidation)
│  └─ index.ts
│
├─ config/                   # Configuration resolution & defaults
│  └─ index.ts
│
├─ types/                    # Shared type definitions
│  └─ index.ts
│
├─ utils/                    # Shared utilities
│  ├─ errors.ts              # Error class hierarchy
│  ├─ logger.ts              # Module-scoped logger
│  ├─ validation.ts          # Runtime data validators
│  └─ file-io.ts             # File read/write helpers
│
└─ index.ts                  # Library barrel export (no CLI dependency)

tests/
├─ unit/                     # Additional unit tests
└─ e2e/                      # End-to-end CLI tests

docs/
├─ specs/                    # Design specifications & diagrams
└─ usages/                   # Usage documentation
```

---

## 3. Module Design

## 3.1 Internal Structure of a Module

Select subdirectories based on the scale of the module. Not all are required.

```text
{module}/
├─ index.ts                  # Public API (re-exports)
├─ {feature}.ts              # Feature implementation
├─ {feature}.test.ts         # Co-located test
├─ types.ts                  # Module-specific types (optional)
└─ constants.ts              # Module-specific constants (optional)
```

## 3.2 Structure Examples by Scale

**Small module** (config, cache):

```text
config/
└─ index.ts                  # Resolve + defaults in a single file
```

**Medium module** (preprocessor, reporter):

```text
reporter/
├─ index.ts                  # Entry: generateAllReports()
├─ base.ts                   # Shared reporter helper
├─ business.ts               # Business report generator
├─ competitor.ts             # Competitor report generator
└─ *.test.ts
```

**Large module** (collector with multiple strategies):

```text
collector/
├─ index.ts                  # Entry: collect()
├─ web.ts                    # Web scraping (Playwright)
├─ source.ts                 # Source code scanning
├─ auth.ts                   # Authentication handling
├─ types.ts                  # Collector-specific types
└─ *.test.ts
```

---

## 4. Dependency Rules

## 4.1 Allowed Dependencies

```text
cli/ → pipeline/ → {domain modules} → utils/, types/, config/
                 → cache/
                 → extensions/
```

## 4.2 Prohibited Practices

- **Cross-domain module dependencies are prohibited** — if two modules need shared logic, extract it to `utils/`
- **utils/ → domain module dependencies are prohibited**
- **Domain modules → cli/ dependencies are prohibited** — core logic must work without CLI
- **Circular dependencies are prohibited** — enforce with lint rules

---

## 5. CLI Layer Separation (Strict)

The `cli/` directory is **strictly limited** to:

- Argument parsing and validation (Commander setup)
- Configuration resolution
- Orchestrator invocation
- Process exit code management
- User-facing error formatting

Business logic, data processing, and I/O operations belong in domain modules.

```ts
// cli/index.ts — GOOD: thin wrapper
const config = resolveConfig(options);
const orchestrator = new PipelineOrchestrator(config);
const results = await orchestrator.run();
process.exit(results.some(r => !r.success) ? 1 : 0);
```

---

## 6. Library Export Pattern

`src/index.ts` exports the public API for programmatic usage:

```ts
// src/index.ts
export { PipelineOrchestrator, createDefaultSteps } from "./pipeline/index.js";
export { resolveConfig, DEFAULT_CONFIG } from "./config/index.js";
export type { AnalyzerConfig, PipelineStepResult } from "./types/index.js";
```

This allows the tool to be used as both a CLI and an importable library.

---

## 7. Test Organization

| Location | Purpose |
|----------|---------|
| `src/**/*.test.ts` | Co-located unit tests (module-level) |
| `tests/unit/` | Cross-module unit tests |
| `tests/e2e/` | End-to-end CLI invocation tests |

- Co-locate unit tests with source files for discoverability
- E2E tests invoke the actual CLI binary and verify stdout/stderr/exit codes
- Use test fixtures in `tests/fixtures/` for sample data

---

## 8. Guidelines Summary

- **Module-based structure is the default**
- **CLI layer is a thin wrapper — no business logic**
- **Core logic is importable as a library**
- **Co-locate tests with source files**
- **Domain modules must not depend on each other directly** — use shared utils or the pipeline orchestrator to coordinate
