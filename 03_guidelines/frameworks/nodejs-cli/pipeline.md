# Pipeline Orchestration Guidelines

This document defines how to design multi-step processing pipelines for CLI tools, covering step management, state persistence, caching, and error recovery.

---

## 1. Pipeline Architecture

## 1.1 Core Concepts

A pipeline is a sequence of **steps** that transform input data into output:

```text
Input → [Step 1: Collect] → [Step 2: Process] → [Step 3: Transform] → [Step 4: Output] → Result
```

Each step:

- Has a **name** (identifier) and **label** (display text)
- Receives a **config** and **work directory**
- Reads input from the work directory (previous step's output)
- Writes output to the work directory
- Is independently testable

## 1.2 Step Interface

```ts
interface PipelineStep {
  name: string;       // Unique identifier (e.g., "collect", "preprocess")
  label: string;      // Display label (e.g., "Step 1: Data Collection")
  execute(config: Config, workDir: string): Promise<void>;
}
```

## 1.3 Orchestrator Pattern

The orchestrator manages step registration, execution order, state persistence, and error handling:

```ts
class PipelineOrchestrator {
  private steps: PipelineStep[] = [];

  registerSteps(steps: PipelineStep[]): void;
  run(resumeModules?: string[]): Promise<StepResult[]>;

  // Internal
  private loadState(): PipelineState | null;
  private saveState(state: PipelineState): void;
  private initWorkDir(): void;
}
```

---

## 2. Work Directory Structure

Each pipeline run uses a dedicated work directory for intermediate files:

```text
.work/
├─ pipeline-state.json       # Pipeline execution state
├─ cache-meta.json           # Cache metadata
├─ raw/                      # Step 1 output: raw collected data
│  ├─ screenshots/
│  └─ *.json
├─ structured/               # Step 2 output: structured/parsed data
│  └─ *.json
├─ intermediate/             # Step 3 output: enriched/transformed data
│  └─ *.json
└─ reports/                  # Step 4 output: final deliverables
   └─ *.md
```

### Rules

- Each step writes to its own subdirectory or well-known file
- Steps read from previous step's output location
- The work directory is the **single source of truth** for pipeline state
- Initialize all required subdirectories at pipeline start

---

## 3. State Management

## 3.1 Pipeline State

Persist execution state to enable resume after interruption:

```ts
interface PipelineState {
  completedSteps: string[];       // Steps that finished successfully
  currentStep?: string;           // Step currently executing
  results: StepResult[];          // Outcome of each step
  startedAt: string;              // ISO timestamp
}
```

## 3.2 State Lifecycle

1. **Before each step**: Set `currentStep`, save state
2. **After successful step**: Add to `completedSteps`, clear `currentStep`, save state
3. **After failed step**: Record error in `results`, save state
4. **On resume**: Load state, skip completed steps

## 3.3 Resume Strategy

```ts
async run(resumeModules?: string[]): Promise<StepResult[]> {
  const state = this.loadState() ?? createInitialState();

  for (const step of this.steps) {
    // Skip completed steps (unless explicitly re-running)
    if (!resumeModules && state.completedSteps.includes(step.name)) {
      continue;
    }
    // Execute step...
  }
}
```

---

## 4. Caching

## 4.1 Cache Strategy

Cache expensive operations (network requests, AI API calls) to avoid redundant work:

| Strategy | Use Case |
|----------|----------|
| Input-based hash | Cache by hashing the step's input data |
| TTL-based expiry | Invalidate after configurable duration (e.g., `24h`) |
| Manual invalidation | `--no-cache` flag to force re-execution |

## 4.2 Cache Key Design

```ts
const cacheKey = hashString(`${stepName}:${inputHash}`);
```

- Include step name to avoid collisions
- Hash the input content (not file paths) for portability
- Use SHA-256 for content hashing

## 4.3 TTL Parsing

Support human-readable durations:

```ts
"30m"  → 1_800_000 ms
"24h"  → 86_400_000 ms
"7d"   → 604_800_000 ms
```

---

## 5. Error Handling in Pipelines

## 5.1 Error Wrapping

Wrap raw errors with step-specific error types:

```ts
function wrapStepError(stepName: string, error: unknown): AppError {
  if (error instanceof AppError) return error;
  const msg = error instanceof Error ? error.message : String(error);
  switch (stepName) {
    case "collect":    return new CollectionError(msg);
    case "preprocess": return new PreprocessError(msg);
    default:           return new AppError(msg, "UNKNOWN_ERROR");
  }
}
```

## 5.2 Graceful Degradation

- Non-critical steps (e.g., report generation) should not abort the entire pipeline
- Log warnings and continue where possible
- Record partial results in state

```ts
try {
  await step.execute(config, workDir);
} catch (error) {
  state.results.push({ step: step.name, success: false, error: msg });
  if (step.name !== "report") {
    logger.warn("Error occurred, continuing with remaining steps");
  }
}
```

## 5.3 Validation Between Steps

Validate the output of each step before the next step consumes it:

```ts
// Before step 2
const rawCollected = readJsonFileSync(collectedPath);
const { data, warnings } = validateCollectedData(rawCollected);
for (const w of warnings) logger.warn(w);
```

---

## 6. Manual Review Points

For pipelines that benefit from human review of intermediate results:

```ts
if (config.pause && process.stdin.isTTY) {
  logger.info("Intermediate files generated. Review and edit:");
  logger.info(`  ${workDir}/intermediate/`);
  logger.info("Press Enter to continue, or resume later with:");
  logger.info(`  my-tool resume --workdir ${workDir}`);
  await waitForEnter();
}
```

- Only prompt in interactive mode
- Allow `--no-pause` to skip for CI
- Provide the resume command for later continuation

---

## 7. Progress Reporting

Display step-based progress during execution:

```ts
logger.progress(stepNum, totalSteps, `${step.label}...`);
// Output: [2/4] Preprocessing...
```

After completion, show a summary:

```ts
for (const r of state.results) {
  const status = r.success ? "OK" : "FAIL";
  logger.info(`  [${status}] ${r.step} (${(r.duration / 1000).toFixed(1)}s)`);
}
```

---

## 8. Summary

- **Pipeline = ordered sequence of independent steps**
- **Work directory is the single source of truth** for all intermediate data
- **Persist state after every step** to enable resume
- **Cache expensive operations** with input-based hashing and TTL
- **Wrap errors per step** and support graceful degradation
- **Validate output between steps** to catch issues early
- **Support manual review points** for human-in-the-loop workflows
