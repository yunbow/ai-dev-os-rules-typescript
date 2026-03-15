# Coding Standards & Static Analysis Guidelines

This guideline defines the **TypeScript coding standards and static analysis tool policies** to be enforced across the entire project.

# 1. Key Principles
* **Prioritize readability and maintainability**
  Write code that communicates intent, rather than being concise or abbreviated.
* **Enforce type safety**
  Express intent through types rather than relying solely on inference.
* **Ensure quality through static analysis**
  Enforce formatting and code quality through tooling, not manual effort.

# 2. TypeScript Coding Standards

## 2.1 Type Definition Placement
* Project type definitions **must be separated into dedicated files**
* Use `type` for data structures, `interface` for contracts expected to change

```ts
type User = {
  id: string
  name: string
}

interface UserRepository {
  findById(id: string): Promise<User>
}
```

## 2.2 Handling Side Effects

* Functions with side effects must use naming conventions that signal mutation or I/O. Specifically:
  * **Prefix with a verb that implies external interaction**: `fetch`, `save`, `send`, `delete`, `upload`, `sync`, `notify`, `enqueue`
  * **Pure functions use computational verbs**: `calculate`, `format`, `parse`, `transform`, `validate`, `build`, `merge`
  * **Never use generic names** like `handle`, `process`, `do`, `run` for functions with side effects unless the name also includes the specific resource (e.g., `processPayment` is acceptable, `processData` is not)
* Do not create ambiguous utility functions

```ts
fetchUser()      // Has side effects - "fetch" signals network I/O
calculatePrice() // Pure function - "calculate" signals computation only
saveOrder()      // Has side effects - "save" signals persistence
buildQuery()     // Pure function - "build" signals construction
```

## 2.3 Prohibit Enum → Use Union Literals

```ts
type Theme = 'dark' | 'light'
```

Use Enum **only when external API compatibility is required**.

# 3. Lint Standards

## 3.1 Rule Sets

Recommended sets:

```
@typescript-eslint/recommended
import/order
no-unused-vars
no-redeclare
eqeqeq
```

Rules to enforce:

| Rule | Reason |
| --- | --- |
| strict:true + TS type rules | Foundation of type safety |
| no-explicit-any | Maintains type safety |
| no-unused-vars | Reduces unnecessary code |
| import/order | Improves readability |
| no-console | Prevents leftover debug statements |

## 3.2 unused-imports

```
eslint-plugin-unused-imports
```

Auto-removal is required.

## 3.3 Import Order Rules

```
builtin → external → internal → relative
```

# 4. Prettier

## 4.1 Configuration

```js
// prettier.config.js
/** @type {import('prettier').Config} */
const config = {
  semi: true,
  singleQuote: false,
  tabWidth: 2,
  trailingComma: "es5",
  printWidth: 100,
  plugins: ["prettier-plugin-tailwindcss"],
};
```

| Setting | Value | Reason |
|------|-----|------|
| `semi` | `true` | Follows TypeScript / Next.js standard conventions |
| `singleQuote` | `false` | Prioritizes consistency with JSON and JSX |
| `trailingComma` | `"es5"` | Adds trailing commas within ES5 compatibility (excludes function arguments) |
| `printWidth` | `100` | Ensures readability during code review |
| `tabWidth` | `2` | Standard indentation width |
| `prettier-plugin-tailwindcss` | - | Auto-sorts Tailwind classes |

# 5. CI / Git Hooks Integration

Static analysis and formatting **must not rely on manual execution**.
Always automate the following:

* Lint & format checks on commit
* CI as first line of defense on push / PR

---

# 6. Comment Standards

* Do not use comments to explain logic
* Only document intent, side effects, and exceptional conditions

```ts
/**
 * Calculate order amount
 * @throws ValueError
 */
```

---

# 7. Code Reuse Patterns

## 7.1 Server Actions Factory Pattern

**Purpose**: Centralize authentication, validation, and error handling

### Base Pattern: withAction

```ts
// lib/actions/action-helpers.ts
export function withAction<TInput, TOutput>(
  schema: z.ZodSchema<TInput>,
  handler: (input: TInput, userId: string) => Promise<TOutput>
): (input: TInput) => Promise<ActionResult<TOutput>> {
  return async (input) => {
    try {
      const session = await requireAuth();
      const validated = schema.parse(input);
      const result = await handler(validated, session.user.id);
      return { success: true, data: result };
    } catch (error) {
      return handleActionError(error);
    }
  };
}
```

### Resource Save Factory

