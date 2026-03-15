# Client Hooks Guidelines

> **[Replaceable]** This guide defines custom hooks (useAsyncAction, useListData, useTableState, etc.) for use with **Server Actions**. If your project uses **TanStack Query** or **SWR**, these hooks may be replaced by the library's built-in hooks (useQuery, useMutation, etc.). The patterns for separation of concerns and type safety still apply.

This document defines the implementation patterns and usage methods for custom hooks used in this project.

---

## 1. Basic Principles

- **Separation of concerns**: UI logic (dialog open/close, form field visibility, animation triggers) stays in components; data management (fetching, caching, pagination state, optimistic updates, error handling) lives in hooks
- **Reusability**: Place general-purpose hooks in `/src/hooks/`
- **Domain-specific**: Place hooks containing domain logic in `/features/{domain}/hooks/`

---

## 2. Hook List

| Hook | Location | Purpose |
|--------|------|------|
| `useAsyncAction` | /src/hooks | Async execution of Server Actions |
| `useTableState` | /src/hooks | Table state management (search, sort, pagination) |
| `useListData` | /src/hooks | List data fetching and management |
| `useFilterState` | /src/hooks | Filter state management |
| `usePaginatedList` | /src/hooks | Paginated list |
| `useDebounce` | /src/hooks | Value debouncing |
| `useJobPolling` | /features/{domain}/hooks | Job status polling |
| `useOnlineStatus` | /src/hooks | Network connection status monitoring |
| `useRovingTabIndex` | /src/hooks | Keyboard navigation |

---

## 3. useAsyncAction

Manages Server Actions execution, unifying loading state and error handling.

### Type Definitions

```ts
interface UseAsyncActionOptions<TData, TInput> {
  /** Server Action to execute */
  action: (input: TInput) => Promise<ActionResult<TData>>;
  /** Callback on success */
  onSuccess?: (data: TData) => void;
  /** Callback on failure */
  onError?: (error: ActionError) => void;
  /** Toast message on success */
  successMessage?: string;
  /** Whether to show toast on error (default: true) */
  showErrorToast?: boolean;
}

interface UseAsyncActionReturn<TData, TInput> {
  /** Execute the action */
  execute: (input: TInput) => Promise<ActionResult<TData>>;
  /** Whether loading */
  loading: boolean;
  /** Last error */
  error: ActionError | null;
  /** Clear the error */
  clearError: () => void;
  /** Last success data */
  data: TData | null;
}
```

### Usage Example

```tsx
"use client";

import { useAsyncAction } from "@/hooks/useAsyncAction";
import { createProject } from "@/features/project/server/project-actions";

function CreateProjectButton() {
  const { execute, loading, error } = useAsyncAction({
    action: createProject,
    onSuccess: (data) => {
      router.push(`/project/${data.id}`);
    },
    successMessage: "Project created successfully",
  });

  const handleClick = () => {
    execute({ name: "New Project" });
  };

  return (
    <>
      {error && <p className="text-destructive">{error.message}</p>}
      <Button onClick={handleClick} disabled={loading}>
        {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
        Create
      </Button>
    </>
  );
}
```

### Integration with Forms

```tsx
function ProjectForm() {
  const form = useForm<CreateProjectInput>({
    resolver: zodResolver(createProjectSchema),
  });

  const { execute, loading, error } = useAsyncAction({
    action: createProject,
    onSuccess: () => {
      form.reset();
      onClose();
    },
  });

  // Reflect server field errors in the form
  useEffect(() => {
    if (error?.fieldErrors) {
      Object.entries(error.fieldErrors).forEach(([field, messages]) => {
        form.setError(field as keyof CreateProjectInput, {
          type: "server",
          message: messages.join(", "),
        });
      });
    }
  }, [error, form]);

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit((data) => execute(data))}>
        {/* Fields */}
        <Button type="submit" disabled={loading}>
          {loading ? "Processing..." : "Create"}
        </Button>
      </form>
    </Form>
  );
}
```

---

## 4. useTableState

Centrally manages search, sort, and pagination state for tables/lists.

### Type Definitions

