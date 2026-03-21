# UI Guidelines

> **[Replaceable]** This guide uses **Tailwind CSS + shadcn/ui (Radix UI)**. If your project uses **MUI**, **Mantine**, **Ant Design**, or other component libraries, replace the styling and component patterns accordingly. The principles (design tokens as SSOT, accessibility, component hierarchy) remain the same.

## Core Principles
- **Tailwind CSS** is adopted as a low-level utility layer
- **shadcn/ui** is used as the base for UI components (accessibility-ready, built on Radix UI)
- Leverage unified UI tokens (colors, spacing, typography)
- Domain-specific custom components are placed in `features/{domain}/components`
- **SSOT (Single Source of Truth)** for design tokens: CSS Variables (`globals.css` / `theme.css`) serve as the single canonical definition for all design tokens (colors, spacing, typography). Both Tailwind CSS config and shadcn/ui reference these variables rather than defining their own values. This ensures that a color or spacing change in one place propagates everywhere, and enables runtime theme switching (e.g., dark mode) via CSS custom property overrides without rebuilding.

## Directory Structure Example
```

/src
  /styles/
    globals.css      // Tailwind global styles
    theme.css        // Color and typography extensions (SSOT)
  /components/ui/     // shadcn/ui standard components (no extensions or customizations allowed)
  /components/common/ // App-wide shared UI components (extension/customization layer)
  /features/{domain}/components/ // Domain-specific UI
```

## Tailwind CSS Usage Guidelines
- Define spacing/colors/shadows as CSS Variables, and have `tailwind.config.js` reference them
- Use Tailwind only for visual styling within components
- Handle complex UI by extending or wrapping shadcn/ui components
- **Anti-patterns**:
  - Excessively long Tailwind class lists → Organize with CVA
  - Defining colors and spacing inline inconsistently → Unify with CSS Variables
- **Clear Decision Criteria**:
  - "Complex UI" and "large full-screen UI" are judged by reusability and logic coupling, not line count or screen size
  - Reusability: Styles used in 2+ places should be extracted into CVA or wrapper components
  - Logic: Styles tightly coupled with JS/TS if/else or map should be componentized

## shadcn/ui Usage Guidelines
- `/components/ui` is the home for shadcn/ui standard components — **avoid breaking changes**
- Application-specific extensions should be wrapped in `/components/common` or `/features`
- Composite components are extracted to `/components/common`
- Domain-specific components are placed in `features/{domain}/components`

## CVA (class-variance-authority) Usage
- **Purpose**: Centrally manage styles for components with many variations
- **Example**:
```ts
const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md text-sm font-medium transition",
  {
    variants: {
      variant: {
        default: "bg-primary text-white",
        ghost: "bg-transparent hover:bg-accent",
      },
      size: {
        sm: "h-8 px-2",
        md: "h-10 px-4",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "md",
    },
  }
);
```

## Dark Mode Support
* Use Tailwind's `dark:` prefix
* Use `next-themes` for shadcn/ui theme construction
* Define color schemes as CSS Variables in `globals.css` / `theme.css` (SSOT)

## Responsive Design
* Utilize Tailwind's `sm` through `2xl` breakpoints
* Consider PC display even for mobile-first components

## Accessibility (A11y)

* ARIA support based on Radix UI
* Color contrast conforming to **WCAG AA** — this means a minimum contrast ratio of 4.5:1 for normal text and 3:1 for large text (18px+ or 14px+ bold). Use tools like the Chrome DevTools color picker or axe-core to verify compliance. This is a legal requirement in many jurisdictions (ADA, EU Accessibility Act).

### Required aria Attribute Patterns

#### Badges and Notifications (Dynamic Content)

```tsx
// ❌ Screen readers cannot recognize this
<span className="badge">{count}</span>

// ✔ Add description with aria-label
<span
  className="badge"
  aria-label={`${count} unread notifications`}
>
  {count}
</span>

// ✔ Notify dynamic updates (aria-live)
<div aria-live="polite" aria-atomic="true">
  {status}
</div>
```

#### Progress Display

