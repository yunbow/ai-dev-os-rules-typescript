# Next.js Project Template

## Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Next.js (App Router) |
| Language | TypeScript (strict: true) |
| Styling | Tailwind CSS v4 + shadcn/ui |
| Forms | React Hook Form + Zod |
| Authentication | NextAuth.js v5 |
| DB / ORM | Prisma + SQLite |
| Internationalization | next-intl |
| Logger | Pino |
| Validation | Zod |

## Included Files

```
templates/nextjs/
├── README.md                 # This file
├── submodule-setup.sh        # ai-dev-os submodule setup script
├── CLAUDE.md.template        # CLAUDE.md template
├── .claude/
│   └── skills/
│       ├── commit/
│       │   └── SKILL.md      # Commit skill
│       ├── guideline-checker/
│       │   └── SKILL.md      # Guideline checker
│       └── type-check/
│           └── SKILL.md      # Type check & lint
├── tsconfig.json             # TypeScript config (strict: true)
├── eslint.config.mjs         # ESLint config
├── prettier.config.js        # Prettier config
├── postcss.config.mjs        # PostCSS (Tailwind) config
├── next.config.ts.template   # Next.js config template
├── .gitignore                # gitignore
└── package.json.template     # Base dependencies template
```

## Setup Instructions

```bash
# 1. Create a Next.js project
npx create-next-app@latest my-project --typescript --tailwind --eslint --app --src-dir
cd my-project

# 2. Set up ai-dev-os submodule
bash /path/to/ai-dev-os/templates/nextjs/submodule-setup.sh

# 3. Copy template files
# (submodule-setup.sh runs this automatically)

# 4. Install dependencies
npm install

# 5. Customize CLAUDE.md
# Edit the project name and project-specific guidelines
```
