# CLI Design Guidelines

> **[Replaceable]** This guide uses **Commander** as the CLI framework. The same architectural principles apply when using alternatives such as **yargs**, **clipanion**, or **citty**.

This document defines how to design subcommands, options, arguments, and user interactions for Node.js CLI tools.

---

# 1. Subcommand Design

## 1.1 One Command = One Responsibility

Each subcommand should have a single, well-defined purpose.

```
my-tool analyze   # Run analysis pipeline
my-tool resume    # Resume interrupted analysis
my-tool compare   # Compare multiple results
```

## 1.2 Command Registration Pattern

Use separate `Command` instances for each subcommand, then attach to the root program:

```ts
import { Command } from "commander";

const program = new Command();

program
  .name("my-tool")
  .description("Tool description")
  .version("0.1.0");

const analyzeCmd = new Command("analyze")
  .description("Run analysis")
  .option("-u, --url <url>", "Target URL")
  .option("-o, --output <path>", "Output directory", "./output")
  .action(async (options) => { /* ... */ });

program.addCommand(analyzeCmd);
program.parse();
```

## 1.3 Subcommand Guidelines

| Rule | Rationale |
|------|-----------|
| Use **verbs** for command names | `analyze`, `compare`, `export` — not `analysis`, `comparison` |
| Keep to **1-2 words** | Short and memorable |
| Provide `.description()` for every command | Shown in `--help` output |
| Use `.requiredOption()` for mandatory inputs | Fail early with a clear message |

---

# 2. Option & Argument Design

## 2.1 Option Conventions

| Convention | Example | Rationale |
|-----------|---------|-----------|
| Short + long form | `-o, --output <path>` | Usability for both beginners and power users |
| Provide defaults where possible | `"./output"` | Minimize required configuration |
| Use `<value>` for required option values | `--url <url>` | Commander enforces this |
| Use `[value]` for optional option values | `--config [path]` | Falls back to default |
| Boolean flags use `--no-` prefix for negation | `--no-cache`, `--no-pause` | Standard CLI convention |

## 2.2 Common Options (Recommended)

Standardize these across all subcommands:

```ts
.option("-v, --verbose", "Enable verbose output", false)
.option("-o, --output <path>", "Output directory", "./output")
.option("-c, --config <path>", "Configuration file path")
.option("-f, --format <format>", "Output format (md|json|pdf)", "md")
```

## 2.3 Multi-Value Options

For comma-separated values, parse in the action handler:

```ts
.option("-m, --modules <modules>", "Modules to run (comma-separated)")
// In action:
const modules = options.modules?.split(",").map(m => m.trim());
```

For variadic arguments (multiple values as separate args):

```ts
.requiredOption("--reports <dirs...>", "Report directories (2 or more)")
```

---

# 3. Input Validation

## 3.1 Fail Fast

Validate inputs at the CLI layer before passing to core logic:

```ts
.action(async (options) => {
  if (!options.url && !options.source) {
    console.error("Error: specify at least --url or --source.");
    process.exit(1);
  }

  // Additional validation via shared validator
  const validation = validateInputs(options);
  if (!validation.valid) {
    console.error(`Error: ${validation.warnings.join("; ")}`);
    process.exit(1);
  }
});
```

## 3.2 Validation Layers

| Layer | Responsibility | Example |
|-------|---------------|---------|
| Commander built-in | Required options, types | `.requiredOption()` |
| CLI action handler | Mutual exclusivity, basic sanity | `if (!url && !source)` |
| Shared validator | Business rule validation | `validateInputs(config)` |
| Zod schema | Deep structural validation | Config file parsing |

---

# 4. Help & Documentation

## 4.1 Auto-Generated Help

Commander generates `--help` automatically from descriptions. Ensure:
- Every command has `.description()`
- Every option has a description string
- Default values are specified (shown in help)

## 4.2 Usage Examples

Add examples to help output for complex commands:

```ts
analyzeCmd.addHelpText("after", `
Examples:
  $ my-tool analyze --url https://example.com
  $ my-tool analyze --source ./src --modules business,ux
  $ my-tool analyze --url https://example.com --source ./src
`);
```

---

# 5. Output Design

## 5.1 Output Channels

| Channel | Purpose | Example |
|---------|---------|---------|
| `stdout` | Primary output (results, data) | Report content, JSON output |
| `stderr` | Diagnostics (logs, progress, errors) | Progress bars, warnings, errors |

This separation allows piping: `my-tool analyze --url ... > result.json`

## 5.2 Verbosity Levels

| Flag | Behavior |
|------|----------|
| (default) | INFO-level messages only |
| `--verbose` / `-v` | DEBUG-level messages included |
| `--quiet` / `-q` (optional) | Suppress all non-error output |

## 5.3 Progress Reporting

For long-running operations, display step-based progress:

```
[1/4] Collecting data...
[2/4] Preprocessing...
[3/4] Summarizing... (15.2s)
[4/4] Generating reports...

Pipeline complete:
  [OK]   collect     (3.1s)
  [OK]   preprocess  (1.2s)
  [OK]   summarize   (15.2s)
  [FAIL] report      (0.3s)
```

---

# 6. Interactive vs Non-Interactive

## 6.1 Detection

```ts
const isInteractive = process.stdin.isTTY && process.stdout.isTTY;
```

## 6.2 Behavior Differences

| Feature | Interactive | Non-Interactive (CI) |
|---------|------------|---------------------|
| Confirmation prompts | Show and wait | Skip (use `--yes` flag or `--no-pause`) |
| Progress spinners | Animated | Static line-by-line |
| Color output | Enabled | Disabled (respect `NO_COLOR`) |
| stdin prompts | Readline | Error or use defaults |

## 6.3 Confirmation Pattern

```ts
if (config.pause && process.stdin.isTTY) {
  await waitForConfirmation();
} else {
  logger.debug("Non-interactive mode: skipping confirmation");
}
```

---

# 7. Summary

- **One subcommand = one responsibility**
- **Fail fast** with clear error messages at the CLI layer
- **Separate stdout (data) from stderr (diagnostics)**
- **Provide defaults** for all optional parameters
- **Support both interactive and CI environments**
- **Validate inputs in layers** — Commander → CLI handler → shared validator → Zod
- **Add help text and examples** for complex commands
