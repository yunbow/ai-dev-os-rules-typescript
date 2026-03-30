# MCP Server Guidelines

This document defines patterns and constraints for building **MCP (Model Context Protocol) servers** as Node.js CLI tools using the `@modelcontextprotocol/sdk` package.

MCP servers are a specialized form of Node.js CLI: they communicate over stdio using JSON-RPC, expose tools that AI agents invoke, and must operate within strict timeout and transport constraints that differ from ordinary CLI tools.

---

## 1. Transport Constraints

### 1.1 stdout Is JSON-RPC Only

**MUST NOT** use `console.log()` anywhere in an MCP server process. `stdout` is the JSON-RPC channel; any non-protocol bytes corrupt communication.

```typescript
// ❌ NEVER — breaks JSON-RPC framing
console.log("Server started");
console.log(JSON.stringify(data));

// ✅ Use structured logging to stderr or a log file
logger.info("Server started");
```

**Three-layer logging strategy:**

| Layer | Destination | Visible in |
|-------|------------|------------|
| `server.sendLoggingMessage()` | MCP notification → client | Claude Code conversation |
| `console.error()` / `stderr` | stderr | Claude Desktop logs |
| File logger | `~/.app-name/logs/` | Always (persistent) |

Default to **file logging** because Claude Code does not persist stderr between sessions.

### 1.2 Three-Minute Timeout

Every tool call must complete within **3 minutes**. This is the de-facto timeout enforced by MCP clients such as Claude Code.

```typescript
// ✅ Guard long-running operations with an explicit timeout
async function withTimeout<T>(fn: () => Promise<T>, ms = 150_000): Promise<T> {
  return Promise.race([
    fn(),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`Operation timed out after ${ms}ms`)), ms)
    ),
  ]);
}
```

If a workflow requires more than 3 minutes in total, **split it into multiple tools** so the AI calls them sequentially.

### 1.3 Declare Capabilities Explicitly

Declare every capability the server uses. Calling an undeclared capability throws a protocol error at runtime.

```typescript
const server = new Server(
  { name: "my-server", version: "1.0.0" },
  {
    capabilities: {
      tools: {},
      resources: {},   // only if you implement resources
      prompts: {},     // only if you implement prompts
      logging: {},     // MUST include if using server.sendLoggingMessage()
    },
  }
);
```

---

## 2. Tool Design

### 2.1 Naming: Verb-First

Tool names map to an action the AI needs to perform. Use a **verb** that describes the outcome; parameters carry the object and modifiers.

```text
✅ analyze_dimension(dimension: "business" | "ux")   — one tool, one verb
❌ analyze_business / analyze_ux                      — same verb, proliferates tools
```

| Pattern | Rule |
|---------|------|
| Same outcome → same tool | Use a parameter (`dimension`, `report_type`) instead of separate tools |
| Different processing characteristics (timeout, I/O, prerequisites) → separate tools | Split even when the verb is similar |
| Prefix with a namespace | `sa_collect_data`, `gh_create_issue` — prevents collisions in multi-server setups |

### 2.2 Always Use enum for String Choices

Free-text string parameters cause the AI to hallucinate values. Constrain every choice with `enum`.

```typescript
// ❌ AI may send "biz-context", "Business", or other variants
dimension: { type: "string", description: "Analysis dimension" }

// ✅ Only valid values accepted
dimension: {
  type: "string",
  enum: ["business-context", "technical-profile", "architecture"],
  description: "Dimension to analyze",
}
```

### 2.3 Flat Parameters

Avoid nested objects in `inputSchema`. The AI constructs top-level primitives more reliably.

```typescript
// ❌ Nested — AI struggles to fill correctly
{ config: { url: "...", options: { lang: "ja" } } }

// ✅ Flat — each parameter is unambiguous
{ url: "...", lang: "ja" }
```

### 2.4 Tool Annotations

Declare `annotations` on every tool. Clients use these for auto-approval logic and UI rendering.

