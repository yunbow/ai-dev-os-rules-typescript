# Authentication Guidelines

> **[Replaceable]** This guide uses **NextAuth.js (Auth.js) v5**. If your project uses **Clerk**, **Lucia**, **Auth0**, or another auth provider, replace the authentication patterns accordingly. The principles (server-first authentication, RBAC, session security) remain the same.

This document defines the **NextAuth.js design policy** for large-scale Next.js applications.
It covers **authentication flow, session management, API protection, RSC support, role-based access control (RBAC), and deployment environments** for large-scale applications.

---

## 1. Core Principles (App Router + NextAuth.js v5)

- Adopt **Auth.js (NextAuth.js) v5**, the official recommendation for App Router
- **Excellent compatibility with Server Components, enabling secure session access via `auth()`**
- **Minimize front-end session management (Server-first approach)**: By performing auth checks on the server, you avoid exposing session tokens and role data to client-side JavaScript. This eliminates an entire class of XSS-based session theft attacks, prevents the UI "flash" of unauthenticated content, and ensures that authorization decisions cannot be bypassed by manipulating client-side state.
- `auth()` can be used uniformly across API Routes / Server Actions / RSC
- Use Prisma Adapter for the DB (SQLite)

---

## 2. Directory Structure

```text
/src
  /lib/auth/
    config.ts          # NextAuth.js configuration (providers, callbacks)
    auth.ts            # Export-only for auth(), signIn(), signOut()
  /app/api/auth/[...nextauth]/route.ts  # NextAuth endpoint
  /middleware.ts       # Authentication guard
```

---

## 3. NextAuth.js Configuration (config.ts)

### Standard Configuration Using Prisma Adapter

```ts
import { PrismaAdapter } from "@auth/prisma-adapter";
import { db } from "@/lib/db";
import GitHub from "next-auth/providers/github";
import Credentials from "next-auth/providers/credentials";

export const authConfig = {
  adapter: PrismaAdapter(db),
  providers: [
    GitHub({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!,
    }),
    Credentials({
      name: "credentials",
      credentials: {
        email: {},
        password: {}
      },
      authorize: async (cred) => {
        // Verify user against DB
      },
    }),
  ],
  session: {
    strategy: "jwt",
    maxAge: 7 * 24 * 60 * 60,   // 7 days
    updateAge: 24 * 60 * 60,    // 24 hours
  },
  callbacks: {
    // Fetch latest role from DB on JWT refresh
    async jwt({ token, user }) {
      if (user) {
        token.role = user.role;
        token.version = user.sessionVersion ?? 0;
      } else {
        // Fetch latest role information from DB and update token
        const dbUser = await db.user.findUnique({ where: { id: token.id } });
        if (dbUser) {
          token.role = dbUser.role;
          token.version = dbUser.sessionVersion ?? 0;
        }
      }
      return token;
    },
    async session({ session, token }) {
      session.user.role = token.role;
      session.user.sessionVersion = token.version;
      return session;
    },
    // Processing for new user registration or account linking
    async signIn({ user, account }) {
      // Define credential and OAuth linking policy here
      return true;
    },
  },
};
```

---

## 4. Authentication Flow (Server-first)

- Perform authentication in Server Components / Server Actions to prevent unauthenticated state "flash" on the client side.
- Example of a page requiring authentication:

```ts
import { auth } from "@/lib/auth";

export default async function DashboardPage() {
  const session = await auth();
  if (!session) redirect("/login");

  return <Dashboard />;
}
```

---

## 5. Page Protection via Middleware (middleware.ts)

```ts
import { auth } from "@/lib/auth";

export default auth((req) => {
  return { authorized: !!req.auth };
});

export const config = {
  matcher: ["/dashboard/:path*", "/settings/:path*"],
};
```

---

## 6. Protecting API Routes / Server Actions

### API Route

```ts
import { auth } from "@/lib/auth";

export async function GET() {
  const session = await auth();
  if (!session) return new Response("Unauthorized", { status: 401 });

  return Response.json({ message: "ok" });
}
```

### Server Action

```ts
"use server";
import { auth } from "@/lib/auth";

export async function updateProfile(data: FormData) {
  const session = await auth();
  if (!session) throw new Error("Unauthorized");

  // Update processing
}
```

---

## 7. Role-Based Access Control (RBAC)

- Roles are consolidated in **session.user.role**
- Final check is done server-side; UI serves only as supplementary display

```ts
const session = await auth();
if (session?.user.role !== "admin") throw new Error("Forbidden");
```

- **Immediate role reflection via JWT version number mechanism**:
  The problem this solves: JWTs are stateless and valid until they expire. If an admin revokes a user's role, the user's existing JWT still contains the old role and remains valid. The `sessionVersion` counter in the DB is incremented whenever a user's role changes. On each JWT refresh, the callback compares the token's version against the DB version — if they differ, the token is updated with the new role. This provides near-real-time role revocation without requiring a full DB session strategy.

---

## 8. Session Strategy

- **JWT Strategy (Recommended)**: Easy to scale, suited for distributed environments
- DB Strategy: Consider when advanced session management is required

---

## 9. Deployment Environment Considerations

### Vercel

- Officially recommended environment for NextAuth.js
- Edge Runtime support
- Be mindful of Prisma connection limits (PlanetScale / Neon recommended)

---

## 10. Security Policy

- CSRF protection is auto-generated
- Cookie `secure`, `httpOnly`, `sameSite` are automatically configured per environment
- OAuth redirect URI is fixed per environment
- Passwords are hashed with argon2

---

## 11. Prohibited Practices (Anti-patterns)

- Directly parsing sessions in Routes without using auth()
- Tampering with role information on the front end
- Using DB session strategy for large-scale use cases

---

## 12. Summary

- **Server-first + NextAuth.js v5** is optimal for large-scale development
- Unify authentication, permissions, and sessions on the server side
- Use `auth()` securely in API Routes / Server Actions
- Stable operation on Vercel
- Systematized RBAC, session strategy, and API protection
- **JWT Callback-based role synchronization** with on-demand session invalidation for immediate response to permission changes
- Clear initial registration and linking policies for multi-provider usage
- Explicitly configure session `maxAge` / `updateAge`