```ts
// features/{domain}/server/resource-save-helper.ts
export function createResourceSaveAction<T extends ResourceBase>(
  options: ResourceSaveOptions<T>
) {
  return withAction(options.schema, async (input, userId) => {
    await requireProjectOwnership(input.projectId, userId);
    await checkQuota(userId, options.quotaCost);
    return options.save(input);
  });
}

// Usage example
export const saveProduct = createResourceSaveAction({
  schema: productSchema,
  quotaCost: 10,
  save: (data) => prisma.product.upsert({ ... })
});
```

### Image Generation Factory

```ts
// features/{domain}/server/ai-generation-helper.ts
export function createImageGenerationAction<T>(
  options: ImageGenerationOptions<T>
) {
  return withAction(options.schema, async (input, userId) => {
    const remaining = await checkQuota(userId, options.quotaCost);
    const jobId = await enqueueJob({ ...input, type: options.type });
    return { jobId, quotaRemaining: remaining };
  });
}
```

## 7.2 Authentication & Authorization Helpers

```ts
// lib/actions/auth-helpers.ts

// Simple authentication check
export async function requireAuth(): Promise<Session> {
  const session = await getSession();
  if (!session) throw new UnauthorizedError();
  return session;
}

// Project ownership check
export async function requireProjectOwnership(
  projectId: string,
  userId: string
): Promise<Project> {
  const project = await prisma.project.findUnique({
    where: { id: projectId, userId }
  });
  if (!project) throw new ForbiddenError();
  return project;
}

// Ownership check via relation
export async function requireRelationOwnership<T>(
  config: RelationConfig<T>
): Promise<T> {
  const record = await config.findRecord();
  if (!record || record.userId !== config.userId) {
    throw new ForbiddenError();
  }
  return record;
}
```

## 7.3 API Client Centralization

```ts
// lib/api/fetch-client.ts
export async function fetchWithAuth<T>(
  url: string,
  options?: RequestInit
): Promise<T> {
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers
    }
  });

  if (!res.ok) {
    throw new ApiError(res.status, await res.text());
  }

  return res.json();
}

// Usage example: eliminating duplication
// ❌ Writing fetch directly in each component
const res = await fetch('/api/generate/auto-config', { ... });

// ✔ Using the shared client
const result = await fetchWithAuth<AutoConfigResult>(
  '/api/generate/auto-config',
  { method: 'POST', body: JSON.stringify(data) }
);
```

## 7.4 Hooks Centralization

### Generic CRUD Hook

```ts
// features/{domain}/hooks/useResourceCRUD.ts
export function useResourceCRUD<T extends { id?: string }>(
  options: UseResourceCRUDOptions<T>
) {
  const [items, setItems] = useState<T[]>(options.initialItems);

  const addItem = useCallback((item: T) => {
    setItems(prev => [...prev, { ...item, id: item.id || generateId() }]);
  }, []);

  const updateItem = useCallback((id: string, updates: Partial<T>) => {
    setItems(prev => prev.map(item =>
      item.id === id ? { ...item, ...updates } : item
    ));
  }, []);

  const deleteItem = useCallback((id: string) => {
    setItems(prev => prev.filter(item => item.id !== id));
  }, []);

  return { items, addItem, updateItem, deleteItem };
}
```

## 7.5 Component Reuse Patterns

### Base Component + Specialized Component

```tsx
// Base: shared/BaseResourceDialog.tsx
export function BaseResourceDialog({
  title,
  onSubmit,
  renderOptions,
  ...props
}: BaseProps) {
  return (
    <Dialog {...props}>
      <DialogHeader>{title}</DialogHeader>
      <FileUpload />
      {renderOptions?.()}
      <StatusBanner />
      <SubmitButton onClick={onSubmit} />
    </Dialog>
  );
}

// Specialized: ProductEditDialog.tsx
export function ProductEditDialog(props) {
  return (
    <BaseResourceDialog
      title="Edit Product"
      onSubmit={handleProductSubmit}
      renderOptions={() => (
        <>
          <CategorySelector />
          <PriceInput />
        </>
      )}
    />
  );
}
```

## 7.6 Criteria for Code Reuse

| Condition | Action |
|------|------|
| Same logic in 2+ places | Extract into a helper function |
| Same pattern in 3+ places | Extract into a factory function |
| Similar components in 5+ places | Consider creating a base component |
| Authentication/authorization patterns | Consolidate in auth-helpers.ts |
| Error handling | Consolidate in action-helpers.ts |

## 7.7 Anti-Patterns

```ts
// ❌ Premature abstraction
// Abstracting when only used in one place
const useSingleUseHook = () => { ... };

// ❌ Bloated configuration objects
createAction({
  option1, option2, option3, option4, option5, // Too many
  ...
});

// ✔ Extract only the common parts, implement special cases individually
const baseAction = createBaseAction(commonOptions);
const specialAction = async (input) => {
  // Special logic
  return baseAction(transformedInput);
};
```