```typescript
{
  name: "sa_list_projects",
  description: "...",
  inputSchema: { ... },
  annotations: {
    title: "プロジェクト一覧",
    readOnlyHint: true,      // no data mutation
    destructiveHint: false,  // no deletion / overwrite
    idempotentHint: true,    // same args → same result
    openWorldHint: false,    // no external network calls
  },
}
```

| Annotation | Set `true` when |
|------------|----------------|
| `readOnlyHint` | Tool only reads data (list, show, status, export) |
| `destructiveHint` | Tool deletes or overwrites data |
| `idempotentHint` | Repeated calls with the same args produce the same result |
| `openWorldHint` | Tool makes outbound network requests |

---

## 3. Tool Descriptions

Tool descriptions are **instruction documents for AI agents**, not human help text. Write them accordingly.

### 3.1 Five Required Elements

```text
1. What it does        — first sentence, most important
2. When to use it      — its place in the workflow
3. What it returns     — key fields in the response
4. What to do next     — guidance to the following tool
5. What NOT to do      — e.g., "Do NOT run CLI commands — use this tool"
```

```typescript
// ❌ Human-oriented
"Collect startup data from a URL."

// ✅ Agent-oriented
"Collect and preprocess startup data from a URL or source path. " +
"This is the FIRST step — call this before any analysis tool. " +
"Returns session_id, basic metrics, and detected tech stacks. " +
"After this, call sa_analyze_dimension for each analysis dimension. " +
"Do NOT run CLI commands — use this MCP tool instead."
```

### 3.2 Lead with the Most Important Information

AI reads descriptions from the top. Tool Search keyword matching also weights the beginning. Place the critical information in the first 200 characters.

### 3.3 Mark Deprecated Tools

```typescript
"DEPRECATED: use sa_collect_data + sa_analyze_dimension instead. ..."
```

---

## 4. Response Design

### 4.1 Two-Layer Response (JSON + Markdown)

Return every tool response as two layers: machine-readable JSON for the AI to process, and Markdown for the AI to display to the user.

```typescript
function toolResult(json: unknown, markdown: string): ToolResponse {
  return {
    content: [
      { type: "text", text: markdown },           // displayed to user
      { type: "text", text: JSON.stringify(json) }, // used by AI for next step
    ],
  };
}
```

```typescript
// ✅ Two-layer
return toolResult(
  { session_id: id, status: "collected", metrics },
  `## データ収集完了\n- セッションID: ${id}\n- 取得メトリクス: ${metrics.length}件`,
);

// ❌ JSON only — AI must re-summarize, consuming extra context
return { content: [{ type: "text", text: JSON.stringify({ session_id: id }) }] };
```

**Markdown size guideline:** Keep the markdown layer under 2,000 characters for typical responses. For large data sets, put a summary in markdown and full data in JSON.

### 4.2 Delegate AI Inference to the Client

Never call an LLM API inside an MCP server tool. Instead, return a prompt + data so the client AI performs the inference. This avoids timeout risk, double billing, and model mismatch.

```typescript
// ❌ Server calls AI internally
const analysis = await callClaude(prompt);
return toolResult(analysis, "...");

// ✅ Return prompt + data; client AI performs inference
const data = await loadFromDB(sessionId);
const prompt = renderTemplate(templateName, data);
return toolResult(
  { prompt_template: prompt, data, session_id: sessionId },
  "## 分析プロンプト準備完了\nプロンプトに従って分析を実行してください。",
);
```

---

## 5. Error Handling

### 5.1 Structured Three-Part Errors

Every error response must answer three questions:

1. **What happened** — `error_code` + `message`
2. **What was expected** — `expected`
3. **What to do next** — `suggestion` + `related_tools` + `retry_allowed`

```typescript
// ❌ Flat string — AI cannot act on it
return { isError: true, content: [{ type: "text", text: "Analysis failed" }] };

