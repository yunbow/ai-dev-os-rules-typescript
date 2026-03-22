$NOTE

# Anti-Patterns

This defines repeatedly observed "do not do this" patterns.
Each anti-pattern includes why it is problematic and what should be done instead.

---

## 1. Abandoning Type Safety

### Careless Use of `any`

```ts
// ❌ Creates a hole in the type system
const data: any = await fetchData()
data.nonExistent.property // Explodes at runtime

// ✔ unknown + type guard
const data: unknown = await fetchData()
if (isValidResponse(data)) {
  data.property // Type-safe
}
```

**Why it's problematic**: `any` disables type checking. A single `any` propagates through type inference — when `any` is assigned to a variable, every expression derived from it also becomes `any`, silently disabling checks across the entire call chain without compiler warnings.
**Exception**: Inadequate type definitions in external libraries. Always attach a `// FIXME` comment.

---

## 2. Architectural Deviation

### Direct fetch from Components

```ts
// ❌ Skipping layers
function MyComponent() {
  const [data, setData] = useState(null)
  useEffect(() => {
    fetch('/api/data').then(r => r.json()).then(setData)
  }, [])
}

// ✔ Go through Server Actions + Hooks
function MyComponent() {
  const { data } = useListData({ action: fetchDataAction })
}
```

**Why it's problematic**: Error handling, authentication, caching, and loading states end up implemented inconsistently.

### Introducing Global State Management Libraries

```ts
// ❌ Introducing Redux / Zustand / Recoil
const useStore = create((set) => ({ ... }))

// ✔ Server Actions + local state + Feature Context
const [state, setState] = useState(initial)
// or
const { value } = useFeatureContext()
```

**Why it's problematic**: Global state obscures the origin of data and undermines Server Actions' role as the source of truth.

---

## 3. Lack of Observability

### Missing Trace ID

```ts
// ❌ Cannot identify which request caused the error
logger.error('Something went wrong')

// ✔ Traceable via Request ID
logger.error({ requestId, userId, action }, 'Payment processing failed')
```

**Why it's problematic**: Without it, requests cannot be traced end-to-end during incident investigation.

---

## 4. Over-Abstraction

### Generalizing Code Used in Only One Place

```ts
// ❌ Abstraction with no reuse potential
function useSinglePurposeHook() { ... }
function createSingleUseFactory(options) { ... }

// ✔ Write it inline. Extract only after duplication appears in 3 places
```

**Why it's problematic**: Abstraction increases comprehension cost. An abstraction used in only one place leaves only the cost.

### Bloated Configuration Objects

```ts
// ❌ Too many options = the abstraction is heading in the wrong direction
createAction({
  schema, handler, middleware, errorHandler,
  retryPolicy, cachePolicy, rateLimitPolicy, auditPolicy,
})

// ✔ Extract only the common parts; implement special cases individually
const baseAction = createBaseAction(commonOptions)
const specialAction = async (input) => {
  // Special logic
  return baseAction(transformedInput)
}
```

**Why it's problematic**: A massive configuration object is not "flexible" — it is "complex."

---

## 5. Misuse of Naming and Comments

### Vague Naming

```ts
// ❌
const data = await getData()
const result = process(data)
function handleClick() { ... }

// ✔
const userProfile = await fetchUserProfile()
const validatedOrder = validateOrder(rawOrder)
function handleSubmitPayment() { ... }
```

**Why it's problematic**: `data`, `result`, `handle` convey nothing. The reader must read the implementation to understand the intent.

### Comments That Explain Logic

```ts
// ❌ Stating what the code already says
// Check if user's age is 18 or above
if (user.age >= 18) { ... }

// ✔ Document intent, exceptions, and side effects
// Legal requirement: minors cannot use the payment feature (see compliance guidelines)
if (user.age >= 18) { ... }
```

**Why it's problematic**: "What it does" is told by the code. Comments should tell "why it does it that way."

---

## 6. Inadequate Testing

### Testing Only the Happy Path

```ts
// ❌ Only the success case
test('creates user', async () => {
  const user = await createUser(validInput)
  expect(user).toBeDefined()
})

// ✔ Include error cases, boundary values, and security scenarios
test('rejects invalid email', ...)
test('prevents IDOR access', ...)
test('handles duplicate webhook events', ...)
test('fails gracefully on external API timeout', ...)
```

**Why it's problematic**: Bugs occur in error cases and at boundary values, not in the happy path.

---

## 7. Ignoring Performance

### Huge Bundle Sizes

```ts
// ❌ Importing the entire library
import _ from 'lodash'
import moment from 'moment'

// ✔ Import only the needed functions / use lightweight alternatives
import { debounce } from 'lodash/debounce'
import dayjs from 'dayjs'
```

**Why it's problematic**: Bundle size directly impacts load time. As a reference point, research by Google and Akamai shows that each additional 100KB of JavaScript adds roughly 100–300ms of parse/compile time on mobile devices, and pages loading in over 3 seconds see significantly higher bounce rates. Tree-shaking and selective imports keep the bundle lean.