```tsx
// ❌ Progress status is not conveyed
<div className="progress">{percent}%</div>

// ✔ Add role and aria attributes
<div
  role="progressbar"
  aria-valuenow={percent}
  aria-valuemin={0}
  aria-valuemax={100}
  aria-label="Processing progress"
>
  {percent}%
</div>
```

#### Dialogs / Modals

```tsx
// ✔ Add label to close button
<Dialog>
  <DialogContent>
    <DialogClose aria-label="Close dialog" />
  </DialogContent>
</Dialog>

// ✔ Specify closeLabel in shadcn/ui Dialog
<DialogContent closeLabel="Close">
  ...
</DialogContent>
```

#### Image Slider / Carousel

```tsx
// ✔ Set current position and live region
<div
  role="region"
  aria-label="Image slider"
  aria-live="polite"
>
  <img
    src={images[currentIndex]}
    alt={`Image ${currentIndex + 1} / ${images.length}`}
  />
  <div aria-label={`Showing image ${currentIndex + 1} of ${images.length}`}>
    {/* Dot indicators */}
  </div>
</div>
```

### Accessibility Checklist

| Element | Required Action |
|---------|----------------|
| Icon button | MUST have `aria-label` describing the action (e.g., `aria-label="Delete task"`, `aria-label="Open menu"`). Every `<Button>` without visible text MUST have an aria-label. |
| Badge / Counter | Explain meaning with aria-label |
| Dynamically updated content | aria-live="polite" |
| Progress bar | role="progressbar" + aria-value* |
| Dialog close button | aria-label or closeLabel |
| Image slider | aria-live + position information |
| Form error | aria-describedby + role="alert" |
| Loading | aria-busy + sr-only text |

### Automated Testing

```bash
# Static checking with eslint-plugin-jsx-a11y
npm install -D eslint-plugin-jsx-a11y

# Runtime checking with axe-core
npm install -D @axe-core/react
```

## Performance
* Tailwind automatically removes unused classes
* shadcn/ui is SSR-compatible and supports tree shaking
* Images use lazy loading via Next.js `<Image />`

---

## Common UI Component Patterns

### Loading / Skeleton (Shimmer Effect)

Placeholder display while content is loading:

```tsx
// components/common/Skeleton.tsx
import { cn } from "@/lib/utils";

interface SkeletonProps {
  className?: string;
  variant?: 'text' | 'circular' | 'rectangular';
}

export function Skeleton({ className, variant = 'rectangular' }: SkeletonProps) {
  return (
    <div
      className={cn(
        "animate-pulse bg-muted rounded",
        variant === 'circular' && "rounded-full",
        variant === 'text' && "h-4 rounded",
        className
      )}
    />
  );
}

// Usage example: Card skeleton
export function CardSkeleton() {
  return (
    <div className="p-4 border rounded-lg space-y-3">
      <Skeleton className="h-40 w-full" />           {/* Image */}
      <Skeleton variant="text" className="w-3/4" />  {/* Title */}
      <Skeleton variant="text" className="w-1/2" />  {/* Subtext */}
    </div>
  );
}

// Usage example: Table row skeleton
export function TableRowSkeleton({ columns = 4 }: { columns?: number }) {
  return (
    <tr>
      {Array.from({ length: columns }).map((_, i) => (
        <td key={i} className="p-2">
          <Skeleton variant="text" />
        </td>
      ))}
    </tr>
  );
}
```

#### Shimmer Effect CSS Animation

```css
/* globals.css */
@keyframes shimmer {
  0% {
    background-position: -200% 0;
  }
  100% {
    background-position: 200% 0;
  }
}

.skeleton-shimmer {
  background: linear-gradient(
    90deg,
    hsl(var(--muted)) 25%,
    hsl(var(--muted-foreground) / 0.1) 50%,
    hsl(var(--muted)) 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
```

```tsx
// Skeleton with shimmer effect
<div className="skeleton-shimmer h-40 w-full rounded" />
```

### Image Upload / Loading

