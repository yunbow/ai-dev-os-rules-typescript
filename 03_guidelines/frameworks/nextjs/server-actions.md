# Server Actions Guidelines

> **[Replaceable]** This guide uses **Server Actions with the ActionResult pattern**. If your project uses **tRPC** or other RPC frameworks, replace the server communication patterns accordingly. The principles (type-safe error handling, authentication/authorization checks, input validation) remain the same.

This document defines the unified patterns and implementation guidelines for Next.js Server Actions.

---

## 1. Basic Principles

- Use the **ActionResult pattern** uniformly to achieve type-safe error handling
- Reduce boilerplate with the **withAction() wrapper**
- Standardize **authentication checks** and **IDOR (Insecure Direct Object Reference) prevention** — IDOR occurs when a user modifies an ID parameter (e.g., `/project/123`) to access another user's resource; prevent by always verifying `resource.userId === session.user.id` before operating on data
- Place Server Actions in `/features/{domain}/server/` — co-locates the server mutation logic with the feature's UI components, schemas, and services, making it easy to find and refactor as a unit

---

## 2. ActionResult Type

### Basic Structure

```ts
// lib/actions/action-helpers.ts

/** Success response */
export interface ActionSuccess<T> {
  success: true;
  data: T;
}

/** Error response */
export interface ActionFailure {
  success: false;
  error: ActionError;
}

/** ActionError type */
export interface ActionError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
  fieldErrors?: Record<string, string[]>;
}

/** Unified type (Discriminated Union) */
export type ActionResult<T> = ActionSuccess<T> | ActionFailure;
```

### Usage Examples

```ts
// On success
return { success: true, data: { id: project.id, name: project.name } };

// On failure
return {
  success: false,
  error: { code: "NOT_FOUND", message: "Project not found" },
};
```

---

## 3. withAction() Wrapper

### Purpose

- Reduce try-catch boilerplate
- Automatically load translation files
- Unified error conversion

### Signature

```ts
export async function withAction<T, D = unknown>(
  fn: (params: ActionContext<D>) => Promise<ActionResult<T>>,
  options: WithActionOptions<D>
): Promise<ActionResult<T>>;

interface WithActionOptions<D = unknown> {
  /** Translation namespace (e.g., "project", "user") */
  translationNamespace?: string;
  /** Request data (target for Zod parsing) */
  data?: D;
  /** Zod schema (used with data for validation) */
  schema?: ZodSchema<D>;
  /** Request ID (for tracing) */
  requestId?: string;
}

interface ActionContext<D> {
  /** i18n translation function */
  t: (key: string, values?: Record<string, unknown>) => string;
  /** Validated data (when schema is specified) */
  validData?: D;
}
```

### Usage Example

```ts
// features/project/server/project-actions.ts
"use server";

import { withAction } from "@/lib/actions/action-helpers";
import { createProjectSchema } from "../schema/project-schema";

export async function createProject(
  formData: CreateProjectInput
): Promise<ActionResult<{ id: string }>> {
  return withAction(
    async ({ t, validData }) => {
      // validData is already validated
      const project = await prisma.project.create({
        data: validData!,
      });

      return { success: true, data: { id: project.id } };
    },
    {
      translationNamespace: "project",
      data: formData,
      schema: createProjectSchema,
    }
  );
}
```

---

## 4. Error Handling

### createActionErrors() Utility

```ts
// Error generation helper
export function createActionErrors(t: TranslationFunction) {
  return {
    notFound: (entity = "resource"): ActionFailure => ({
      success: false,
      error: { code: "NOT_FOUND", message: t("errors.notFound", { entity }) },
    }),
    unauthorized: (): ActionFailure => ({
      success: false,
      error: { code: "UNAUTHORIZED", message: t("errors.unauthorized") },
    }),
    forbidden: (): ActionFailure => ({
      success: false,
      error: { code: "FORBIDDEN", message: t("errors.forbidden") },
    }),
    validation: (fieldErrors: Record<string, string[]>): ActionFailure => ({
      success: false,
      error: {
        code: "VALIDATION_ERROR",
        message: t("errors.validation"),
        fieldErrors,
      },
    }),
    internal: (details?: string): ActionFailure => ({
      success: false,
      error: { code: "INTERNAL_ERROR", message: t("errors.internal"), details },
    }),
  };
}
```

### Usage Example

```ts
export async function deleteProject(
  projectId: string
): Promise<ActionResult<void>> {
  return withAction(
    async ({ t }) => {
      const errors = createActionErrors(t);

      const session = await auth();
      if (!session?.user?.id) {
        return errors.unauthorized();
      }

      const project = await prisma.project.findUnique({
        where: { id: projectId },
      });

      if (!project) {
        return errors.notFound("project");
      }

      // IDOR prevention: ownership check
      if (project.userId !== session.user.id) {
        return errors.forbidden();
      }

      await prisma.project.delete({ where: { id: projectId } });

      return { success: true, data: undefined };
    },
    { translationNamespace: "project" }
  );
}
```

---

## 5. handleActionError() Function

Uniformly converts Prisma errors and Zod errors to ActionError:

```ts
export function handleActionError(
  error: unknown,
  t: TranslationFunction
): ActionError {
  // Zod validation error
  if (error instanceof ZodError) {
    return {
      code: "VALIDATION_ERROR",
      message: t("errors.validation"),
      fieldErrors: error.flatten().fieldErrors,
    };
  }

  // Prisma error
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    const prismaError = PRISMA_ERROR_MAP[error.code];
    if (prismaError) {
      return {
        code: prismaError.code,
        message: t(prismaError.messageKey),
      };
    }
  }

  // Domain error (custom error class)
  if (error instanceof DomainError) {
    const domainError = DOMAIN_ERROR_MAP[error.code];
    if (domainError) {
      return {
        code: domainError.code,
        message: t(domainError.messageKey),
      };
    }
  }

  // Unknown error
  return {
    code: "INTERNAL_ERROR",
    message: t("errors.internal"),
  };
}
```

### Error Mapping

```ts
// Prisma error mapping
export const PRISMA_ERROR_MAP: Record<string, { code: string; messageKey: string }> = {
  P2002: { code: "UNIQUE_CONSTRAINT", messageKey: "errors.unique" },
  P2025: { code: "NOT_FOUND", messageKey: "errors.notFound" },
  P2003: { code: "FOREIGN_KEY_CONSTRAINT", messageKey: "errors.reference" },
};

// Domain error mapping
export const DOMAIN_ERROR_MAP: Record<string, { code: string; messageKey: string }> = {
  INSUFFICIENT_QUOTA: { code: "INSUFFICIENT_QUOTA", messageKey: "errors.insufficientQuota" },
  RATE_LIMIT_EXCEEDED: { code: "RATE_LIMIT", messageKey: "errors.rateLimit" },
  FILE_TOO_LARGE: { code: "FILE_TOO_LARGE", messageKey: "errors.fileTooLarge" },
};
```

---

## 6. Authentication Helpers

> **Reference:** For the overall security strategy, see common/security.md

### requireAuth()

```ts
export async function requireAuth(): Promise<
  | { success: true; session: Session; userId: string }
  | ActionFailure
> {
  const session = await auth();
  if (!session?.user?.id) {
    return {
      success: false,
      error: { code: "UNAUTHORIZED", message: "Authentication required" },
    };
  }
  return { success: true, session, userId: session.user.id };
}
```

### requireOwnership()

```ts
export async function requireOwnership<T extends { userId: string }>(
  resource: T | null,
  userId: string
): Promise<
  | { success: true; resource: T }
  | ActionFailure
> {
  if (!resource) {
    return {
      success: false,
      error: { code: "NOT_FOUND", message: "Resource not found" },
    };
  }
  if (resource.userId !== userId) {
    return {
      success: false,
      error: { code: "FORBIDDEN", message: "You do not have permission to access this resource" },
    };
  }
  return { success: true, resource };
}
```

### Usage Example

```ts
export async function getProjectDetails(
  projectId: string
): Promise<ActionResult<ProjectDetails>> {
  return withAction(async () => {
    const authResult = await requireAuth();
    if (!authResult.success) return authResult;

    const project = await prisma.project.findUnique({
      where: { id: projectId },
    });

    const ownershipResult = await requireOwnership(project, authResult.userId);
    if (!ownershipResult.success) return ownershipResult;

    return { success: true, data: ownershipResult.resource };
  }, {});
}
```

---

## 7. Pagination

### executePaginatedQuery()

```ts
interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export async function executePaginatedQuery<T>(
  query: {
    findMany: (args: any) => Promise<T[]>;
    count: (args: any) => Promise<number>;
  },
  options: {
    where?: any;
    orderBy?: any;
    page: number;
    limit: number;
    include?: any;
    select?: any;
  }
): Promise<PaginatedResult<T>> {
  const { page, limit, where, orderBy, include, select } = options;
  const skip = (page - 1) * limit;

  const [items, total] = await Promise.all([
    query.findMany({
      where,
      orderBy,
      skip,
      take: limit,
      include,
      select,
    }),
    query.count({ where }),
  ]);

  return {
    items,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
}
```

### Usage Example

```ts
export async function getProjects(
  params: GetProjectsParams
): Promise<ActionResult<PaginatedResult<Project>>> {
  return withAction(
    async () => {
      const authResult = await requireAuth();
      if (!authResult.success) return authResult;

      const result = await executePaginatedQuery(prisma.project, {
        where: {
          userId: authResult.userId,
          ...(params.search && {
            name: { contains: params.search, mode: "insensitive" },
          }),
        },
        orderBy: { [params.sortKey]: params.sortOrder },
        page: params.page,
        limit: params.limit,
      });

      return { success: true, data: result };
    },
    { translationNamespace: "project" }
  );
}
```

---

## 8. Directory Structure

```
/src
  /lib
    /actions
      action-helpers.ts      # Shared helpers
      errors.ts              # Error definitions / mapping
  /features
    /{domain}
      /server
        {domain}-actions.ts  # Server Actions
      /schema
        {domain}-schema.ts   # Zod schemas
```

---

## 9. Best Practices

### DO (Recommended)

```ts
// Wrap with withAction() — handles try-catch, i18n loading, and error conversion
return withAction(async ({ t, validData }) => {
  // ...
}, { translationNamespace: "domain", data, schema });

// Keep transactions within a single prisma.$transaction
await prisma.$transaction(async (tx) => {
  await tx.order.update(...);
  await tx.orderItem.create(...);
});
```

### DON'T (Not Recommended)

```ts
// Do not write try-catch directly (withAction handles it)
try {
  // ...
} catch (e) {
  return { success: false, error: { ... } };
}

// Do not omit authentication/authorization checks
const project = await prisma.project.findUnique({ where: { id } });
// Operating without checking userId

// Do not return raw error messages to the client
return { success: false, error: { message: e.message } };
```

---

## 10. Client-side Usage

> **Reference:** For detailed form UI patterns, see frameworks/nextjs/form.md

### Integration with useAsyncAction

```tsx
import { useAsyncAction } from "@/hooks/useAsyncAction";
import { createProject } from "@/features/project/server/project-actions";

function CreateProjectForm() {
  const { execute, loading, error } = useAsyncAction({
    action: createProject,
    onSuccess: (data) => {
      router.push(`/project/${data.id}`);
    },
  });

  const handleSubmit = (values: CreateProjectInput) => {
    execute(values);
  };

  return (
    <form onSubmit={handleSubmit}>
      {error && <ErrorMessage error={error} />}
      {/* Form fields */}
      <Button type="submit" loading={loading}>
        Create
      </Button>
    </form>
  );
}
```

### Displaying Field Errors

```tsx
// When fieldErrors exist, integrate with React Hook Form
useEffect(() => {
  if (error?.fieldErrors) {
    Object.entries(error.fieldErrors).forEach(([field, messages]) => {
      form.setError(field as keyof FormValues, {
        type: "server",
        message: messages.join(", "),
      });
    });
  }
}, [error, form]);
```

---

## 11. Summary

| Item | Pattern |
|------|---------|
| Return value | `ActionResult<T>` (discriminated union) |
| Wrapper | Reduce boilerplate with `withAction()` |
| Authentication | Unified with `requireAuth()` |
| Authorization | IDOR prevention with `requireOwnership()` |
| Validation | Pass Zod schema to withAction |
| Error conversion | Unified with `handleActionError()` |
| Pagination | `executePaginatedQuery()` |
| i18n | Auto-load translations via translationNamespace |