// ✅ Structured — AI can self-recover
return toolError({
  error_code: "prerequisites_not_met",
  message: "summary レポートに必要なディメンション分析が未完了です",
  expected: "business-context, technical-profile, architecture が完了済み",
  suggestion: "sa_analyze_dimension で不足ディメンションを先に実行してください",
  related_tools: ["sa_analyze_dimension", "sa_analysis_status"],
  retry_allowed: false,
});
```

### 5.2 Graceful Degradation

When part of a tool's work fails, return partial results rather than aborting entirely.

```typescript
const results = await Promise.allSettled([fetchMetrics(), fetchTechStack()]);
const succeeded = results
  .filter((r): r is PromiseFulfilledResult<Data> => r.status === "fulfilled")
  .map((r) => r.value);

if (succeeded.length === 0) {
  return toolError({ error_code: "fetch_failed", message: "...", retry_allowed: true });
}

return toolResult(
  { data: succeeded, incomplete: results.some((r) => r.status === "rejected") },
  `## 部分結果 (${succeeded.length}/${results.length} 取得成功)\n...`,
);
```

---

## 6. Multi-Turn Workflow Patterns

### 6.1 get-prompt / store-result Phase Split

For AI-delegated analysis, split the tool into two phases: one that returns the prompt+data, and one that stores the AI's result.

```text
AI → tool(phase="get-prompt")    → data + prompt template returned
AI → (runs inference)
AI → displays result to user
AI → tool(phase="store-result")  → result persisted to DB
```

This gives the AI (and user) an opportunity to review results before they are saved, and allows resuming interrupted workflows.

```typescript
const phaseSchema = z.enum(["get-prompt", "store-result"]);

async function handleAnalyzeDimension(args: AnalyzeArgs): Promise<ToolResponse> {
  if (args.phase === "get-prompt") {
    const data = await loadSessionData(args.session_id);
    return toolResult(
      { prompt: renderPrompt(args.dimension, data), session_id: args.session_id },
      "## 分析プロンプト準備完了",
    );
  }

  // phase === "store-result"
  await upsertAnalysisResult(args.session_id, args.dimension, args.result_json);
  return toolResult({ saved: true }, "## 分析結果を保存しました");
}
```

### 6.2 Prerequisite Checks

Synthesis tools must validate that dependent analyses are complete before running.

```typescript
const PREREQUISITES: Record<string, string[]> = {
  summary: ["business-context", "technical-profile", "architecture"],
  full:    ["business-context", "technical-profile", "architecture", "ui-structure", "competitor"],
};

const completed = await getCompletedDimensions(sessionId);
const missing = PREREQUISITES[reportType].filter((d) => !completed.includes(d));
if (missing.length > 0) {
  return toolError({
    error_code: "prerequisites_not_met",
    message: `不足ディメンション: ${missing.join(", ")}`,
    suggestion: "sa_analyze_dimension で不足ディメンションを先に実行してください",
    related_tools: ["sa_analyze_dimension"],
    retry_allowed: false,
  });
}
```

### 6.3 next_step Hints

Include a `next_step` hint in responses to guide the AI through sequential workflows autonomously.

```json
{
  "next_step": {
    "tool": "sa_analyze_dimension",
    "args": { "dimension": "technical-profile" },
    "reason": "business-context 完了。次は technical-profile を推奨。"
  }
}
```

`next_step` is a **suggestion**, not a command. The AI or user may choose a different order.

### 6.4 Sequential Execution (Not Parallel)

Design multi-step workflows for sequential execution. Parallel execution hides intermediate results from the user and prevents the AI from using earlier results in later steps.

```text
❌ Promise.all([analyze_business(), analyze_ux()])
   → user sees nothing until all complete; no cross-referencing possible

✅ analyze_dimension("business")   → user sees result, AI can note findings
   analyze_dimension("ux")         → AI can reference business findings
