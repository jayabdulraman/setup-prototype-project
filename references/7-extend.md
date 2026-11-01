# Any time — Extend (add a new tool)

Use this whenever a feature needs something the project doesn't have yet: a new service (AI, email, payments, maps, calendar, auth, analytics), a new CLI, an MCP server, or a skill. Also use it to move data from IndexedDB to Supabase.

## 1. Name the need

One sentence: "To send the reminder email, we need an email service." If there's a real choice of provider, give 2–3 options with a recommendation (free tier, setup effort, whether it has an official CLI or skill).

## 2. Discover what exists

```bash
bash SKILL/scripts/discover.sh <tool-or-vendor>
```

It checks: already installed locally, Homebrew formula (macOS/Linux), winget package (Windows), npm packages (the SDK and `@<vendor>/cli`), skills on skills.sh (via `npx skills find`, which downloads the small `skills` search CLI on first use), and Vercel Marketplace integrations. It only looks; it installs nothing. Network-dependent lookups may come back empty; that doesn't mean nothing exists.

Then confirm with the vendor's own docs (web search: `<vendor> official CLI`, `<vendor> agent skill`, `<vendor> MCP server`). What to look for, in order of preference:

| Kind | Why it helps | Example |
|---|---|---|
| Vercel Marketplace integration | Provisions the account and sets env vars on Vercel for you | `vercel integration add <name>` |
| Official CLI | You can create resources and fetch keys without the person clicking through dashboards | `stripe`, `supabase`, `gh` |
| Official agent skill | Teaches you the vendor's current APIs | `npx skills add <owner>/<repo>` |
| Official MCP server | Lets the agent query the service directly | the vendor's documented MCP URL |
| SDK only | Always needed for the code itself | `npm i <sdk>` |

Prefer things published by the vendor (their GitHub org, their npm scope, their Homebrew tap or winget publisher). Treat unknown third-party packages as a risk: say so.

Check the free tier's limits against the demo and mention any that bite. Example: email services often send only to the account owner's address until a domain is verified.

## 3. Ask (the approval card)

Present this, then wait for yes:

> **New tool: Email (Resend)**
> - Why: sends the reminder email in feature 3
> - Install: Resend SDK (`resend`, npm, by Resend) in the project; Resend skill (`resend/resend-skills`) globally
> - Connect: you'll create a free account and an API key; you'll store it in your computer's credential store with one command
> - Cost: free tier covers the prototype
>
> Install and connect?

## 4. Install (global first, project fallback)