```tsx
// components/common/ImageUploader.tsx
interface ImageUploaderProps {
  onUpload: (file: File) => Promise<string>;
  currentImage?: string;
}

export function ImageUploader({ onUpload, currentImage }: ImageUploaderProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [preview, setPreview] = useState<string | null>(currentImage ?? null);

  const handleUpload = async (file: File) => {
    setIsUploading(true);
    setPreview(URL.createObjectURL(file)); // Show preview

    try {
      const url = await onUpload(file);
      setPreview(url);
    } catch (error) {
      setPreview(currentImage ?? null);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <div className="relative">
      {/* Preview area */}
      <div className="relative aspect-square border rounded-lg overflow-hidden">
        {preview ? (
          <Image src={preview} alt="Preview" fill className="object-cover" />
        ) : (
          <div className="flex items-center justify-center h-full bg-muted">
            <ImageIcon className="h-8 w-8 text-muted-foreground" />
          </div>
        )}

        {/* Loading overlay */}
        {isUploading && (
          <div className="absolute inset-0 bg-background/80 flex items-center justify-center">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
            <span className="sr-only">Uploading...</span>
          </div>
        )}
      </div>

      {/* Upload button */}
      <input
        type="file"
        accept="image/*"
        onChange={(e) => e.target.files?.[0] && handleUpload(e.target.files[0])}
        disabled={isUploading}
        className="absolute inset-0 opacity-0 cursor-pointer"
        aria-label="Upload image"
      />
    </div>
  );
}
```

#### Image Generation Loading Display

```tsx
// Image generation job status display
export function ImageGenerationStatus({ status, progress }: Props) {
  return (
    <div className="relative aspect-square border rounded-lg overflow-hidden">
      {/* Shimmer background */}
      <div className="absolute inset-0 skeleton-shimmer" />

      {/* Status display */}
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-2">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <span className="text-sm text-muted-foreground">{status}</span>
        {progress !== undefined && (
          <div className="w-32">
            <Progress value={progress} aria-label={`${progress}% complete`} />
          </div>
        )}
      </div>
    </div>
  );
}
```

### Table Sorting

```tsx
// components/common/SortableTable.tsx
import { ChevronUp, ChevronDown, ChevronsUpDown } from "lucide-react";

type SortDirection = 'asc' | 'desc' | null;

interface SortConfig {
  key: string;
  direction: SortDirection;
}

interface SortableHeaderProps {
  label: string;
  sortKey: string;
  currentSort: SortConfig | null;
  onSort: (key: string) => void;
}

export function SortableHeader({
  label,
  sortKey,
  currentSort,
  onSort,
}: SortableHeaderProps) {
  const isActive = currentSort?.key === sortKey;
  const direction = isActive ? currentSort.direction : null;

  return (
    <th>
      <button
        onClick={() => onSort(sortKey)}
        className="flex items-center gap-1 hover:text-foreground"
        aria-label={`Sort by ${label}`}
      >
        {label}
        {direction === 'asc' ? (
          <ChevronUp className="h-4 w-4" aria-label="Ascending" />
        ) : direction === 'desc' ? (
          <ChevronDown className="h-4 w-4" aria-label="Descending" />
        ) : (
          <ChevronsUpDown className="h-4 w-4 text-muted-foreground" />
        )}
      </button>
    </th>
  );
}

// Sort logic hooks
export function useTableSort<T>(
  data: T[],
  defaultSort?: SortConfig
) {
  const [sortConfig, setSortConfig] = useState<SortConfig | null>(defaultSort ?? null);

  const sortedData = useMemo(() => {
    if (!sortConfig?.key || !sortConfig.direction) return data;

    return [...data].sort((a, b) => {
      const aVal = a[sortConfig.key as keyof T];
      const bVal = b[sortConfig.key as keyof T];

      if (aVal < bVal) return sortConfig.direction === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortConfig.direction === 'asc' ? 1 : -1;
      return 0;
    });
  }, [data, sortConfig]);

  const handleSort = (key: string) => {
    setSortConfig(prev => {
      if (prev?.key !== key) return { key, direction: 'asc' };
      if (prev.direction === 'asc') return { key, direction: 'desc' };
      return null; // Reset on third click
    });
  };

  return { sortedData, sortConfig, handleSort };
}
```

### Pagination