```ts
interface SortState {
  key: string;
  order: "asc" | "desc";
}

interface PaginationState {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

interface UseTableStateOptions<F extends Record<string, unknown>> {
  defaultSort?: SortState;
  defaultLimit?: number;
  defaultFilters?: F;
  debounceMs?: number;  // Default: 300ms
}

interface UseTableStateReturn<F> {
  // Search
  search: string;
  setSearch: (value: string) => void;
  debouncedSearch: string;
  // Filters
  filters: F;
  setFilter: <K extends keyof F>(key: K, value: F[K]) => void;
  setFilters: React.Dispatch<React.SetStateAction<F>>;
  // Sort
  sort: SortState;
  toggleSort: (key: string) => void;
  setSort: (sort: SortState) => void;
  // Pagination
  pagination: PaginationState;
  setPage: (page: number) => void;
  setLimit: (limit: number) => void;
  setTotal: (total: number) => void;
  // Reset
  reset: () => void;
  resetPage: () => void;
}
```

### Usage Example

```tsx
interface Filters {
  status: "all" | "active" | "inactive";
  type: string;
}

function ProjectListPage() {
  const {
    search,
    setSearch,
    debouncedSearch,
    filters,
    setFilter,
    sort,
    toggleSort,
    pagination,
    setPage,
    setTotal,
  } = useTableState<Filters>({
    defaultSort: { key: "createdAt", order: "desc" },
    defaultLimit: 20,
    defaultFilters: { status: "all", type: "" },
  });

  // Data fetching
  const { data, loading } = useListData({
    fetcher: getProjects,
    params: {
      search: debouncedSearch,
      status: filters.status === "all" ? undefined : filters.status,
      sortKey: sort.key,
      sortOrder: sort.order,
      page: pagination.page,
      limit: pagination.limit,
    },
  });

  // Update total
  useEffect(() => {
    if (data) setTotal(data.total);
  }, [data, setTotal]);

  return (
    <div>
      {/* Search */}
      <Input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search..."
      />

      {/* Filters */}
      <Select
        value={filters.status}
        onValueChange={(v) => setFilter("status", v)}
      >
        <SelectItem value="all">All</SelectItem>
        <SelectItem value="active">Active</SelectItem>
        <SelectItem value="inactive">Inactive</SelectItem>
      </Select>

      {/* Table */}
      <Table>
        <TableHeader>
          <SortableHeader
            label="Created Date"
            sortKey="createdAt"
            currentSort={sort}
            onSort={toggleSort}
          />
        </TableHeader>
        <TableBody>
          {data?.items.map((item) => (
            <TableRow key={item.id}>...</TableRow>
          ))}
        </TableBody>
      </Table>

      {/* Pagination */}
      <Pagination
        currentPage={pagination.page}
        totalPages={pagination.totalPages}
        onPageChange={setPage}
      />
    </div>
  );
}
```

---

## 5. useListData

Unifies list data fetching and state management. Works with ActionResult-format fetchers.

### Type Definitions

```ts
interface UseListDataOptions<TData, TParams> {
  fetcher: (params: TParams) => Promise<ActionResult<{ items: TData[]; total: number }>>;
  params: TParams;
  limit?: number;  // Default: 20
  autoFetch?: boolean;  // Default: true
  showErrorToast?: boolean;  // Default: true
}

interface UseListDataReturn<TData> {
  data: TData[];
  total: number;
  totalPages: number;
  page: number;
  setPage: (page: number) => void;
  loading: boolean;
  refetch: () => Promise<void>;
  refetchWithReset: () => Promise<void>;  // Reset to page 1 and refetch
}
```

### Usage Example

```tsx
const {
  data: logs,
  total,
  page,
  setPage,
  loading,
  refetch,
} = useListData({
  fetcher: async (params) => {
    const result = await getAuditLogs(params);
    if (result.success) {
      return {
        success: true,
        data: { items: result.data.logs, total: result.data.total },
      };
    }
    return result;
  },
  params: {
    action: actionFilter === "all" ? undefined : actionFilter,
    search: debouncedSearch || undefined,
    sortKey,
    sortOrder,
  },
  limit: 20,
});
```

### Features

- **Detects params changes**: When params change, resets to page 1 and auto-refetches
- **Auto-fetch on page change**: Automatically refetches when the page changes
- **Error toast**: Automatically displays toast on error (optional)

---

## 6. useFilterState

Manages filter state and provides active filter tracking.

### Type Definitions

