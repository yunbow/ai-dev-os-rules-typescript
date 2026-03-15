$NOTE
# Decision Criteria for Generalization and Abstraction

Criteria for deciding whether to "extract" or "leave as-is" when you find code duplication.

---

## Fundamental Principle

**"Premature abstraction leads to wrong abstraction."**

Abstraction increases the cost of understanding. It only has value when "enough reuse" exists — meaning 3+ call sites with genuinely identical logic, not just superficially similar code. Two similar-looking functions that evolve independently don't justify abstraction.

---

## Extraction Thresholds

| Occurrences | Decision | Extraction Target |
|---------|------|--------|
| 1 location | **Write it inline** | — |
| 2 locations | Extract to a helper function if the logic is identical | `lib/` or `helpers.ts` in the same directory |
| 3+ locations | Extract to a factory function if the pattern is identical | `lib/` |
| 5+ locations | Consider creating a base component if the components are similar | `components/common/` |

### Patterns That Should Be Consolidated

| Pattern | Consolidation Target | Reason |
|---------|--------|------|
| Authentication/authorization checks | `auth-helpers.ts` | Consistency of security |
| Error handling | `action-helpers.ts` | Unified error handling |
| Validation schemas | `schema/` directory | Schema reuse |

---

## Signs You Should NOT Extract

### Bloated Configuration Objects

```ts
// ❌ More than 5 options → the abstraction direction is wrong
createAction({
  schema, handler, middleware, errorHandler,
  retryPolicy, cachePolicy, rateLimitPolicy,
})

// ✔ Extract only the common parts; implement special cases individually
const baseAction = createBaseAction(commonOptions)
const specialAction = async (input) => {
  return baseAction(transformedInput)
}
```

### "We might use it in the future"

- Apply YAGNI (You Aren't Gonna Need It)
- Address future requirements when they actually emerge
- Don't abstract for a second occurrence that doesn't exist yet

### Similar but Not Identical

```ts
// ❌ Forced generalization resulting in excessive conditional branching
function processItem(item, type) {
  if (type === 'A') { /* Logic specific to A */ }
  else if (type === 'B') { /* Logic specific to B */ }
  // Only 10% is shared
}

// ✔ If the shared portion is small, write them separately
function processItemA(item) { ... }
function processItemB(item) { ... }
```

---

## Component Generalization Decisions

| Criteria | Generalize | Keep Separate |
|---------|----------|--------------|
| UI structure is identical, only data differs | ✔ Base component + Props | |
| 70%+ of UI is shared | ✔ Base + render props/slots | |
| Less than 30% of UI is shared | | ✔ Separate components |
| Generalization would result in 10+ Props | | ✔ Abstraction is inappropriate — 10+ props signals the component is trying to serve too many use cases. At that point, conditional logic inside the component typically exceeds the code you'd save by reusing it, and the prop combinations become difficult to test and document. Split into focused variants instead. |

---

## Hook Generalization Decisions

| Situation | Decision |
|------|------|
| Same fetch → state → error pattern in 3 locations | ✔ Extract to a generic Hook |
| Same CRUD pattern in 3 locations | ✔ Extract to `useResourceCRUD<T>` |
| 3+ branches inside a Hook | ✖ Split into separate Hooks |
| 5+ arguments for a Hook | ✖ Too much responsibility. Consider splitting |