```tsx
// components/common/Pagination.tsx
import {
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";

interface PaginationProps {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  siblingCount?: number;  // Number of pages to display before and after the current page
}

export function Pagination({
  currentPage,
  totalPages,
  onPageChange,
  siblingCount = 1,
}: PaginationProps) {
  // Generate array of page numbers
  const pages = useMemo(() => {
    const range = (start: number, end: number) =>
      Array.from({ length: end - start + 1 }, (_, i) => start + i);

    const leftSibling = Math.max(currentPage - siblingCount, 1);
    const rightSibling = Math.min(currentPage + siblingCount, totalPages);

    const showLeftDots = leftSibling > 2;
    const showRightDots = rightSibling < totalPages - 1;

    if (!showLeftDots && showRightDots) {
      return [...range(1, 3 + siblingCount * 2), '...', totalPages];
    }
    if (showLeftDots && !showRightDots) {
      return [1, '...', ...range(totalPages - 2 - siblingCount * 2, totalPages)];
    }
    if (showLeftDots && showRightDots) {
      return [1, '...', ...range(leftSibling, rightSibling), '...', totalPages];
    }
    return range(1, totalPages);
  }, [currentPage, totalPages, siblingCount]);

  return (
    <nav aria-label="Pagination" className="flex items-center gap-1">
      {/* First page */}
      <Button
        variant="outline"
        size="icon"
        onClick={() => onPageChange(1)}
        disabled={currentPage === 1}
        aria-label="Go to first page"
      >
        <ChevronsLeft className="h-4 w-4" />
      </Button>

      {/* Previous page */}
      <Button
        variant="outline"
        size="icon"
        onClick={() => onPageChange(currentPage - 1)}
        disabled={currentPage === 1}
        aria-label="Go to previous page"
      >
        <ChevronLeft className="h-4 w-4" />
      </Button>

      {/* Page numbers */}
      {pages.map((page, i) =>
        page === '...' ? (
          <span key={`dots-${i}`} className="px-2">...</span>
        ) : (
          <Button
            key={page}
            variant={currentPage === page ? 'default' : 'outline'}
            size="icon"
            onClick={() => onPageChange(page as number)}
            aria-label={`Go to page ${page}`}
            aria-current={currentPage === page ? 'page' : undefined}
          >
            {page}
          </Button>
        )
      )}

      {/* Next page */}
      <Button
        variant="outline"
        size="icon"
        onClick={() => onPageChange(currentPage + 1)}
        disabled={currentPage === totalPages}
        aria-label="Go to next page"
      >
        <ChevronRight className="h-4 w-4" />
      </Button>

      {/* Last page */}
      <Button
        variant="outline"
        size="icon"
        onClick={() => onPageChange(totalPages)}
        disabled={currentPage === totalPages}
        aria-label="Go to last page"
      >
        <ChevronsRight className="h-4 w-4" />
      </Button>
    </nav>
  );
}
```

#### Pagination Hooks

```tsx
// hooks/usePagination.ts
interface UsePaginationOptions {
  totalItems: number;
  itemsPerPage: number;
  initialPage?: number;
}

export function usePagination({
  totalItems,
  itemsPerPage,
  initialPage = 1,
}: UsePaginationOptions) {
  const [currentPage, setCurrentPage] = useState(initialPage);

  const totalPages = Math.ceil(totalItems / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const endIndex = Math.min(startIndex + itemsPerPage, totalItems);

  // Adjust when page change puts us out of data range
  useEffect(() => {
    if (currentPage > totalPages && totalPages > 0) {
      setCurrentPage(totalPages);
    }
  }, [totalItems, currentPage, totalPages]);

  const paginate = <T,>(data: T[]): T[] => {
    return data.slice(startIndex, endIndex);
  };

  return {
    currentPage,
    totalPages,
    startIndex,
    endIndex,
    setCurrentPage,
    paginate,
  };
}
```

### Confirmation Dialog

```tsx
// components/common/ConfirmDialog.tsx
interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: 'default' | 'destructive';
  onConfirm: () => void | Promise<void>;
}

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  variant = 'default',
  onConfirm,
}: ConfirmDialogProps) {
  const [isLoading, setIsLoading] = useState(false);

  const handleConfirm = async () => {
    setIsLoading(true);
    try {
      await onConfirm();
      onOpenChange(false);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isLoading}>
            {cancelLabel}
          </AlertDialogCancel>
          <AlertDialogAction
            onClick={handleConfirm}
            disabled={isLoading}
            className={variant === 'destructive' ? 'bg-destructive' : ''}
          >
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {confirmLabel}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```

