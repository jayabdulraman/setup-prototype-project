---
name: setup-prototype-project
description: Use when someone wants to turn an idea into a working, shareable web app prototype; set up a new Next.js prototype project in a folder; log in to or connect the CLIs a prototype needs; deploy a prototype to a live link; or add a feature to an existing prototype that needs a new tool, service, API key, CLI, or skill. Triggers include "prototype this", "build me an app", "turn this idea into something I can share", "set up my project", "ship it", "deploy this", "add payments/email/AI/login to my prototype". Works on macOS, Windows and Linux. Suited to non-technical builders.
---

# Setup Prototype Project

Build a working web app from an idea, then share it as a live link. The person gives **direction and judgment**; you do **the technical work**.

## The stack

| Layer | Default tool |
|---|---|
| Interface (what people see and click) | Next.js (App Router) + TypeScript + Tailwind + shadcn/ui (Base UI, neutral theme, Lucide icons, Sera style) from one shadcn preset |
| Server work (secret keys, outside APIs, AI calls) | Next.js Server Actions |
| Data | IndexedDB in the browser (Dexie). Supabase CLI installed for later |
| Hosting and sharing | Vercel |
| Setup and automation | Official CLIs (`vercel`, `supabase`, `gh`, `shadcn`) + this skill's scripts |

IndexedDB comes first: no account, no keys, works offline. Move to Supabase only when data must be shared between people or devices, the app needs login, or a server/scheduled job must read the data (see `references/7-extend.md`).

## Always the latest stable release (no need to ask)

- Upgrades never need approval, with one exception: tools that come from a **third-party Homebrew tap** (e.g. `supabase/tap`). Ask before trusting such a tap and before each upgrade from it during setup, even if it was approved before.
- Otherwise, bring every CLI and package to its latest **stable** release: `npm i -g <cli>@latest`, `brew upgrade`, `winget upgrade`, Node.js current LTS, and in the project `npm outdated --json | jq -r 'keys[] + "@latest"' | xargs npm i`. Say what you upgraded in one line.
- Never use canary, beta, rc, or `next` tags unless the person asks. Don't pin versions from memory or from these docs.
- After upgrading, run the checks (`lint`, `typecheck`, `build`). If one fails, read the error to find the package that broke it, downgrade **only that package** to the newest release of its previous major (`npm i -D <pkg>@^<major-1>`), and re-run. Record the pin and why in `PROTOTYPE.md` Decisions. Example: TypeScript 7 broke ESLint's TypeScript plugin, so pin `typescript@^6` and keep everything else latest.
- When resuming an existing prototype, do the same upgrade-and-check pass before new work.

## The build, step by step

Read the step's reference file when you reach it. Do not read them all up front.

| Step | Person does | You do | Reference |
|---|---|---|---|
| 1. Setup | Picks a folder | Check tools and their dependencies, install what's missing, scaffold the app | `references/1-setup.md` |
| 2. Connect | Approves, signs in once in the browser | Run each CLI login, confirm it worked, store app keys in the OS credential store | `references/2-connect.md` |
| 3. Spec | Shapes the idea | Ask short rounds of questions, write `SPEC.md` | `references/3-spec.md` |
| 4. Build | Reacts, redirects | Build one feature at a time, show it running | `references/4-build.md` |
| 5. Test | Tries it | Run checks, test in a real browser, fix | `references/5-test.md` |
| 6. Ship | Approves, shares | Sync keys to Vercel, deploy, hand over the link | `references/6-ship.md` |
| Any time | Asks for a new capability | Find the tool's CLI or skill, ask to install, connect it | `references/7-extend.md` |

Result: a working app on `localhost`, then a live link anyone can open.

## Platforms

| | macOS | Windows | Linux |
|---|---|---|---|
| Shell for this skill's scripts | Terminal (zsh/bash) | **Git Bash** (comes with Git for Windows) | bash |
| Package manager for CLIs | Homebrew | winget (Scoop for Supabase) | Homebrew on Linux, or npm |
| Where app keys live | Keychain | Credential Manager | Secret Service (`secret-tool`); otherwise a git-ignored `.env.local` |

- Run scripts with `bash <absolute path>`. On Windows from PowerShell or cmd, plain `bash` may start WSL instead; use `& "$env:ProgramFiles\Git\bin\bash.exe" <script>`. Claude Code on Windows already runs its shell in Git Bash.
- WSL counts as Linux, but `secrets.sh` uses the Windows Credential Manager through `powershell.exe` when it's reachable.
- Cloud-synced folders (Dropbox, OneDrive, iCloud, Google Drive) are fine. In a Dropbox folder, run `bash SKILL/scripts/ignore-sync.sh <project>` right after scaffolding so Dropbox skips `node_modules`, `.next` and test output.

## Progress file

Every prototype has a `PROTOTYPE.md` at its root (template: `templates/PROTOTYPE.md`). It holds the step checklist, the tools list (tool, version, global or project install), key **names** (never values), decisions, and links.

- Update it at the end of each step and whenever a tool is added.
- When invoked inside an existing prototype, read `PROTOTYPE.md` first and resume at the first unchecked step. If the person names a step ("let's ship"), go there, but run that step's checks first.
- All steps checked and the person wants something new: add it to `SPEC.md` (must-haves + acceptance checks) and to Features in `PROTOTYPE.md`, run `references/7-extend.md` if it needs a new tool, then loop Build → Test → Ship for that feature.

## You run every command

The person gives direction and approvals; **you run every command yourself**. Never ask them to type or paste a command.

- **No approval needed:** looking things up; upgrades (see above); installing the default stack and its dependencies once the person asked for a prototype. Announce what you're installing and why in one line, then do it.
- **Ask first** (explain why in one plain sentence, then run it yourself on yes; one yes can cover a listed batch):
  - signing in to a CLI
  - changing a security setting, e.g. trusting a Homebrew tap (`brew trust supabase/tap`), and upgrading a tool from a third-party tap
  - installing a tool beyond the default stack (`references/7-extend.md`)
  - creating cloud resources (Vercel project, Supabase project, GitHub repo, marketplace integration)
  - deploying to production
  - locking the spec and moving from Spec to Build
- If the person's request already says to go all the way ("take it to a live link"), that is the approval for the Vercel project and production deploy. Still say what you're about to do, one line, before doing it.

When a command needs the person to interact (a browser sign-in, a verification code, an admin password):

1. Explain what will happen and what they'll see.
2. Run it where they can see and answer it: your agent app's terminal panel (a "run in terminal" tool) if you have one. Give **each sign-in its own new tab named for it** ("Vercel sign-in", "GitHub sign-in"); never reuse a tab named for something else. Bring the terminal panel into view on that tab (a "show pane" tool) and link the tab in your message. Without a panel, otherwise open a terminal window for them (macOS: `osascript -e 'tell application "Terminal" to do script "cd <project> && <command>"'`; Windows: `start "" "%ProgramFiles%\Git\git-bash.exe" -c "<command>; read"`).
3. Wait for them to say "done", then **verify it yourself** (`vercel whoami`, `gh auth status`, ...). Never mark a step done on their word alone.

Secrets (API keys, tokens), in this order:

1. **Automatic first**: a Vercel Marketplace integration (keys land on Vercel, then `secrets.sh pull-vercel`), or a provider CLI whose key output you pipe straight into `secrets.sh set NAME --stdin`. The person never sees or pastes a key.
2. **Dialog last**: only when the service offers neither, run `bash SKILL/scripts/secrets.sh ask NAME "where to find it"`. It opens a hidden-input dialog on the person's screen and stores the value in the OS credential store; nothing passes through chat or your output. Tell the person first that a dialog will appear and why.
 **Never ask for a secret in chat, never print one, never write one into code or a committed file.**

Your shell's working directory may reset between calls: start every project command with `cd "<project>" &&`. Long-running commands (`npm run dev`) go in the background.

## How to talk to the person

- Before each action, one plain sentence on what it does for them: "Adding a browser database so your list saves between visits."
- After each step, a 2–3 line recap: what now works, what they can try, what comes next.
- When there is a real choice, give 2–3 options and a recommendation. Otherwise pick a sensible default and say what you picked.
- Show, don't describe: open `localhost` (or a screenshot) after every visible change.
- Errors: fix them yourself first. Only bring the person in when you need a decision, an approval, or their hands for a sign-in, password, or key.

## Bundled files

- `scripts/preflight.sh [dir]` — tools, dependencies, installed vs latest versions, logins, folder checks
- `scripts/secrets.sh` — OS credential storage (`ask` opens a hidden-input dialog), run-with-keys, `.env.local` export, Vercel push/pull (`help` for usage)
- `scripts/ignore-sync.sh <project>` — tells Dropbox not to sync `node_modules`, `.next` and test output
- `scripts/wincred.ps1` — Windows Credential Manager helper used by `secrets.sh` (don't call directly)
- `scripts/discover.sh <tool>` — first-pass lookup for a new tool's CLI, npm package, and skills
- `scripts/install.sh` — installs this skill globally (falls back to project level)
- `templates/` — `PROTOTYPE.md`, `SPEC.md`, `AGENTS.section.md`, `db.ts`, `actions.ts`, `smoke.spec.ts`, `playwright.config.ts`

`SKILL` in these docs means this skill's folder, e.g. `~/.agents/skills/setup-prototype-project`. Expand it to the absolute path when you run a script: `bash ~/.agents/skills/setup-prototype-project/scripts/preflight.sh`.

## Common mistakes

| Mistake | Instead |
|---|---|
| Asking the person to run or paste a command | Explain, get a yes, run it yourself (visible terminal for sign-ins). |
| Marking a login done because the person said so | Verify with the CLI (`vercel whoami`, `gh auth status`, `supabase projects list`). |
| Letting Dropbox sync `node_modules` | Run `ignore-sync.sh` right after scaffolding. |
| Installing a CLI before what it depends on | Follow the install order in `1-setup.md` (package manager → git → Node.js → npm CLIs). |
| Installing from memory (`npm i next@15`) | Use `@latest` stable; downgrade one package only if a check fails. |
| Reaching for Supabase on day one | Start on IndexedDB; upgrade when sharing or login is a must-have. |
| Calling IndexedDB from a Server Component or Server Action | IndexedDB exists only in the browser. Use it in `"use client"` components. |
| Putting an API key in a `NEXT_PUBLIC_` variable | Anything `NEXT_PUBLIC_` ships to every visitor. Keep keys server-side in Server Actions. |
| Building every feature before showing anything | One feature at a time, shown running, then react. |
| Deploying without syncing keys | Run `secrets.sh diff-vercel` before every deploy. |
| Scheduling a job that reads IndexedDB | Server jobs can't see browser data. Move the data to Supabase first (`7-extend.md`). |
| Handing over a link without opening it logged-out | Check the production URL returns 200 publicly before sharing (`6-ship.md`). |
| Installing a tool from a search result without checking who publishes it | Prefer the vendor's official CLI, package, or skill. Show the publisher when asking. |