```

> This applies to the client-side orchestration of tool calls. Within a single tool handler, `Promise.all` for independent DB queries or fetch calls is fine.

---

## 7. Security

See **common/security.md** for full security guidelines. MCP-specific points:

- **Path traversal** (Section 3.12): Validate all file path parameters against an allowed base directory
- **Prompt injection / Tool poisoning** (Section 13): Sanitize any external content before returning it in tool responses; never return raw web page content directly
- **Secret exposure**: Tool responses must not contain API keys, tokens, or credentials — apply the same redact rules as logging

---

## 8. Testing

### 8.1 Unit Tests per Tool Handler

Test each handler in isolation with mocked dependencies.

```typescript
vi.mock("../../db/session-repository.js", () => ({
  getLatestSession: vi.fn().mockResolvedValue(mockSession),
}));

describe("handleAnalysisStatus", () => {
  it("returns progress for a known session", async () => {
    const result = await handleAnalysisStatus({ project_key: "example" });
    expect(result.isError).toBeUndefined();
    const json = JSON.parse(result.content[1].text); // index 1 = JSON layer
    expect(json.completed_dimensions).toHaveLength(2);
  });
});
```

### 8.2 Multi-Turn Integration Tests

Test the full collect → analyze → synthesize flow end-to-end.

```typescript
it("collect → analyze × N → synthesize", async () => {
  const collect = await handleCollectData({ url: "https://example.com" });
  const { session_id } = parseJsonLayer(collect);

  for (const dim of ALL_DIMENSIONS) {
    const prompt = await handleAnalyzeDimension({ session_id, dimension: dim, phase: "get-prompt" });
    await handleAnalyzeDimension({
      session_id, dimension: dim, phase: "store-result",
      result_json: mockAnalysisResult(dim), result_md: "...",
    });
  }

  const report = await handleSynthesizeReport({ session_id, report_type: "summary", phase: "get-prompt" });
  expect(report.isError).toBeUndefined();
});
```

### 8.3 Tool Definition Tests

Prevent regressions in tool schemas.

```typescript
describe("tool definitions", () => {
  it("all tools have descriptions longer than 50 chars", () => {
    for (const tool of ALL_TOOL_DEFS) {
      expect(tool.description.length).toBeGreaterThan(50);
    }
  });

  it("all string-choice parameters use enum", () => {
    for (const tool of ALL_TOOL_DEFS) {
      for (const prop of Object.values(tool.inputSchema.properties ?? {})) {
        if ((prop as any).description?.toLowerCase().includes("one of")) {
          expect((prop as any).enum).toBeDefined();
        }
      }
    }
  });
});
```

### 8.4 Protocol Smoke Test

```bash
npx @modelcontextprotocol/inspector node dist/mcp/index.js
# Verify: tool list appears, each tool can be called without error
```

---

## 9. New Tool Checklist

When adding a tool, complete every item before merging:

```text
□ Naming:       verb-first, namespaced (Section 2.1)
□ inputSchema:  flat + enum for all choices (Section 2.2, 2.3)
□ annotations:  readOnlyHint, idempotentHint, openWorldHint set (Section 2.4)
□ description:  5 elements present, agent-oriented, ≤200 chars for first sentence (Section 3.1)
□ Handler:
    □ Zod safeParse at dispatch level
    □ toolResult(json, markdown) two-layer response (Section 4.1)
    □ structured toolError on failure (Section 5.1)
    □ logger call with session context
□ server.ts:    added to ListToolsRequestSchema + CallToolRequestSchema
□ Security:
    □ file path params validated (common/security.md 3.12)
    □ no secrets in response
□ Tests:
    □ unit test (Section 8.1)
    □ tool definition test (Section 8.3)
```

---

## Summary

- **`stdout` is JSON-RPC only** — never `console.log()`; use stderr or file logging
- **3-minute timeout** — split workflows across multiple tools if needed
- **Verb-first naming + enum params** — reduces AI hallucination
- **Two-layer responses (JSON + Markdown)** — machine-readable and human-readable simultaneously
- **Delegate AI inference to the client** — never call an LLM API inside a tool handler
- **Structured three-part errors** — enable AI self-recovery without user intervention
- **get-prompt / store-result phase split** — separates data retrieval from persistence for safe multi-turn workflows
- **Sequential over parallel** — lets the AI and user review each step's result before proceeding