### Empty State

```tsx
// components/common/EmptyState.tsx
interface EmptyStateProps {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: {
    label: string;
    onClick: () => void;
  };
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      {icon && (
        <div className="mb-4 text-muted-foreground">
          {icon}
        </div>
      )}
      <h3 className="text-lg font-semibold">{title}</h3>
      {description && (
        <p className="mt-1 text-sm text-muted-foreground max-w-sm">
          {description}
        </p>
      )}
      {action && (
        <Button onClick={action.onClick} className="mt-4">
          {action.label}
        </Button>
      )}
    </div>
  );
}

// Usage example
<EmptyState
  icon={<FolderOpen className="h-12 w-12" />}
  title="No projects found"
  description="Create a new project to get started"
  action={{
    label: "Create Project",
    onClick: () => setCreateDialogOpen(true),
  }}
/>
```

### Error State

```tsx
// components/common/ErrorState.tsx
interface ErrorStateProps {
  /** Error title */
  title?: string;
  /** Error message */
  message: string;
  /** Detail information (e.g., displayed only in development environment) */
  details?: string;
  /** Retry action */
  onRetry?: () => void;
  /** Retry button label */
  retryLabel?: string;
  /** Icon (default: AlertCircle) */
  icon?: React.ReactNode;
  /** Variant */
  variant?: "default" | "destructive" | "warning";
}

export function ErrorState({
  title = "An error occurred",
  message,
  details,
  onRetry,
  retryLabel = "Retry",
  icon,
  variant = "destructive",
}: ErrorStateProps) {
  const IconComponent = icon || <AlertCircle className="h-12 w-12" />;

  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center py-12 text-center",
        variant === "destructive" && "text-destructive",
        variant === "warning" && "text-amber-600"
      )}
      role="alert"
    >
      <div className="mb-4">{IconComponent}</div>
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="mt-1 text-sm text-muted-foreground max-w-md">{message}</p>
      {details && process.env.NODE_ENV === "development" && (
        <pre className="mt-2 text-xs bg-muted p-2 rounded max-w-lg overflow-auto">
          {details}
        </pre>
      )}
      {onRetry && (
        <Button onClick={onRetry} variant="outline" className="mt-4">
          <RefreshCw className="mr-2 h-4 w-4" />
          {retryLabel}
        </Button>
      )}
    </div>
  );
}

// Usage example
<ErrorState
  message="Failed to load data"
  onRetry={() => refetch()}
/>

// Network error
<ErrorState
  icon={<WifiOff className="h-12 w-12" />}
  title="Connection Error"
  message="Please check your internet connection"
  onRetry={() => location.reload()}
/>

// Permission error
<ErrorState
  icon={<ShieldX className="h-12 w-12" />}
  title="Access Denied"
  message="You do not have permission to view this page"
  variant="warning"
/>
```

### Loading Button

```tsx
// components/common/LoadingButton.tsx
import { Loader2 } from "lucide-react";
import { Button, ButtonProps } from "@/components/ui/button";

interface LoadingButtonProps extends ButtonProps {
  /** Whether it is loading */
  loading?: boolean;
  /** Text during loading (displays children if omitted) */
  loadingText?: string;
}

export function LoadingButton({
  children,
  loading = false,
  loadingText,
  disabled,
  ...props
}: LoadingButtonProps) {
  return (
    <Button disabled={loading || disabled} aria-busy={loading} {...props}>
      {loading && (
        <>
          <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden="true" />
          <span className="sr-only">Processing</span>
        </>
      )}
      {loading && loadingText ? loadingText : children}
    </Button>
  );
}

// Usage example
<LoadingButton loading={isSubmitting} type="submit">
  Save
</LoadingButton>

// Change text during loading
<LoadingButton loading={isDeleting} loadingText="Deleting...">
  Delete
</LoadingButton>

// With variant
<LoadingButton
  loading={isProcessing}
  variant="destructive"
  onClick={handleDelete}
>
  Delete Permanently
</LoadingButton>
```

#### Loading Button Patterns

