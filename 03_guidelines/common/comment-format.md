# Comment Format Guidelines

This guideline defines **how to write code comments** so that they are useful for both AI coding assistants and human readers, while remaining mechanically verifiable through lint rules.

It is the concrete expansion of [`code.md`](./code.md) §6 (Comment Standards: "do not explain logic, only document intent, side effects, and exceptional conditions").

## 1. Two-layer Language Rule

Comments live in two distinct layers:

| Layer | Surface | Language | Rationale |
|---|---|---|---|
| **JSDoc `/** ... */`** | Hover, TypeDoc, MCP tool descriptions, IDE IntelliSense | **English (ASCII-only)** | Consumed directly by LLMs and tooling; English maximizes ecosystem compatibility |
| **Line comments `//`** | Source-only (does not appear in hover/TypeDoc) | **Team's native language allowed** | "Why" reasoning is denser when written in the author's working language |
| **Log / exception messages** | Runtime, end-user facing | **Team's native language** | Match the operator's language |
| **Test descriptions (`describe` / `it`)** | CI logs, reporters | **English** | Consistent CI output across teams and CI tools |

**Core invariant**: a JSDoc block must contain only ASCII characters; a `//` line comment may contain any language.

This split is enforced by lint (see §5). It avoids the common failure mode of mixing English summaries and native-language paragraphs inside the same JSDoc block, which destabilizes AI assistants that mimic surrounding comment style.

## 2. Four Templates

### 2.1 File Header

```ts
/**
 * Module orchestration: dependency resolution, parallel group execution,
 * and cascade-skip on upstream failure.
 */
// 責務境界: 拡張の実行順序の決定とエラー伝搬のみを担う。
// 個々のロジックは extensions/<name>.ts 側、依存グラフ計算は dependency-resolver.ts 側。
```

* JSDoc: one English sentence describing the module's responsibility.
* Optional `//` block immediately below: native-language note on responsibility boundaries (what this module does **not** do).
* Forbidden: argument/return descriptions, step-by-step procedure, scattered TODOs.

### 2.2 Exported Function

```ts
/**
 * Compute module-wide confidence from data sources and dimension count.
 *
 * @param dataSources - Provenance types contributing to this module.
 * @param dimensionCount - Number of analysis dimensions evaluated.
 * @returns Confidence in `[0, 1]`, rounded to 2 decimals.
 * @throws Never. Returns `0.1` for empty input by design.
 */
// なぜ 0.1 を返すか: 呼び出し側で「データ未投入」と
// 「データはあるが信頼度0」を区別する用途。
export function computeModuleConfidence(...) {
  // 重複除去前に length を見ると過大評価になる
  const uniqueSources = [...new Set(dataSources)];
  ...
}
```

| Element | Language | Required? |
|---|---|---|
| One-line summary | English | required |
| `@param` description | English | required when type cannot express the unit/range |
| `@returns` description | English | required (units, range, meaning of `null`) |
| `@throws` | English | required when function throws; otherwise `Never.` recommended |
| Pre-function `//` block | Native | optional, only when "why" is non-obvious |
| Inline `//` | Native | optional, only at counter-intuitive points |

**Avoid the "thin English summary" trap.** A summary that is merely the function name in prose is a §6 violation:

```ts
// ❌ Logic restatement; equivalent to the function name
/** Calculate weighted average of dimension scores. */
export function weightedAverage(...) { ... }

// ✅ States a contract the type signature cannot
/**
 * Aggregate dimension scores. Returns `0` for empty input as a sentinel,
 * so callers can distinguish "not yet evaluated" from "evaluated as zero".
 */
export function weightedAverage(...) { ... }
```

If a function is so trivial that the summary cannot say more than the name, omit JSDoc entirely (lint allows this for non-exported helpers).

### 2.3 Exported Constants and Type Definitions

```ts
/** Confidence bands per provenance type, expressed as `[min, max]` ranges in `[0, 1]`. */
const PROVENANCE_CONFIDENCE: Record<ProvenanceType, { min: number; max: number }> = { ... };

/** Outcome of a single extension run. `skipReason` is set only when `status === "skipped"`. */
export interface ExtensionOutcome { ... }
```

* One-line JSDoc, English.
* Document only contracts the type cannot express (invariants, nullability semantics, units).
* Do not enumerate values; the literal is right there in code.

### 2.4 Internal (Non-exported) Functions

* JSDoc is **not required**. Lint runs with `publicOnly: true`.
* If a comment helps, prefer a single `//` line in the team's native language.
* Reserve a multi-line `//` block above the function only when the function is 5+ lines long **and** the "why" is non-obvious.

## 3. JSDoc Tag Adoption

