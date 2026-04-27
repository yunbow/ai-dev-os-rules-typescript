# AI Dev OS Rules — TypeScript

[![Lint & Link Check](https://github.com/yunbow/ai-dev-os-rules-typescript/actions/workflows/lint.yml/badge.svg)](https://github.com/yunbow/ai-dev-os-rules-typescript/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

> 4-layer guidelines for TypeScript projects (Next.js, Node.js CLI, etc.).
> Add as a git submodule, referenced by AI coding assistants via CLAUDE.md.

**Part of the [AI Dev OS](https://github.com/yunbow/ai-dev-os) ecosystem.**

## Why These Rules?

AI Dev OS Rules give your AI coding assistant **concrete, verifiable standards** instead of vague instructions:

- **14 common rules** — Naming, error handling, security, testing, logging, i18n, comment format, and more
- **Framework-specific rules** — Next.js App Router patterns, Server Actions, API design
- **Conflict resolution built-in** — Specificity Cascade resolves rule priority automatically
- **Versioned & auditable** — Pin to a tag, diff changes, review in PRs

## Quick Start

```bash
npx ai-dev-os init --rules typescript --plugin claude-code
```

> Sets up everything automatically. See [AI Dev OS CLI](https://github.com/yunbow/ai-dev-os-cli).

<details>
<summary>Manual setup</summary>

### Add as submodule

```bash
cd /path/to/your-project
git submodule add https://github.com/yunbow/ai-dev-os-rules-typescript.git docs/ai-dev-os
git submodule update --init
```

### Set up using templates (for Next.js)

```bash
bash docs/ai-dev-os/templates/nextjs/submodule-setup.sh
```

### Edit CLAUDE.md

Copy `templates/nextjs/CLAUDE.md.template` to `./CLAUDE.md` and fill in your project name and project-specific guidelines.

### Update submodule

```bash
git submodule update --remote docs/ai-dev-os
```

</details>

## What's Included

| Layer | Path | Contents |
|-------|------|----------|
| L1 — Philosophy | `01_philosophy/` | Principles, mental models, anti-patterns |
| L2 — Decision Criteria | `02_decision-criteria/` | Abstraction, tech selection, architecture, errors, security |
| L3 — Common Guidelines | `03_guidelines/common/` | 14 rules: code, naming, validation, errors, logging, security, testing, comment format, etc. |
| L3 — Framework Guidelines | `03_guidelines/frameworks/` | [Next.js](03_guidelines/frameworks/nextjs/README.md), [Node.js CLI](03_guidelines/frameworks/nodejs-cli/README.md) |
| Templates | `templates/` | [Next.js scaffolding](templates/nextjs/README.md) |

## Specificity Cascade

When rules conflict, **lower number wins**.

| Priority | Layer | Example |
|----------|-------|---------|
| 1 (Highest) | Framework-specific guidelines | `03_guidelines/frameworks/nextjs/*` |
| 2 | Common guidelines | `03_guidelines/common/*` |
| 3 | Decision criteria | `02_decision-criteria/*` |
| 4 | Design philosophy | `01_philosophy/*` |

<details>
<summary>Directory Structure</summary>

```text
ai-dev-os/
├── docs/
│   ├── operation-guide.md        # Operation & Contribution Guide
│   └── i18n/                     # Multilingual Guides
│       ├── ja/                   #   Japanese
│       ├── zh-CN/                #   Simplified Chinese
│       ├── ko/                   #   Korean
│       └── es/                   #   Spanish
│
├── 01_philosophy/                # Design Philosophy [Sample - rewrite in your native language]
│   ├── principles.md             #   Three Pillars: Correctness, Observability, Pragmatism
│   ├── mental-models.md          #   10 Thinking Frameworks
│   └── anti-patterns.md          #   Patterns to Avoid (with code examples)
│
├── 02_decision-criteria/         # Decision Criteria [Sample - rewrite in your native language]
│   ├── abstraction.md            #   Timing and Thresholds for Abstraction
│   ├── technology-selection.md   #   Technology Selection Framework
│   ├── architecture.md           #   Rendering, API, State Management, Component Placement
│   ├── error-strategy.md         #   Error Classification, Retry, ActionResult Pattern
│   └── security-vs-ux.md        #   Security Measure Priority and Balance
│
├── 03_guidelines/                # Guidelines [EN]
│   ├── common/                   #   Common (Language/FW Independent)
│   │   ├── code.md               #     Coding Standards
│   │   ├── comment-format.md     #     Comment Format (JSDoc English / line comments native)
│   │   ├── naming.md             #     Naming Conventions
│   │   ├── validation.md         #     Validation
│   │   ├── error-handling.md     #     Error Handling
│   │   ├── logging.md            #     Logging
│   │   ├── security.md           #     Security
│   │   ├── rate-limiting.md      #     Rate Limiting
│   │   ├── testing.md            #     Testing
│   │   ├── performance.md        #     Performance
│   │   ├── cors.md               #     CORS
│   │   ├── env.md                #     Environment Variables
│   │   ├── cicd.md               #     CI/CD
│   │   └── i18n.md               #     Internationalization
│   │
│   └── frameworks/               #   Framework-Specific (see each README.md)
│       ├── nextjs/               #     → [README.md](03_guidelines/frameworks/nextjs/README.md)
│       └── nodejs-cli/           #     → [README.md](03_guidelines/frameworks/nodejs-cli/README.md)
│
│
└── templates/                    # Project Templates [EN]
    └── nextjs/                   #     → [README.md](templates/nextjs/README.md)
```

</details>

<details>
<summary>Operations & Versioning</summary>

For update policies, framework addition steps, and versioning details, see **[docs/operation-guide.md](./docs/operation-guide.md)**.

### Update Frequency Guide

| Section | Frequency | Impact Scope |
|---------|-----------|--------------|
| `01_philosophy/` | Extremely rare | All projects (MAJOR change) |
| `02_decision-criteria/` | Rare | All projects |
| `03_guidelines/common/` | Medium | All projects |
| `03_guidelines/frameworks/` | High | Projects using the relevant FW only |
| `templates/` | Medium | New projects only |

### Adding Frameworks

To add a new framework (e.g., Remix, Nuxt, SvelteKit):

1. Create `overview.md` and `project-structure.md` under `03_guidelines/frameworks/{framework}/`
2. Enforce responsibility separation with `common/` (common rules -> common, FW-specific patterns -> frameworks)
3. Prepare templates under `templates/{framework}/`
4. Update the directory structure in this README

See [docs/operation-guide.md](./docs/operation-guide.md) for detailed steps and checklist.

**Versioning** — Managed with semantic versioning (git tags).

| Change Type | Version | Example |
|-------------|---------|---------|
| Major changes to philosophy / decision-criteria | MAJOR | v2.0.0 |
| Guideline additions/improvements | MINOR | v1.1.0 |
| Typo fixes, supplementary additions | PATCH | v1.0.1 |

Pin the submodule to a specific tag:

```bash
cd docs/ai-dev-os
git checkout v1.2.0
cd ../..
git add docs/ai-dev-os
git commit -m "chore: pin ai-dev-os to v1.2.0"
```

</details>

## Language Policy

- `01_philosophy/` and `02_decision-criteria/` contain **sample content in English**. After cloning, rewrite these in your **native language** to preserve nuance in your team's abstract thinking and decision-making frameworks.
- All other sections are written in **English** for AI compatibility and international accessibility.
- Multilingual operation guides are available in `docs/i18n/`.

## Related

| Repository | Description |
|---|---|
| [ai-dev-os](https://github.com/yunbow/ai-dev-os) | Framework specification and theory |
| [rules-python](https://github.com/yunbow/ai-dev-os-rules-python) | Python / FastAPI guidelines |
| [plugin-claude-code](https://github.com/yunbow/ai-dev-os-plugin-claude-code) | Skills, Hooks, and Agents for Claude Code |
| [plugin-kiro](https://github.com/yunbow/ai-dev-os-plugin-kiro) | Steering Rules and Hooks for Kiro |
| [plugin-cursor](https://github.com/yunbow/ai-dev-os-plugin-cursor) | Cursor Rules (.mdc) for guideline-driven development |
| [cli](https://github.com/yunbow/ai-dev-os-cli) | Setup automation — `npx ai-dev-os init` |
| [benchmark](https://github.com/yunbow/ai-dev-os-benchmark) | Quantitative benchmark — guideline impact on AI code quality |

## License

[MIT](./LICENSE)

---

Languages: English | [日本語](docs/i18n/ja/README.md) | [简体中文](docs/i18n/zh-CN/README.md) | [한국어](docs/i18n/ko/README.md) | [Español](docs/i18n/es/README.md)
