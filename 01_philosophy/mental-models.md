$NOTE
# Mental Models

This defines the thinking patterns behind design decisions.
These are not concrete rules, but the "way of thinking" from which rules emerge.

---

## 1. Constraints Breed Creativity

**"Fewer choices lead to faster and better decisions."**

"Faster" here means reduced decision fatigue and shorter code review cycles. When the framework constrains choices (e.g., "no Enums, use union literals"), developers spend zero time debating the approach and reviewers can focus on logic rather than style. This compounds across a team — eliminating 10 micro-decisions per PR across 50 PRs/week saves meaningful cognitive load.

- `strict: true` doesn't take away freedom — it takes away room for bugs
- Tailwind's utility classes don't restrict expression — they guarantee consistency
- "No Enums," "No any," "No console.log" are constraints that raise the quality floor

> Unlimited freedom produces unlimited inconsistency.

---

## 2. Code is Read More Than Written

**"Write code that the future reader (including yourself 3 months later) can understand as quickly as possible."**

- Write code where intent is clear, rather than optimizing for brevity or shortness
- Consistency in naming conventions directly impacts searchability and refactoring ease
- Don't use comments to explain logic. Only document intent, side effects, and edge cases

> The code should convey not "what it does" but "why it does it this way."

---

## 3. Validate at Boundaries

**"Trust the internals, but validate strictly at the points of contact with the outside."**

```
External Input ──[Zod]──▶ Server Action ──[Types]──▶ Business Logic ──[ORM]──▶ DB
              ↑ Guard here                ↑ Protected by types here
```

- User input, API requests, webhooks, environment variables — all are "external"
- Once data passes validation, trust the types internally
- Don't over-apply defensive programming inside internal code (types provide the guarantee)

---

## 4. Design for Failure

**"Don't write code that assumes things work. Design with the assumption that things break."**

- All external communication can fail (timeouts, rate limits, service outages)
- Use types to prevent forgetting error handling (discriminated union `ActionResult<T>`)
- Design so that non-critical feature failures don't take down critical features. To distinguish: **critical features** are those whose failure prevents the user from completing the core task they came to do (e.g., authentication, checkout, data saving). **Non-critical features** are enhancements that improve the experience but whose absence doesn't block the core workflow (e.g., analytics, notifications, recommendations, avatar display). When in doubt, ask: "Can the user still accomplish their primary goal without this feature?"
- Distinguish between retryable and non-retryable errors

> Testing only the happy path is like selling umbrellas only on sunny days.

---

## 5. Unidirectional Data Flow

**"If the data flow is consistent, most bugs disappear."**

```
Server Actions (commands)
       ↓
    Hooks (state management / side-effect control)
       ↓
  Components (rendering / event firing)
       ↓
    Callbacks (events bubble up)
       ↓
Server Actions (next command)
```

- Data flows down (Props), events flow up (Callbacks)
- Do not use global state management libraries (Redux, Zustand, etc.)
- Server Actions are the single source of truth. Hooks are thin coordination layers

> Two-way data binding is convenient in small apps but creates chaos in large ones.

---

## 6. Rule of Three (Timing of Abstraction)

**"Premature abstraction leads to wrong abstraction."**

| Occurrences | Action |
|-------------|--------|
| 1 place | Write it inline — you have no evidence of a pattern yet |
| 2 places | Extract to a helper function if the logic is identical — but remain skeptical; two instances may be coincidentally similar |
| 3+ places | Extract to a factory function if the pattern is identical — three occurrences give enough evidence to identify the true common pattern and design a stable interface |
| 5+ places | Consider creating a base component if the components are similar — at this scale the maintenance cost of duplication exceeds the comprehension cost of abstraction |

- An abstraction used in only one place only adds comprehension cost
- If the configuration object keeps growing, it's a sign the abstraction is heading in the wrong direction

---

## 7. Make the Implicit Explicit

**"Implicit agreements become bugs the moment the team changes."**

- Make side effects clear through naming (`fetchUser()` = has side effects, `calculatePrice()` = pure)
- Always include a reason with `eslint-disable`
- Make technical debt visible with `FIXME` comments — don't leave it untracked
- Convey intent through naming convention suffixes and prefixes (`*-actions.ts`, `use*`, `create*Schema`)