```tsx
// Submit button
<LoadingButton
  type="submit"
  loading={form.formState.isSubmitting}
  disabled={!form.formState.isValid}
>
  Submit
</LoadingButton>

// Confirm dialog action button
<AlertDialogAction asChild>
  <LoadingButton
    loading={isDeleting}
    variant="destructive"
    onClick={handleConfirm}
  >
    Delete
  </LoadingButton>
</AlertDialogAction>

// Button with icon
<LoadingButton loading={isSaving}>
  {!isSaving && <Save className="mr-2 h-4 w-4" />}
  Save
</LoadingButton>
```

### Inline Loading

```tsx
// Action button within a list
function ActionCell({ item }: { item: Item }) {
  const [isLoading, setIsLoading] = useState(false);

  const handleAction = async () => {
    setIsLoading(true);
    try {
      await performAction(item.id);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={handleAction}
      disabled={isLoading}
    >
      {isLoading ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <Trash className="h-4 w-4" />
      )}
      <span className="sr-only">{isLoading ? "Deleting" : "Delete"}</span>
    </Button>
  );
}
```

### Common UI Components List

| Component | Location | Purpose |
|-----------|----------|---------|
| Skeleton | /components/common | Loading placeholder |
| ImageUploader | /components/common | Image upload + preview |
| SortableTable | /components/common | Sortable table |
| Pagination | /components/common | Pagination |
| ConfirmDialog | /components/common | Confirmation dialog |
| EmptyState | /components/common | Empty state display |
| ErrorState | /components/common | Error state display |
| LoadingButton | /components/common | Button with loading state |
| LoadingOverlay | /components/common | Full-screen loading |
| CookieConsent | /components/common | Cookie consent banner |

### Cookie Consent Dialog (GDPR / Privacy Law Compliance)