| Kind | Global | Project fallback |
|---|---|---|
| CLI | `brew install <formula>` (macOS/Linux), `winget install -e --id <id>` or `scoop install <app>` (Windows), or `npm i -g <pkg>@latest` | `npm i -D <pkg>@latest`, run with `npx` |
| Skill | `npx skills add <owner/repo> -g -y` | `npx skills add <owner/repo> -y` (installs into the project's agent folders) |
| MCP server | Agent's user-level config (Claude Code: `claude mcp add --scope user ...`) | Project config (`claude mcp add --scope project ...`, writes `.mcp.json`) |
| Marketplace integration | `vercel integration add <name>` (needs a linked project) | n/a |
| SDK | n/a, always project | `npm i <sdk>@latest` |

Always install the latest stable release; never canary/beta unless asked. Fall back when global fails (permission denied, no package manager, blocked by policy). Never use `sudo` or an admin shell yourself. A newly installed skill or MCP server may need the agent session restarted to load; tell the person if so.

## 5. Connect

- CLI sign-in: as in `2-connect.md` (ask, run it where the person can see it, verify it yourself).
- Keys, automatic first: a Marketplace integration (`secrets.sh pull-vercel`) or the provider CLI piped into `secrets.sh set NAME --stdin`. Only if neither exists, `secrets.sh ask NAME "where to find it"` (hidden dialog). Prefer providers that support automatic keys when choosing between options.
- Marketplace integration: may open a browser for the person to accept the provider's terms. Keys land on Vercel; capture them locally with `secrets.sh pull-vercel`.
- Already deployed? Push new keys with `secrets.sh push-vercel NAME`.

## 6. Record

Add a row to the tools table in `PROTOTYPE.md` (tool, kind, version, global or project, key names). Note the choice under Decisions. If the feature isn't in `SPEC.md` yet, add it (must-have + acceptance checks) and to Features in `PROTOTYPE.md`. Then continue the feature in `4-build.md`.

## Scheduled jobs (reminders, weekly digests, cleanups)

A job that runs on a timer runs on the server, with no browser open, so it **cannot read IndexedDB**. If it needs the app's data, move the data to Supabase first (next section). It also needs to know who to contact (an email address saved with the user's data, or the owner's address in a key for a single-user demo).

Build it on Vercel Cron:

1. A Route Handler, e.g. `app/api/cron/weekly-digest/route.ts`, exporting `GET`. First line of work: reject the request unless `request.headers.get("authorization") === \`Bearer ${process.env.CRON_SECRET}\``.
2. A random secret: `node -e "process.stdout.write(require('crypto').randomBytes(32).toString('hex'))" | bash SKILL/scripts/secrets.sh set CRON_SECRET --stdin`, then `push-vercel CRON_SECRET`. Vercel sends it automatically with each cron call.
3. The schedule in `vercel.json` at the project root (times are UTC; convert from the person's timezone and say so):

   ```json
   { "crons": [{ "path": "/api/cron/weekly-digest", "schedule": "0 15 * * 1" }] }
   ```

4. Test locally by calling it yourself:

   ```bash
   cd "<project>" && bash SKILL/scripts/secrets.sh run -- sh -c 'curl -s -H "Authorization: Bearer $CRON_SECRET" http://localhost:3000/api/cron/weekly-digest'
   ```

Limits to tell the person: crons run only on the production deployment, and the free (Hobby) plan allows at most one run per day per job, at an approximate time within the hour.

## Moving data to Supabase

Upgrade when data must be shared between people or devices, login is a must-have, or a server/scheduled job needs the data. Otherwise stay on IndexedDB.

1. Ask: "To <reason>, we'll move storage to Supabase (free tier). OK?"
2. Create the database, one of:
   - **Via Vercel** (keys auto-sync): `vercel integration add supabase` (the person may need to accept terms in the browser), then `secrets.sh pull-vercel`.
   - **Via Supabase CLI**: you run `supabase orgs list` to get the org id and pick a region near the person (e.g. `us-west-1` for Arizona). Then, after the person approves creating the project, run this yourself. It generates a database password straight into the credential store so nobody has to see or type it:

     ```bash
     cd "<project>" && node -e "process.stdout.write(require('crypto').randomBytes(18).toString('hex'))" | bash SKILL/scripts/secrets.sh set SUPABASE_DB_PASSWORD --stdin && bash SKILL/scripts/secrets.sh run -- sh -c 'supabase projects create <name> --org-id <id> --region <region> --db-password "$SUPABASE_DB_PASSWORD"'
     ```

     Then pipe the API keys into the credential store as in `2-connect.md`.
3. `npm i @supabase/supabase-js@latest @supabase/ssr@latest`. If a Supabase skill is installed, load it for current client setup and Row Level Security guidance.
4. Write tables as migrations: `supabase init`, `supabase link --project-ref <ref>`, `supabase migration new <name>`, `supabase db push`. Enable Row Level Security on every table.
5. Re-implement the functions in `lib/db.ts` against Supabase with the same names and return types. Components shouldn't change.
6. Update the project's `AGENTS.md` "Prototype rules" (data now lives in Supabase; `db.ts` may be called from the server) and the Data row in `PROTOTYPE.md`.
7. Re-run Step 5, push keys (`push-vercel`), redeploy.