```ts
interface FilterConfig<T extends Record<string, FilterValue>> {
  defaults: T;
  resetValues?: Partial<T>;
}

interface UseFilterStateReturn<T> {
  filters: T;
  setFilter: <K extends keyof T>(key: K, value: T[K]) => void;
  setFilters: (values: Partial<T>) => void;
  clearFilters: () => void;
  hasActiveFilters: boolean;
  activeFilterCount: number;
  isFilterActive: <K extends keyof T>(key: K) => boolean;
}
```

### Usage Example

```tsx
interface Filters {
  status: "all" | "active" | "inactive";
  category: string;
  dateRange: string;
}

function FilterableList() {
  const {
    filters,
    setFilter,
    clearFilters,
    hasActiveFilters,
    activeFilterCount,
  } = useFilterState<Filters>({
    defaults: {
      status: "all",
      category: "all",
      dateRange: "",
    },
  });

  return (
    <div>
      <Select
        value={filters.status}
        onValueChange={(v) => setFilter("status", v)}
      >
        ...
      </Select>

      {/* Show clear button when filters are active */}
      {hasActiveFilters && (
        <Button variant="ghost" onClick={clearFilters}>
          Clear Filters ({activeFilterCount})
        </Button>
      )}
    </div>
  );
}
```

### Combining with useTableState

```tsx
const filterState = useFilterState({
  defaults: { status: "all", type: "all" },
});

const tableState = useTableState({
  defaultSort: { key: "createdAt", order: "desc" },
});

// Reset page when filter changes
const handleFilterChange = <K extends keyof Filters>(key: K, value: Filters[K]) => {
  filterState.setFilter(key, value);
  tableState.resetPage();
};
```

---

## 7. usePaginatedList

A high-level hook that integrates search, filters, sort, and pagination.

### Type Definitions

```ts
interface UsePaginatedListOptions<T, F = string> {
  defaultLimit?: number;
  defaultSortBy?: string;
  defaultFilter?: F | "all";
  fetchFn: (params: LoadParams<F>) => Promise<LoadResult<T> | null>;
  autoReload?: boolean;  // Default: true
}

interface UsePaginatedListReturn<T, F> {
  items: T[];
  setItems: React.Dispatch<React.SetStateAction<T[]>>;
  pagination: PaginationInfo;
  isLoading: boolean;
  search: string;
  setSearch: React.Dispatch<React.SetStateAction<string>>;
  debouncedSearch: string;
  filter: F | "all";
  setFilter: React.Dispatch<React.SetStateAction<F | "all">>;
  sortBy: string;
  setSortBy: React.Dispatch<React.SetStateAction<string>>;
  handlePageChange: (newPage: number) => void;
  handleLimitChange: (newLimit: number) => void;
  handleRefresh: () => void;
}
```

### Usage Example

```tsx
const {
  items: presets,
  pagination,
  isLoading,
  search,
  setSearch,
  filter,
  setFilter,
  sortBy,
  setSortBy,
  handlePageChange,
  handleRefresh,
} = usePaginatedList<PresetSummary, PresetType>({
  defaultLimit: 12,
  defaultSortBy: "newest",
  fetchFn: async (params) => {
    const result = await getMyPresets({
      page: params.page,
      limit: params.limit,
      search: params.search,
      type: params.filter,
      sortBy: params.sortBy,
    });
    if (!result.success) return null;
    return {
      items: result.data.presets,
      page: result.data.page,
      limit: result.data.limit,
      total: result.data.total,
      totalPages: result.data.totalPages,
    };
  },
});
```

---

## 8. useDebounce

A simple hook for debouncing values.

### Implementation

```ts
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

### Usage Example

```tsx
const [search, setSearch] = useState("");
const debouncedSearch = useDebounce(search, 300);

useEffect(() => {
  // Only call API when debouncedSearch changes
  fetchData({ search: debouncedSearch });
}, [debouncedSearch]);
```

---

## 9. useJobPolling

Polls the status of background jobs (AI generation, image processing, etc.).

### Type Definitions

```ts
interface PendingJob {
  jobId: string;
}

interface JobResult<T extends PendingJob> {
  job: T;
  status: "completed" | "failed";
  resultUrl?: string;
  error?: string;
}

interface UseJobPollingOptions<T extends PendingJob> {
  collectPendingJobs: () => T[];
  getJobStatus: (jobId: string) => Promise<JobStatusResult>;
  onJobResults: (results: JobResult<T>[]) => boolean;
  onSave: () => Promise<void>;
  pollInterval?: number;  // Default: 5000ms
  enabled?: boolean;  // Default: true
}
```

### Usage Example

```tsx
interface ResourceJob extends PendingJob {
  resourceId: string;
  itemId: string;
  label: string;
}

