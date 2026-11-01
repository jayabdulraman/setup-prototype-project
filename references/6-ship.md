# Step 6 — Ship (the live link)

Goal: a public URL anyone can open, with the same keys as local, recorded in `PROTOTYPE.md`.

## 1. Pre-flight

- Step 5 checks pass (`npm run check`).
- Everything committed (`git status` is clean).
- `vercel whoami` succeeds (if not, back to Step 2).

## 2. Link the project (first ship only)

Find where it will live: `vercel teams ls` lists the person's account and teams. If there is more than one, ask which; otherwise use the one listed. Then: "I'll create a Vercel project called `<name>` under `<team>`. OK?"

```bash
cd "<project>" && vercel link --yes --project <name> --scope <team-slug>
```

This writes `.vercel/` (already git-ignored).

## 3. Sync keys

Compare what the app has locally with what Vercel has:

```bash
bash SKILL/scripts/secrets.sh diff-vercel
```

**Transfer to Vercel** (local credential store → Vercel), for each missing key:

```bash
bash SKILL/scripts/secrets.sh push-vercel OPENAI_API_KEY            # production, preview, development
bash SKILL/scripts/secrets.sh push-vercel OPENAI_API_KEY production # one environment
```

Production and preview values are marked sensitive (write-only on Vercel). The source copy stays in the local credential store.

**Capture from Vercel** (Vercel → local credential store). Use this when a provider created keys on Vercel, for example after adding a Marketplace integration (Supabase, Upstash, Neon, ...):

```bash
bash SKILL/scripts/secrets.sh pull-vercel              # development values
bash SKILL/scripts/secrets.sh pull-vercel production   # production values
```

It imports each variable into the credential store and deletes the temporary file. Vercel system variables (`VERCEL_*`) are skipped. Sensitive variables can't be read back from Vercel; get those from the provider's dashboard.

## 4. Preview deploy

```bash
vercel deploy
```

The CLI prints a preview URL. Run the smoke test against it:

```bash
PLAYWRIGHT_BASE_URL=<preview-url> npx playwright test
```

Preview URLs may ask visitors to log in to Vercel (Deployment Protection). If so, the smoke test fails on the 200 check; that's expected for previews. Check the preview yourself in a logged-in browser instead, and rely on the production check below.

## 5. Production deploy (ask first)

"Preview works. Ready to publish the live link?" On yes:

```bash
vercel deploy --prod
```

Share the stable production address, `https://<project>.vercel.app` (shown as the alias in the deploy output or `vercel inspect <url>`), not the one-off deployment URL.

Prove it is public before handing it over:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://<project>.vercel.app   # must print 200
PLAYWRIGHT_BASE_URL=https://<project>.vercel.app npx playwright test
```

A 401 or a redirect to a login page means Deployment Protection covers production (common on organization teams). Tell the person, and offer: turn protection off for production in the Vercel project settings (Deployment Protection), or deploy under their personal account. Then walk the main journey once.

## 6. Hand it over

- Record the production URL, date, and commit in `PROTOTYPE.md`. Check off Step 6.
- Give the person the link and a one-line share message they can paste.
- Remind them: with IndexedDB, each visitor has their own data; use "Load sample data" for demos.

Optional follow-ups to offer:

- **Back up the code**: `gh repo create <name> --private --source . --push` (ask first).
- **Auto-deploy on every push**: `vercel git connect` after the GitHub repo exists.
- **Custom domain**: `vercel domains add <domain>`.

## Redeploying later

Run Step 5 checks, `secrets.sh diff-vercel`, then `vercel deploy --prod`. Ask before each production deploy.

## If something fails

| Symptom | Fix |
|---|---|
| Build fails on Vercel but not locally | `vercel inspect <url> --logs`; usually a missing env var. Run `diff-vercel` |
| A feature works locally, fails live | Key missing in that environment; `push-vercel NAME production`, redeploy |
| `push-vercel` fails only for preview | Older CLIs want a git branch for preview variables. Update the CLI (`npm i -g vercel@latest`). If it still asks, run `vercel env add NAME preview` in a terminal the person can see and press Enter at the branch prompt (all branches) |
| `vercel` hangs waiting for input | Add `--yes`; if it truly needs a choice, rerun it in a terminal the person can see and tell them which option to pick |
| CLI says it's outdated | `npm i -g vercel@latest` (or `npm i -D vercel@latest` if installed at project level) |