```tsx
// components/common/CookieConsent.tsx
"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";

type ConsentOptions = {
  necessary: boolean;     // Required cookies (always true)
  analytics: boolean;     // Analytics
  marketing: boolean;     // Marketing
  preferences: boolean;   // Preference storage
};

const CONSENT_KEY = "cookie-consent";
const CONSENT_VERSION = "1.0"; // Version change requires re-consent

export function CookieConsent() {
  const [open, setOpen] = useState(false);
  const [showDetails, setShowDetails] = useState(false);
  const [options, setOptions] = useState<ConsentOptions>({
    necessary: true,
    analytics: false,
    marketing: false,
    preferences: true,
  });

  useEffect(() => {
    // Check existing consent
    const stored = localStorage.getItem(CONSENT_KEY);
    if (stored) {
      const { version, options: savedOptions } = JSON.parse(stored);
      if (version === CONSENT_VERSION) {
        setOptions(savedOptions);
        return; // Already consented
      }
    }
    // Not consented or version changed
    setOpen(true);
  }, []);

  const saveConsent = (selectedOptions: ConsentOptions) => {
    localStorage.setItem(
      CONSENT_KEY,
      JSON.stringify({ version: CONSENT_VERSION, options: selectedOptions })
    );
    setOpen(false);

    // Enable scripts based on consent
    if (selectedOptions.analytics) {
      enableAnalytics();
    }
  };

  const acceptAll = () => {
    const allAccepted: ConsentOptions = {
      necessary: true,
      analytics: true,
      marketing: true,
      preferences: true,
    };
    setOptions(allAccepted);
    saveConsent(allAccepted);
  };

  const acceptSelected = () => {
    saveConsent(options);
  };

  const rejectOptional = () => {
    const onlyNecessary: ConsentOptions = {
      necessary: true,
      analytics: false,
      marketing: false,
      preferences: false,
    };
    setOptions(onlyNecessary);
    saveConsent(onlyNecessary);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>About Cookie Usage</DialogTitle>
          <DialogDescription>
            This site uses cookies to improve our services.
            If you agree to the use of cookies, please click "Accept All".
          </DialogDescription>
        </DialogHeader>

        {showDetails && (
          <div className="space-y-4 py-4">
            {/* Required Cookies */}
            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="necessary" className="font-medium">
                  Required Cookies
                </Label>
                <p className="text-sm text-muted-foreground">
                  Necessary for basic site functionality
                </p>
              </div>
              <Switch id="necessary" checked disabled aria-label="Required cookies (cannot be disabled)" />
            </div>

            {/* Analytics */}
            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="analytics" className="font-medium">
                  Analytics
                </Label>
                <p className="text-sm text-muted-foreground">
                  Analyzes site usage patterns
                </p>
              </div>
              <Switch
                id="analytics"
                checked={options.analytics}
                onCheckedChange={(checked) =>
                  setOptions((prev) => ({ ...prev, analytics: checked }))
                }
                aria-label="Allow analytics cookies"
              />
            </div>

            {/* Marketing */}
            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="marketing" className="font-medium">
                  Marketing
                </Label>
                <p className="text-sm text-muted-foreground">
                  Displays personalized advertisements
                </p>
              </div>
              <Switch
                id="marketing"
                checked={options.marketing}
                onCheckedChange={(checked) =>
                  setOptions((prev) => ({ ...prev, marketing: checked }))
                }
                aria-label="Allow marketing cookies"
              />
            </div>

            {/* Preference Storage */}
            <div className="flex items-center justify-between">
              <div>
                <Label htmlFor="preferences" className="font-medium">
                  Preference Storage
                </Label>
                <p className="text-sm text-muted-foreground">
                  Remembers settings such as language and theme
                </p>
              </div>
              <Switch
                id="preferences"
                checked={options.preferences}
                onCheckedChange={(checked) =>
                  setOptions((prev) => ({ ...prev, preferences: checked }))
                }
                aria-label="Allow preference cookies"
              />
            </div>
          </div>
        )}

        <DialogFooter className="flex-col gap-2 sm:flex-row">
          {!showDetails && (
            <Button variant="outline" onClick={() => setShowDetails(true)}>
              Advanced Settings
            </Button>
          )}
          <Button variant="outline" onClick={rejectOptional}>
            Required Only
          </Button>
          {showDetails ? (
            <Button onClick={acceptSelected}>Save Selection</Button>
          ) : (
            <Button onClick={acceptAll}>Accept All</Button>
          )}
        </DialogFooter>

        {/* Privacy policy link */}
        <p className="text-xs text-center text-muted-foreground">
          For details, please see our
          <a href="/privacy" className="underline hover:text-foreground">
            Privacy Policy
          </a>
        </p>
      </DialogContent>
    </Dialog>
  );
}

// Enable analytics (e.g., Google Analytics)
function enableAnalytics() {
  // Dynamically insert GTM or GA script
  if (typeof window !== "undefined" && !window.gtag) {
    const script = document.createElement("script");
    script.src = `https://www.googletagmanager.com/gtag/js?id=${process.env.NEXT_PUBLIC_GA_ID}`;
    script.async = true;
    document.head.appendChild(script);
  }
}
```

#### Getting Cookie Consent State

```tsx
// lib/cookie-consent.ts
export function getCookieConsent(): ConsentOptions | null {
  if (typeof window === "undefined") return null;

  const stored = localStorage.getItem("cookie-consent");
  if (!stored) return null;

  const { version, options } = JSON.parse(stored);
  if (version !== "1.0") return null;

  return options;
}

export function hasAnalyticsConsent(): boolean {
  const consent = getCookieConsent();
  return consent?.analytics ?? false;
}

// Usage example: Check before sending analytics
if (hasAnalyticsConsent()) {
  trackEvent("page_view", { path: pathname });
}
```

#### Placement in Layout

```tsx
// app/layout.tsx
import { CookieConsent } from "@/components/common/CookieConsent";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        {children}
        <CookieConsent />
      </body>
    </html>
  );
}
```

---

## Anti-patterns
* Scattering shadcn/ui components → Centrally manage in `/components/ui`
* Building large full-screen UI with Tailwind alone → Use shadcn/ui or custom components for complex UI
* Creating UI directly in the domain layer → UI must always go in the components layer
* Making app-specific modifications to `/components/ui` → Breaking changes are prohibited

## Summary
* **Tailwind CSS** for unified low-level utilities
* **shadcn/ui** for establishing the UI component system
* **CVA** for managing style variations
* **CSS Variables as SSOT to centralize tokens**
* Achieves UI consistency, accessibility, and scalability together
