# State Management Guidelines

> **[Replaceable]** This guide uses **Server Actions + custom hooks** (useAsyncAction, useListData, etc.). If your project uses **TanStack Query** or **SWR**, replace the data fetching and caching patterns accordingly.

This document defines the management policy for server state and UI state in Next.js App Router.
This project adopts an architecture centered on **Server Actions + custom hooks** and does not depend on client-side data fetching libraries.

---

## 1. Core Principles

- **Data fetching and mutations are executed via Server Actions** (`features/*/server/`), never via client-side `fetch()` or API routes for internal operations
- **Client-side state management is unified through custom hooks** (`src/hooks/`) — components never manage loading/error/pagination state directly
- **UI state** (dialog open/close, selected items, form visibility) is managed locally within components using `useState` / `useReducer`
- **State sharing within a feature** is managed via React Context (`features/*/context/`) — Context is scoped to one feature, never used cross-feature
- **Global state management libraries (e.g., Zustand) are not used** — Server Actions + custom hooks replace the need for a global store

### Overall Data Flow

Data flows in one direction: Server Actions produce `ActionResult<T>`, custom hooks consume and manage that state, and components render from the hook's output. Components never write back to Server Actions except through hook-provided `execute`/`refetch` functions.

```typescript
Server Actions (data fetching / mutations)
    ↓ ActionResult<T>
Custom Hooks (state management / loading / error / pagination)
    ↓ data, loading, error, refetch
Client Component (UI rendering / event handling)
```

### Choosing a Data Fetching Strategy

| Strategy | Use Case | Example |
|----------|----------|---------|
| **RSC Direct Fetch** | Initial display data, SEO-focused | Project details, public pages |
| **Server Actions + useListData** | Paginated lists | Admin panel lists, logs |
| **Server Actions + useAsyncAction** | User-initiated mutations | Delete, update, create |
| **Server Actions + useTableState** | Tables (search / filter / sort) | Audit logs, user management |

---

## 2. Directory Structure

```text
src/
  hooks/                    # General-purpose custom hooks
    useAsyncAction.ts       # Async action execution and state management
    useListData.ts          # Paginated list fetching
    useTableState.ts        # Table state (search / filter / sort / pagination)
    useFilterState.ts       # Filter state management
    usePaginatedList.ts     # Pagination management
    useStatsData.ts         # Statistics data fetching
    useAnalyticsData.ts     # Analytics data fetching
    usePreviewForm.ts       # Form with preview
    useDebounce.ts          # Debounce
    useInitialFetch.ts      # Initial fetch control
    useOnlineStatus.ts      # Online status detection
    useRovingTabIndex.ts    # Roving tab index
  features/*/
    hooks/                  # Feature-specific hooks
    context/                # State sharing within a feature
  lib/
    actions/
      action-helpers.ts     # ActionResult type and common helpers
```

---

## 3. ActionResult Pattern with Server Actions

All data fetching and mutations are unified under the `ActionResult<T>` type.

```ts
// lib/actions/action-helpers.ts
type ActionResult<T> =
  | { success: true; data: T }
  | { success: false; error: ActionError };
```

> For details, see frameworks/nextjs/server-actions.md

---

## 4. Custom Hooks

### 4.1 useAsyncAction — Async Action Execution

Provides unified management of Server Action execution, loading state, error handling, and toast notifications.

```ts
const { execute: deleteItem, loading: deleting } = useAsyncAction({
  action: deleteBlacklistEntry,
  onSuccess: () => {
    setDeleteDialogOpen(false);
    refetch();
  },
  successMessage: t("deleteSuccess"),
});

// UI
<Button
  variant="destructive"
  onClick={() => deleteItem(selectedId)}
  disabled={deleting}
>
  {deleting ? tc("processing") : tc("delete")}
</Button>
```

**Features**:

- Automatically handles `ActionResult<T>`
- Optional toast notifications on success/error
- Stabilizes callbacks with `useRef` (avoids dependency array issues)
- Ensures type safety for arguments and return values via generics

### 4.2 useListData — Paginated List

Fetches and manages paginated list data from Server Actions.

```ts
const {
  data: logs,
  total,
  totalPages,
  page,
  setPage,
  loading,
  refetch,
} = useListData({
  fetcher: async (params) => getAuditLogs(params),
  params: {
    action: actionFilter === "all" ? undefined : actionFilter,
    search: debouncedSearch || undefined,
    sortKey,
    sortOrder,
  },
  limit: 20,
});
```

**Features**:

- Automatically resets to page 1 and re-fetches when `params` change
- Automatically re-fetches on page change
- `refetchWithReset()` for re-fetching with page reset
- Prevents duplicate initial fetches (`useRef`-based)

### 4.3 useTableState — Table State Management

Provides centralized management of search, filters, sorting, and pagination.

```ts
interface Filters {
  status: "all" | "active" | "inactive";
  type: string;
}

const {
  search, setSearch,
  debouncedSearch,
  filters, setFilter,
  sort, toggleSort,
  pagination, setPage, setTotal,
} = useTableState<Filters>({
  defaultSort: { key: "createdAt", order: "desc" },
  defaultLimit: 20,
  defaultFilters: { status: "all", type: "" },
});
```

**Features**:

- Built-in search debouncing (default 300ms)
- Automatically resets page on filter change
- Sort toggling (same key toggles asc/desc, different key starts with desc)
- `reset()` restores all state to initial values

### 4.4 useFilterState — Filter State Management

Manages type-safe filter state with active filter detection.

```ts
const {
  filters,
  setFilter,
  clearFilters,
  hasActiveFilters,
  activeFilterCount,
} = useFilterState({
  defaults: { status: "all", type: "all", search: "" },
});

// Reset button
{hasActiveFilters && (
  <Button variant="ghost" onClick={clearFilters}>
    Clear Filters ({activeFilterCount})
  </Button>
)}
```

**Features**:

- `"all"` and empty strings are not considered active
- Controls UI display with `hasActiveFilters` / `activeFilterCount`
- Customizable reset values via `resetValues`

---

## 5. Hook Composition Patterns

### Pattern A: List Screen (Standard)

```tsx
function UserListPage() {
  const { filters, setFilter, clearFilters } = useFilterState({ ... });
  const { data, loading, page, setPage, refetch } = useListData({
    fetcher: getUsers,
    params: { ...filters },
  });
  const { execute: deleteUser, loading: deleting } = useAsyncAction({
    action: deleteUserAction,
    onSuccess: () => refetch(),
  });

  return (
    <>
      <FilterBar ... />
      <DataTable data={data} loading={loading} />
      <Pagination page={page} onPageChange={setPage} />
    </>
  );
}
```

### Pattern B: Table Screen (with Search and Sort)

```tsx
function AuditLogPage() {
  const table = useTableState({ ... });
  const { data, loading } = useListData({
    fetcher: getAuditLogs,
    params: {
      search: table.debouncedSearch,
      ...table.filters,
      sortKey: table.sort.key,
      sortOrder: table.sort.order,
    },
  });

  return (
    <>
      <SearchInput value={table.search} onChange={table.setSearch} />
      <SortableTable sort={table.sort} onSort={table.toggleSort} />
      <Pagination page={table.pagination.page} onPageChange={table.setPage} />
    </>
  );
}
```

---

## 6. State Sharing Within a Feature (React Context)

When state sharing across multiple components within a feature is needed, use React Context.

```ts
// features/{domain}/context/ProjectContext.tsx
interface ProjectContextValue {
  projectId: string;
  title: string;
  completionStatus: CompletionStatus;
}

const ProjectContext = createContext<ProjectContextValue | null>(null);

export function useProjectContext(): ProjectContextValue {
  const context = useContext(ProjectContext);
  if (!context) throw new Error("useProjectContext must be used within ProjectProvider");
  return context;
}
```

**Rules**:

- Context is placed in `features/*/context/`
- Provider is set up in the feature's Layout
- Always provide a `useContext` wrapper hook (with null check)

---

## 7. UI State Management

### Local UI State

```ts
// Dialog open/close
const [isDialogOpen, setDialogOpen] = useState(false);

// Currently selected item
const [selectedId, setSelectedId] = useState<string | null>(null);
```

### Ref-Based Stabilization Pattern

Use `useRef` to exclude callback functions from dependency arrays.

```ts
// ✅ Hold callbacks in a Ref (prevents infinite loops)
const actionRef = useRef(action);
actionRef.current = action;

const execute = useCallback(async () => {
  await actionRef.current();
}, []); // Stable with empty dependency array
```

---

## 8. Best Practices

### DO (Recommended)

```ts
// ✅ Use Server Actions + useAsyncAction for mutation operations
const { execute, loading } = useAsyncAction({
  action: updateSettings,
  successMessage: t("saved"),
});

// ✅ Use useListData for paginated data fetching
const { data, refetch } = useListData({ fetcher: getItems, params });

// ✅ Fetch initial data in Server Component and pass via Props
export default async function Page() {
  const data = await getProjectData(id);
  return <ProjectClient initialData={data} />;
}
```

### DON'T (Not Recommended)

```ts
// ❌ Fetch directly within a component
useEffect(() => {
  fetch("/api/users").then(res => res.json()).then(setUsers);
}, []);

// ❌ Manage server data with a global state management library
const useStore = create((set) => ({
  users: [],
  fetchUsers: async () => { ... }, // Should use Server Actions
}));

// ❌ Manually manage loading state inside useEffect
const [loading, setLoading] = useState(false);
useEffect(() => {
  setLoading(true);
  action().finally(() => setLoading(false)); // Should use useAsyncAction
}, []);

// ❌ Include callbacks in dependency arrays causing infinite loops
const execute = useCallback(async () => {
  await action(); // Infinite loop if action is recreated on every render
}, [action]);
```

---

## 9. Summary

| State Type | Management Method | Location |
|-----------|-------------------|----------|
| Server data (initial display) | RSC direct fetch | `page.tsx` (Server Component) |
| Server data (lists) | `useListData` + Server Actions | `src/hooks/` |
| Data mutation operations | `useAsyncAction` + Server Actions | `src/hooks/` |
| Table state | `useTableState` | `src/hooks/` |
| Filter state | `useFilterState` | `src/hooks/` |
| Shared state within a feature | React Context | `features/*/context/` |
| Local UI state | `useState` / `useReducer` | Within component |
