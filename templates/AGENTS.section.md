
## Prototype rules

This app was set up with the `setup-prototype-project` skill. Progress, tools, key names and decisions are in `PROTOTYPE.md`; what we're building is in `SPEC.md`. Read both before changing anything.

- **Stack:** Next.js App Router, TypeScript, Tailwind, shadcn/ui (`components/ui`, Sera style via preset), Dexie for IndexedDB, Server Actions for server work, Playwright for tests, Vercel for hosting.
- **Data:** all reads and writes go through `lib/db.ts`. IndexedDB runs only in the browser, so use it from `"use client"` code only.
- **Server work:** Server Actions in `actions.ts` files with `"use server"`; validate input with zod; return `{ ok, data | error }`.
- **Secrets:** read from `process.env` on the server. Never commit keys, never use `NEXT_PUBLIC_` for a secret. Keys live in the OS credential store (Keychain, Credential Manager, or Secret Service); run with `bash ~/.agents/skills/setup-prototype-project/scripts/secrets.sh run -- npm run dev`.
- **UI:** add shadcn components (`npx shadcn@latest add <name>`) before hand-building. Handle empty, loading and error states. Works at 375px wide.
- **Checks before saying done:** `npm run check` (lint, typecheck, build, Playwright).
- **Agent runs every command.** Upgrades to latest stable need no approval (downgrade one package if a check fails). **Ask first:** tools beyond the default stack, trusting or upgrading from a third-party Homebrew tap, creating cloud resources, production deploys. Sign-ins run in a visible terminal tab and are verified with the CLI.
