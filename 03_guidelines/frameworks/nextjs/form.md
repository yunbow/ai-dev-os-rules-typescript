# Form Management Guidelines

> **[Replaceable]** This guide uses **React Hook Form + Zod**. If your project uses **Conform**, **Formik**, or a different validation library (e.g., **Valibot**), replace the form/validation patterns accordingly. The principles (server-side validation required, schema sharing, accessibility) remain the same.

This document defines the **form building guidelines** for Next.js large-scale applications.
It summarizes **scalable and maintainable implementation policies** centered on the validation system (Zod) and form management (React Hook Form).

---

## 1. Basic Principles
* Use **React Hook Form (RHF)** as the foundation for form state management.
* Use **Zod** as the sole validation schema definition tool,
  **sharing schemas between client and server**.
* Delegate submit processing to **Server Actions or API Routes**, separating side effects from the UI.
* Ensure safety from validation to DB layer in the order **Zod → Prisma**.
* Standardize UI components with **shadcn/ui**-based form parts.

---

## 2. Directory Structure

```
/src
  /features
    /{domain}
      /schema
        form-schema.ts      # Zod schema for forms
      /components
        Form.tsx            # Shared Form wrapper
        FormField.tsx       # shadcn/ui + RHF wrapper
        FormRadioGroup.tsx  # Dedicated wrapper example
        FormCheckbox.tsx    # Dedicated wrapper example
      /server
        submit.ts           # Server actions or API calls
      /utils
        setFieldErrors.ts   # ServerError → RHF setError conversion utility
```

---

## 3. Zod x RHF: Integrating Types and Validation

### Using ZodResolver

```ts
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";

const form = useForm<FormValues>({
  resolver: zodResolver(FormSchema),
  mode: "onChange",
});
```

---

## 4. Combining with UI (shadcn/ui)
### Shared Form Components

* `Form`: Wraps with RHF `FormProvider`
* `FormField`: input/select/textarea + error display
* `FormMessage`: Unified error messages
* **Abstraction guidelines**:

  * `FormField` serves as a Controller wrapper, supporting both with and without the render property
  * Accepts multiple child components (Input/Select/DatePicker, etc.) in a type-safe manner
  * Dedicated UI wrappers (e.g., `FormRadioGroup`, `FormCheckbox`) can be defined as standard patterns

```tsx
<Form>
  <FormField name="email">
    <Input placeholder="Email address" />
  </FormField>
  <FormRadioGroup name="gender" options={["Male", "Female"]} />
</Form>
```

### FormMessage Animation

Add animation to error message show/hide:

```tsx
// components/ui/form.tsx
import { AnimatePresence, motion } from "framer-motion";

const FormMessage = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, children, ...props }, ref) => {
  const { error, formMessageId } = useFormField();
  const body = error ? String(error?.message) : children;

  return (
    <AnimatePresence mode="wait">
      {body && (
        <motion.p
          ref={ref}
          id={formMessageId}
          role="alert"
          initial={{ opacity: 0, height: 0, y: -10 }}
          animate={{ opacity: 1, height: "auto", y: 0 }}
          exit={{ opacity: 0, height: 0, y: -10 }}
          transition={{ duration: 0.2, ease: "easeOut" }}
          className={cn("text-sm font-medium text-destructive", className)}
          {...props}
        >
          {body}
        </motion.p>
      )}
    </AnimatePresence>
  );
});
```

#### CSS-only Animation (Lightweight Version)

```tsx
// When not using framer-motion
const FormMessage = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, children, ...props }, ref) => {
  const { error, formMessageId } = useFormField();
  const body = error ? String(error?.message) : children;

  if (!body) return null;

  return (
    <p
      ref={ref}
      id={formMessageId}
      role="alert"
      className={cn(
        "text-sm font-medium text-destructive",
        "animate-in fade-in-0 slide-in-from-top-1 duration-200",
        className
      )}
      {...props}
    >
      {body}
    </p>
  );
});
```

```css
/* globals.css - Tailwind CSS animations */
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slide-in-from-top {
  from { transform: translateY(-4px); }
  to { transform: translateY(0); }
}
```

---

## 5. Server-side Validation and RHF Integration

> **Reference:** For detailed Server Actions patterns, see frameworks/nextjs/server-actions.md

### ZodValidationError Handling in Server Actions / API Routes
* Server-side validation based on Zod schema
* Catch ValidationError and return JSON with `fieldErrors` to the client

```ts
import { FormSchema } from "@/features/user/schema/form-schema";
import { ZodError } from "zod";

export async function submit(data: unknown) {
  try {
    const parsed = FormSchema.parse(data);
    // Pass to Prisma
  } catch (err) {
    if (err instanceof ZodError) {
      return { error: { type: "VALIDATION_ERROR", fieldErrors: err.formErrors.fieldErrors } };
    }
    throw err;
  }
}
```

