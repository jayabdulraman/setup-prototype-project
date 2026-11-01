# {{App name}} — prototype progress

> One-line idea: {{what it does, for whom}}
> Folder: `{{absolute path}}` · Started: {{YYYY-MM-DD}}

## Steps

- [ ] 1. Setup — tools installed, app scaffolded, runs on localhost
- [ ] 2. Connect — logged in to the CLIs we need, app keys in the OS credential store
- [ ] 3. Spec — `SPEC.md` locked
- [ ] 4. Build — every must-have works on localhost
- [ ] 5. Test — checks pass, tried in the browser, tried by the owner
- [ ] 6. Ship — live link shared

## Tools

| Layer | Tool | Kind | Version | Installed | Keys (names only) |
|---|---|---|---|---|---|
| Interface | Next.js + TypeScript + Tailwind | framework | | project | |
| Interface | shadcn/ui | CLI + components | | project (npx) | |
| Server work | Next.js Server Actions | framework | | project | |
| Data | Dexie (IndexedDB) | library | | project | |
| Data (later) | Supabase CLI | CLI | | global / project | |
| Hosting | Vercel CLI | CLI | | global / project | |
| Testing | Playwright | library | | project | |
| Runtime | Node.js LTS | runtime | | global | |

## Keys

Values live in the OS credential store (macOS Keychain / Windows Credential Manager / Linux Secret Service, entry `prototype:{{project}}:<NAME>`), never in this repo.

| Name | Used for | Local | Vercel |
|---|---|---|---|

## Features

- [ ] {{Feature 1 from SPEC.md}}

## Decisions

| Date | Decision | Why |
|---|---|---|

## Links

- Local: http://localhost:3000
- Preview:
- Live:
- Repo:
