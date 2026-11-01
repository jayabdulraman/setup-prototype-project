# Step 1 — Setup

Goal: a running Next.js app on `localhost` with every tool and its dependencies at the latest stable release, and a `PROTOTYPE.md` that tracks it.

`SKILL` below means this skill's folder (for example `~/.agents/skills/setup-prototype-project`). On Windows, run every command here in Git Bash (see Platforms in `SKILL.md`). If Git isn't installed yet, Git Bash doesn't exist yet: install Git from PowerShell first (section 3), then switch.

You run every command. The person only picks the folder, approves the few things listed under "Ask first" in `SKILL.md`, and types a password if an installer asks for one.

## 1. Pick the folder

Ask: "Where should the project live, and what should we call it?" Default: `~/prototypes/<kebab-name>`. If the person names a folder (including Dropbox, OneDrive, iCloud or Google Drive), use it.

- If the folder already has a `PROTOTYPE.md`, this is a resume. Read it, run the upgrade-and-check pass from `SKILL.md`, and continue at the first unchecked step.
- If the folder exists with other files, ask whether to build inside it or in a new subfolder.

## 2. Preflight

```bash
bash SKILL/scripts/preflight.sh <target-dir>
```

It prints one line per check: `OK`, `MISSING`, `OUTDATED` (older than the latest stable), `WARN`, `INFO`, plus the Node.js version the latest Next.js requires. Show the person a short table: what they have, what you'll install or upgrade.

If preflight can't reach the internet for the latest versions, check them yourself (`npm view <pkg> version`, the vendor's release page) rather than assuming.

If git has no name or email, ask the person what to use, then set them yourself: `git config --global user.name "..."` and `git config --global user.email "..."`.

## 3. Install and upgrade, in dependency order

No approval needed for these (except tools from a third-party tap, below): announce the list in one line ("Installing Node.js, the Vercel CLI and the Supabase CLI, and upgrading GitHub's CLI") and go. Tools depend on each other, so work top to bottom and skip what preflight marked `OK`.

| # | Tool | Needed by | macOS | Windows | Linux |
|---|---|---|---|---|---|
| 1 | OS build tools | Homebrew, git | `xcode-select --install` (opens an installer the person clicks through) | not needed | `build-essential` / distro equivalent (needs sudo password) |
| 2 | Package manager | installing the CLIs below | Homebrew: official one-line installer from brew.sh (asks for the person's password) | winget: built into Windows 10/11. Scoop (for Supabase): `irm get.scoop.sh \| iex` in PowerShell, no admin | Homebrew on Linux (optional) |
| 3 | git | scaffolding, commits, GitHub | comes with step 1 | `winget install -e --id Git.Git` (also installs Git Bash) | distro package |
| 4 | Node.js LTS (includes npm, npx) | Next.js, shadcn, Vercel CLI, Playwright | `brew install node` | `winget install -e --id OpenJS.NodeJS.LTS` | `nvm install --lts` (install nvm first) |
| 5 | Vercel CLI | deploys, env sync | `npm i -g vercel@latest` | same | same |
| 6 | Supabase CLI | later database upgrade | `brew install supabase/tap/supabase` | `scoop bucket add supabase https://github.com/supabase/scoop-bucket.git` then `scoop install supabase` | `brew install supabase/tap/supabase` |
| 7 | GitHub CLI | code backup, auto-deploys | `brew install gh` | `winget install -e --id GitHub.cli` | brew or distro package |
| 8 | jq | `discover.sh`, piping keys from CLIs | `brew install jq` | `winget install -e --id jqlang.jq` | distro package |

Upgrading outdated tools uses the same managers: `brew upgrade <formula>`, `winget upgrade -e --id <id>`, `scoop update <app>`, `npm i -g <cli>@latest`, `nvm install --lts --reinstall-packages-from=current && nvm alias default 'lts/*'`.

Notes:

- **Steps that need the person's password** (Homebrew installer, Linux sudo, some winget installs): run them in a terminal the person can see, as described in `SKILL.md` → "You run every command". Tell them a password prompt is coming and that typing shows no characters.
- **Tools from a third-party Homebrew tap** (the Supabase CLI comes from `supabase/tap`): ask before trusting the tap and before each upgrade from it during setup, even if it was approved before. If `brew upgrade supabase` refuses because the tap isn't trusted, ask: "Homebrew only updates tools from sources you've trusted. Supabase publishes its CLI from its own source, so to keep it up to date I'll mark `supabase/tap` as trusted and upgrade it. OK?" On yes, run `brew trust supabase/tap && brew upgrade supabase`. On no, keep the current version and note it.
- **Node.js under nvm**: global npm CLIs are installed per Node version, so pass `--reinstall-packages-from=current` when upgrading. Agent shells may keep the old Node on the PATH; start commands with `source ~/.nvm/nvm.sh && nvm use default`.
- **Node.js version**: must meet the latest Next.js requirement preflight printed. Don't keep two separate Node installs (e.g. Homebrew and nvm).
- **Fresh shell after installing** git, Node, or a package manager on Windows: reopen Git Bash (or the agent session) so new commands are on the PATH.

Install **globally first**; if that fails, fall back to **project level** and record which one was used in `PROTOTYPE.md`:

| Tool | Project fallback (run later with `npx <tool>`) |
|---|---|
| Vercel CLI | `npm i -D vercel@latest` |
| Supabase CLI | `npm i -D supabase@latest` |
| GitHub CLI | Skip; it's optional |
| Node.js, git | No fallback: run the official installer from nodejs.org / git-scm.com in a visible terminal or window, then restart the shell |

Global fails when: `EACCES` / permission denied, no package manager, or a managed machine blocks installs. Never run `sudo` silently yourself; if a step truly needs it, run it where the person can see and type their password.

## 4. Scaffold the app (shadcn preset)

From the parent folder (create it first, e.g. `mkdir -p ~/prototypes && cd ~/prototypes`):

```bash
npx shadcn@latest init --preset b1oVxsfY --template next --pointer --name <name> --yes
```

This one command creates `<name>/` with Next.js (App Router, TypeScript), Tailwind CSS, Base UI components, the neutral color theme, Lucide icons and the **Sera** style (a structure close to ASU's design system), plus a git repo with a first commit, `AGENTS.md`, `CLAUDE.md`, `components.json` and a `typecheck` script. If the person gives a different preset code (from ui.shadcn.com/create), use theirs instead of `b1oVxsfY`.

The preset layout has **no `src/` folder**: code lives in `app/`, `components/`, `lib/`, `hooks/`, and `@/*` points to the project root. All paths below follow that layout; if a project does have `src/`, put the same files under `src/`.

If the preset command fails (network, registry outage), retry once, then fall back to:

```bash
npx create-next-app@latest <name> --ts --tailwind --eslint --app --import-alias "@/*" --use-npm --yes --no-agent-feedback
cd <name> && npx shadcn@latest init --defaults --yes
```

and note in `PROTOTYPE.md` that the preset wasn't applied.

**In a Dropbox folder**, right after scaffolding:

```bash
bash SKILL/scripts/ignore-sync.sh "<project>"
```

## 5. Add the project packages and upgrade everything

Run inside the project:

```bash
# Starter UI components (button comes with the preset)
npx shadcn@latest add card input label textarea dialog sonner badge --yes

# Browser database and input validation
npm i dexie@latest dexie-react-hooks@latest zod@latest

# Testing
npm i -D @playwright/test@latest
npx playwright install chromium        # Linux: add --with-deps (needs the person's sudo password)

# Bring every package the scaffold pinned up to its latest stable release
npm outdated --json | jq -r 'keys[] + "@latest"' | xargs npm i
```

Then run `npm run lint && npm run typecheck && npm run build`. If anything fails after the upgrade, follow the downgrade rule in `SKILL.md` (find the one package that broke it, drop it to the newest release of its previous major, re-run) and record it under Decisions.

If npm warns that a package's install script was blocked (`npm install-scripts ls`), leave it blocked unless something fails because of it; then approve only that package (`npm install-scripts approve <pkg>`) and note it.

Copy templates (adjust the app name inside each):

| Template | Destination |
|---|---|
| `templates/db.ts` | `lib/db.ts` |
| `templates/actions.ts` | `app/actions.ts` |
| `templates/playwright.config.ts` | `playwright.config.ts` |
| `templates/smoke.spec.ts` | `tests/smoke.spec.ts` |
| `templates/PROTOTYPE.md` | `PROTOTYPE.md` |
| `templates/AGENTS.section.md` | Append to the end of `AGENTS.md`, outside the `nextjs-agent-rules` markers |

If `CLAUDE.md` is missing, create it with the single line `@AGENTS.md`.

Add any of these scripts to `package.json` that aren't there yet:

```json
"typecheck": "tsc --noEmit",
"test:e2e": "playwright test",
"check": "npm run lint && npm run typecheck && npm run build && npm run test:e2e"
```

Render `<Toaster />` from `@/components/ui/sonner` inside `<body>` in `app/layout.tsx`.

Confirm `.gitignore` contains `.env*` and `.vercel`. Add `test-results/` and `playwright-report/`.

## 6. First look

```bash
cd "<project>" && npm run dev   # run in the background; it keeps running
```

Open `http://localhost:3000` (use your browser tool if you have one, otherwise give the person the link). Run `npm run test:e2e`. Commit: `git add -A && git commit -m "Set up prototype"`.

Fill the tools table in `PROTOTYPE.md` with each tool, its installed version (`<tool> --version`, or `npm ls <pkg> --depth=0`), and `global` or `project`. Record any downgrades under Decisions. Check off Step 1.

Recap to the person: "The app is set up and running at localhost:3000, with every tool on its latest version. Next we sign in to the tools once so they can work for you."

## If something fails

| Symptom | Fix |
|---|---|
| `command not found` right after installing | Open a new shell (Windows: reopen Git Bash) so the PATH refreshes; under nvm, `source ~/.nvm/nvm.sh && nvm use default` |
| Scaffold says the folder isn't empty | Build in a new subfolder, or move stray files after asking |
| `ui.shadcn.com` unreachable | Retry; then use the create-next-app fallback in section 4 and plain Tailwind; note it in `PROTOTYPE.md` |
| Lint fails right after upgrading | Usually a major release the linter doesn't support yet (e.g. TypeScript 7 with typescript-eslint). Downgrade that one package a major |
| `playwright install` fails to download | Continue; Step 5 can use the agent's browser tool instead. Note it |
| Port 3000 busy | `npm run dev -- -p 3001` |
| Turbopack panic: "node process exited before we could connect to it" | The machine or agent sandbox blocks Turbopack's helper process. Use webpack: set `"dev": "next dev --webpack"` and `"build": "next build --webpack"` in `package.json`. The preset already wires Tailwind through PostCSS; a create-next-app project also needs `npm i -D @tailwindcss/postcss@latest` and a `postcss.config.mjs` with `export default { plugins: { "@tailwindcss/postcss": {} } };` |
| Windows: scripts fail with `\r` or "bad interpreter" errors | Line endings were converted. Run `git config --global core.autocrlf input` and reinstall the skill |