useJobPolling<ResourceJob>({
  collectPendingJobs: () => {
    // Collect pending jobs
    return resources.flatMap((resource) =>
      (resource.generatedItems || [])
        .filter((item) => item.jobId && !item.resultUrl)
        .map((item) => ({
          jobId: item.jobId!,
          resourceId: resource.id!,
          itemId: item.id!,
          label: item.label || "Untitled",
        }))
    );
  },
  getJobStatus: async (jobId) => await getJobStatus(jobId),
  onJobResults: (results) => {
    let hasUpdates = false;
    for (const result of results) {
      if (result.status === "completed" && result.resultUrl) {
        // Update result URL
        updateResourceItem(result.job.resourceId, result.job.itemId, {
          resultUrl: result.resultUrl,
        });
        hasUpdates = true;
      } else if (result.status === "failed") {
        // Remove failed item
        removeResourceItem(result.job.resourceId, result.job.itemId);
        hasUpdates = true;
      }
    }
    return hasUpdates;
  },
  onSave: async () => {
    await saveResources();
  },
  pollInterval: 5000,
});
```

### Utility Functions

```ts
// Extract pending jobs from resources
const jobs = extractPendingJobsFromResources(
  resources,
  (resource, item) => ({
    jobId: item.jobId!,
    resourceId: resource.id!,
    itemId: item.id!,
    label: item.label || "Untitled",
  })
);
```

---

## 10. useOnlineStatus

Monitors network connection status and detects offline/online recovery.

### Type Definitions

```ts
interface OnlineStatusState {
  /** Current connection status */
  isOnline: boolean;
  /** Whether recovered from offline (auto-resets after 3 seconds) */
  wasOffline: boolean;
}
```

### Implementation

```ts
// hooks/useOnlineStatus.ts
"use client";

import { useState, useEffect, useCallback } from "react";