### Shared Client-side Processing
* Integrate with `useForm`'s `setError` to display errors on fields without closing the form

```ts
import { setFieldErrors } from "@/features/user/utils/setFieldErrors";

const { execute, loading } = useAsyncAction(async (data: FormValues) => {
  const result = await submitUserForm(data);
  if (!result.success) {
    if (result.error?.type === "VALIDATION_ERROR") {
      setFieldErrors(form, result.error.fieldErrors);
    } else {
      toast.error("An unexpected error occurred");
    }
  }
});
```

#### `setFieldErrors.ts` Utility Example

```ts
import { UseFormReturn } from "react-hook-form";

export function setFieldErrors<T>(form: UseFormReturn<T>, fieldErrors: Record<string, string[]>) {
  Object.entries(fieldErrors).forEach(([field, messages]) => {
    form.setError(field as keyof T, { type: "server", message: messages.join(", ") });
  });
}
```

---
## 6. Data Shaping with Zod Transform

* Empty string → null conversion

```ts
const FormSchema = z.object({
  nickname: z.string().transform(e => e === "" ? null : e),
});
```

* Date string → Date object conversion

```ts
const FormSchema = z.object({
  birthDate: z.string().transform(str => new Date(str)),
});
```

* **Guideline**: Consolidate all differences between UI input and DB requirements within the Zod schema.
  This is important because it keeps `submit.ts` as a thin pass-through layer — it receives already-shaped data and passes it to Prisma without transformation logic. If shaping is done in `submit.ts` or scattered across components, every form endpoint accumulates its own conversion logic, making refactoring and testing harder.

---

## 7. Relationship with Prisma
* Shape Prisma input types (XxxCreateInput) according to the Zod schema
* Unify type differences (nullable, etc.) within the schema

---

## 8. Standard Error Handling Policy
### Client-side
* RHF `formState.errors` → `FormMessage`
* Server errors → toast display
* fieldErrors → Unified processing with `setFieldErrors` utility

### Server-side
* Distinguish between ZodError and ApplicationError
* Return in JSON structure:

```json
{
  "error": {
    "type": "VALIDATION_ERROR",
    "fieldErrors": { "email": ["Required"] }
  }
}
```

---

## 9. Async Processing (Server Actions + useAsyncAction Integration)
* Use the **useAsyncAction** hook for async processing after submit
* Example: User update Server Action → `refetch()` to retrieve the latest data

---

## 10. Platform Support
### Vercel
* Server Actions + SSR fast
* API Routes are also lightweight
* Form processing is based on Server Actions / API Routes

---
## 11. Anti-patterns (Things to Avoid)

* Passing directly to Prisma without server-side validation
* Proliferating copies of shadcn/ui components

---

## 12. Security Measures

### CSRF (Cross-Site Request Forgery) Protection

#### Server Actions Case

Next.js Server Actions have **built-in CSRF protection automatically**:

- Accept POST requests only
- `Origin` header verification
- Encrypted token verification generated by Next.js

```ts
// No additional CSRF measures needed for Server Actions
"use server";

export async function submitForm(data: FormData) {
  // Next.js automatically applies CSRF protection
  const parsed = FormSchema.parse(Object.fromEntries(data));
  // ...
}
```

#### API Route (Route Handler) Case

When calling Route Handlers directly, **explicit CSRF measures are required**:

```ts
// app/api/submit/route.ts
import { headers } from "next/headers";

export async function POST(request: Request) {
  const headersList = headers();
  const origin = headersList.get("origin");

  // Origin verification
  if (origin !== process.env.NEXT_PUBLIC_APP_URL) {
    return Response.json(
      { error: { code: "CSRF_ERROR", message: "Invalid origin" } },
      { status: 403 }
    );
  }

  // ...continue processing
}
```

### Double Submission Prevention

```tsx
const form = useForm<FormValues>({
  resolver: zodResolver(FormSchema),
});

const { isSubmitting } = form.formState;

return (
  <form onSubmit={form.handleSubmit(onSubmit)}>
    {/* ... fields ... */}
    <Button type="submit" disabled={isSubmitting}>
      {isSubmitting ? "Submitting..." : "Submit"}
    </Button>
  </form>
);
```

### Related Documentation

- CSRF/XSS general → common/security.md
- Server Actions security → frameworks/nextjs/server-actions.md
- Authentication integration → frameworks/nextjs/auth.md

---

## 13. Summary

* **RHF + Zod**: The standard for large-scale apps
* **Schema sharing**: Ensures client/server/DB consistency
* **shadcn/ui**: Unified form UI, improved reusability and extensibility
* Achieve reliable data processing with consistent error handling including RHF's setError, integrated with **Server Actions / API Routes**
* **Zod transforms** consolidate differences between UI input and DB requirements, keeping submit processing clean
* Clarify **FormField abstraction levels** and standardize dedicated UI wrappers