| Tag | Adoption | Rationale |
|---|:-:|---|
| `@param` | required | Capture units / ranges / nullability that types cannot |
| `@returns` | required | Same |
| `@throws` | required when throwing; `Never.` recommended otherwise | Make the error contract explicit; cannot be derived from types |
| `@deprecated` | required when deprecated | Migration target must be named in prose |
| `@example` | optional | Use sparingly on public utility APIs; avoid where doc-tests don't exist |
| `@module` | not adopted | A TS file already is a module; redundant |
| `@remarks` | not adopted | Use a regular paragraph in the description body |
| `@see` | not adopted | A short `// see also: ...` line below the JSDoc is denser |
| `@internal` | not adopted | If it is internal, do not `export` it |
| `@public` / `@beta` | not adopted | Premature unless running semver-disciplined releases |
| `@description` | not adopted | The body line already serves this purpose |

## 4. Anti-patterns to Detect

These patterns indicate a §6 violation regardless of language. They can be flagged in CI:

| Pattern | Example | Why it fails |
|---|---|---|
| Procedure description | `First, validate input. Then, compute. Finally, return.` | Restates code; redundant |
| Logic restatement | `If userId is empty, return null.` | Visible in the next 3 lines of code |
| Function-name paraphrase | `Calculate weighted average.` for `weightedAverage()` | Zero new information |
| Pseudo-spec | `This function takes A and returns B.` | The signature already states this |
| Stale `// TODO` without owner / ticket | `// TODO: fix this` | Not actionable; track in a ticket system |

The first three patterns can be detected mechanically via regex (`\b(first|then|finally|next),\s/i`, `\bIf .{1,30}, (return|set|use)\b/i`) and Jaccard similarity between the function name and the JSDoc first line.

## 5. Lint Configuration

Use [`eslint-plugin-jsdoc`](https://github.com/gajus/eslint-plugin-jsdoc).

```jsonc
// eslint.config.js (excerpt)
{
  plugins: { jsdoc },
  rules: {
    "jsdoc/require-jsdoc": ["error", {
      "publicOnly": true,
      "require": { "FunctionDeclaration": true, "ArrowFunctionExpression": false }
    }],
    "jsdoc/require-param": "error",
    "jsdoc/require-param-description": "error",
    "jsdoc/require-returns": "error",
    "jsdoc/require-returns-description": "error",
    "jsdoc/require-throws": "error",
    "jsdoc/check-param-names": "error",
    "jsdoc/check-tag-names": "error",
    "jsdoc/no-types": "error",                  // TS already provides types
    "jsdoc/tag-lines": ["error", "any", { "startLines": 1 }],
    "jsdoc/require-description": "error",

    // Core of the two-layer rule: ASCII-only inside JSDoc blocks
    "jsdoc/match-description": ["error", {
      "matchDescription": "^[\\x00-\\x7F]+$",
      "tags": {
        "param":   "^[\\x00-\\x7F]+$",
        "returns": "^[\\x00-\\x7F]+$",
        "throws":  "^[\\x00-\\x7F]+$"
      }
    }]
  }
}
```

`jsdoc/match-description` enforces ASCII-only inside the JSDoc body and the major tags. `//` line comments are outside its scope, so the team's native language remains free for design-intent commentary.

### Rollout (recommended)

1. Day 0: install `eslint-plugin-jsdoc`, set all rules to `warn`, record baseline violation count.
2. Pilot: migrate `src/utils/` (or your most central module) to the new format manually; refine templates as needed.
3. Bulk migration: convert remaining exported symbols in dependency order, allowing the LLM to translate JSDoc with the team's domain glossary as context.
4. Promote `warn` to `error` and add `--max-warnings 0` to CI.

## 6. Where Deeper Design Intent Belongs

When the "why" exceeds what fits in a `//` block (more than ~5 lines, or a decision worth recording for future readers), promote it out of source code:

| Length / nature | Destination |
|---|---|
| One-liner explaining a non-obvious choice | `//` line comment above the function |
| 2 – 5 lines of context | `//` block above the function |
| A decision with trade-offs and rejected alternatives | An ADR (Architecture Decision Record) in `docs/architecture/decisions/` |
| Cross-module invariant | A dedicated invariants document |
| Domain term that needs a canonical translation | A project glossary / domain dictionary |

The exact filenames and locations are project-specific; the rule is that JSDoc and source comments should not become a dumping ground for content that belongs in long-form documentation.

## 7. Why This Format

* **Mechanically verifiable** — the language split is enforced by a single ESLint rule, not by reviewer discipline.
* **AI-stable** — LLMs that mimic surrounding comment style see only English inside JSDoc blocks, removing a common source of inconsistent generation.
* **Tool-friendly** — TypeDoc, IDE hover, MCP tool descriptions, and code search all consume the JSDoc surface in their native language (English).
* **Author-friendly** — design intent can be written in the team's working language, where nuance is densest, in the form most likely to actually be written (`//` next to the code).
* **§6-aligned** — separating English contract (JSDoc) from native-language reasoning (`//`) makes it harder to write the thin "function-name paraphrase" summaries that violate §6.