export function useOnlineStatus(): OnlineStatusState {
  const [state, setState] = useState<OnlineStatusState>({
    isOnline: typeof navigator !== "undefined" ? navigator.onLine : true,
    wasOffline: false,
  });

  const handleOnline = useCallback(() => {
    setState((prev) => ({
      isOnline: true,
      wasOffline: !prev.isOnline, // true if previously offline
    }));
  }, []);

  const handleOffline = useCallback(() => {
    setState({ isOnline: false, wasOffline: false });
  }, []);

  useEffect(() => {
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, [handleOnline, handleOffline]);

  // Reset wasOffline flag after 3 seconds
  useEffect(() => {
    if (state.wasOffline) {
      const timer = setTimeout(() => {
        setState((prev) => ({ ...prev, wasOffline: false }));
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [state.wasOffline]);

  return state;
}
```

### Usage Example

```tsx
function App() {
  const { isOnline, wasOffline } = useOnlineStatus();

  return (
    <>
      {/* Offline banner */}
      {!isOnline && (
        <div className="bg-destructive text-white p-2 text-center">
          No internet connection
        </div>
      )}

      {/* Online recovery notification */}
      {wasOffline && (
        <div className="bg-green-500 text-white p-2 text-center animate-fade-out">
          Connection restored
        </div>
      )}
    </>
  );
}
```

---

## 11. useRovingTabIndex

Implements keyboard navigation (arrow key movement) in menus and lists.

### Type Definitions

```ts
interface UseRovingTabIndexReturn<T extends HTMLElement> {
  containerRef: React.RefObject<T>;
  containerProps: {
    ref: React.RefObject<T>;
    onKeyDown: (event: KeyboardEvent<T>) => void;
    role: "menu";
    "aria-orientation": "vertical";
  };
  getItemProps: (index: number) => {
    role: "menuitem";
    tabIndex: 0 | -1;
  };
  focusItem: (index: number) => void;
}
```

### Implementation

```ts
// hooks/useRovingTabIndex.ts

import { useCallback, useRef, KeyboardEvent } from "react";

export function useRovingTabIndex<T extends HTMLElement = HTMLElement>() {
  const containerRef = useRef<T>(null);
  const focusedIndexRef = useRef(0);

  const getFocusableItems = useCallback((): HTMLElement[] => {
    if (!containerRef.current) return [];
    return Array.from(
      containerRef.current.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
      )
    );
  }, []);

  const focusItem = useCallback((index: number) => {
    const items = getFocusableItems();
    if (items.length === 0) return;

    const targetIndex = Math.max(0, Math.min(index, items.length - 1));
    items[targetIndex]?.focus();
    focusedIndexRef.current = targetIndex;
  }, [getFocusableItems]);

  const handleKeyDown = useCallback((event: KeyboardEvent<T>) => {
    const items = getFocusableItems();
    if (items.length === 0) return;

    const currentIndex = items.findIndex((item) => item === document.activeElement);

    switch (event.key) {
      case "ArrowDown":
      case "ArrowRight":
        event.preventDefault();
        focusItem(currentIndex + 1 < items.length ? currentIndex + 1 : 0);
        break;

      case "ArrowUp":
      case "ArrowLeft":
        event.preventDefault();
        focusItem(currentIndex - 1 >= 0 ? currentIndex - 1 : items.length - 1);
        break;

      case "Home":
        event.preventDefault();
        focusItem(0);
        break;

      case "End":
        event.preventDefault();
        focusItem(items.length - 1);
        break;
    }
  }, [getFocusableItems, focusItem]);

  const containerProps = {
    ref: containerRef,
    onKeyDown: handleKeyDown,
    role: "menu" as const,
    "aria-orientation": "vertical" as const,
  };

  const getItemProps = useCallback((index: number) => ({
    role: "menuitem" as const,
    tabIndex: index === focusedIndexRef.current ? 0 : -1,
  }), []);

  return { containerRef, containerProps, getItemProps, focusItem };
}
```

### Usage Example

```tsx
function NavigationMenu({ items }: { items: MenuItem[] }) {
  const { containerProps, getItemProps } = useRovingTabIndex();

  return (
    <nav {...containerProps} className="flex flex-col gap-1">
      {items.map((item, index) => (
        <a
          key={item.href}
          href={item.href}
          {...getItemProps(index)}
          className="p-2 hover:bg-muted rounded focus:ring-2"
        >
          {item.label}
        </a>
      ))}
    </nav>
  );
}
```

### Keyboard Controls

| Key | Action |
|------|------|
| Down / Right | Focus next item |
| Up / Left | Focus previous item |
| Home | Focus first item |
| End | Focus last item |

---

## 12. Best Practices

### Hook Placement

```
/src
  /hooks
    useAsyncAction.ts      # General-purpose hooks
    useTableState.ts
    useListData.ts
    useFilterState.ts
    usePaginatedList.ts
    useDebounce.ts
  /features
    /{domain}
      /hooks
        useJobPolling.ts   # Domain-specific hooks
        useItemCRUD.ts
        useResourcePage.ts
```

### Naming Conventions

- Hook name: `use` prefix + PascalCase (e.g., `useTableState`)
- File name: camelCase (e.g., `useTableState.ts`)
- Return type: `Use{HookName}Return`
- Options type: `Use{HookName}Options`

### DO (Recommended)

```tsx
// Stabilize function references with ref (prevent infinite loops in hooks that use callbacks in dependency arrays)
const fetchFnRef = useRef(fetchFn);
fetchFnRef.current = fetchFn;
```

### DON'T (Not Recommended)

```tsx
// Do not pass functions inline (causes infinite loops)
useListData({
  fetcher: async (params) => await getItems(params),  // New reference every time
  ...
});

// Do not omit dependency arrays
useEffect(() => {
  fetchData();
}, []);  // Won't re-run when fetchData changes

// Do not call state updates synchronously in succession
setPage(1);
setTotal(0);
// → May not be batched
```

---

## 13. Summary

| Hook | Purpose | Key Features |
|--------|------|----------|
| `useAsyncAction` | Server Actions execution | Loading, error, toast |
| `useTableState` | Table state | Search, sort, pagination, filters |
| `useListData` | List fetching | Auto-refetch, page reset |
| `useFilterState` | Filter management | Active tracking, clear |
| `usePaginatedList` | Integrated list | Unified search through pagination management |
| `useDebounce` | Debouncing | Input delay |
| `useJobPolling` | Job monitoring | Polling, completion/failure handling |
| `useOnlineStatus` | Network monitoring | Online/offline detection, recovery notification |
| `useRovingTabIndex` | Keyboard navigation | Arrow key movement, accessibility |
