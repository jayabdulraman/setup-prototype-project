# Step 2 — Connect (sign in once)

Goal: each CLI is signed in to the person's account, verified by you, and any app keys live in the OS credential store (macOS Keychain, Windows Credential Manager, or Linux Secret Service), not in files.

You run every sign-in. The person approves it, then clicks through the browser page (and, for Supabase, types one verification code). You never see a password, token, or key.

## Who holds what

| Sign-in / secret | Where it's stored | How it gets there |
|---|---|---|
| Vercel | Vercel CLI's own auth file | You run `vercel login`; the person approves in the browser |
| GitHub | OS credential store (gh does this itself) | You run `gh auth login`; the person enters a one-time code in the browser |
| Supabase | OS credential store (the CLI does this itself) | You run `supabase login`; the person types the code the browser shows |
| App keys (OpenAI, Stripe, Resend, ...) | OS credential store, entry `prototype:<project>:<NAME>` | You run `secrets.sh ask NAME`; the person pastes the key into a hidden dialog |

## 1. Check who's signed in

`preflight.sh` already reported it. Re-check any time:

```bash
vercel whoami            # prints the username, or "Logged out"
gh auth status           # "Logged in to github.com account <name>"
supabase projects list   # a table if signed in; an error if not
```

## 2. Ask once, then sign in

Which ones:

- **Vercel: required** (Step 6 deploys with it).
- **GitHub:** recommended (code backup, auto-deploys); required if the person asked for GitHub.
- **Supabase:** optional while the app uses IndexedDB; sign in now if the person wants it ready.

Ask once for the batch, explaining why:

> "To let me deploy and back up your app for you, I need to sign in to Vercel and GitHub on your behalf. For each one, a browser page opens; you sign in and click Approve, and I'll confirm it worked. OK?"

## 3. Run each sign-in where the person can see it

Sign-ins wait for the browser and sometimes for typed input, so run them in a terminal the person can see (your app's terminal panel, or a terminal window you open for them; see `SKILL.md` → "You run every command"). One at a time, **each in its own new tab named for it** ("Vercel sign-in", "GitHub sign-in", "Supabase sign-in"), with the terminal panel brought into view on that tab. Tell them what to expect first, then read the tab's output and relay any link or code it shows:

| CLI | Command | What the person sees and does |
|---|---|---|
| Vercel | `vercel login` | The terminal shows a link and a short code, and a browser tab opens. Check the code matches, sign in (GitHub, Google, or email), click **Approve**. The terminal says it's logged in |
| GitHub | `gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key` | First asks "Authenticate Git with your GitHub credentials? (Y/n)": click into the tab and press Enter (Yes). Then it shows a one-time code like `ABCD-1234`; press Enter, sign in to GitHub, paste the code, click **Authorize** |
| Supabase | `supabase login` | The terminal says "Press Enter to open browser". Click into the tab and press Enter, sign in and approve; the page shows an 8-character **verification code**. Type it into the tab and press Enter |

If a prompt asks a yes/no question (e.g. gh: "Authenticate Git with your GitHub credentials?"), tell the person the recommended answer (Yes).

After the person says "done", **verify it yourself** with the check commands in section 1. Report the account name back ("Signed in to Vercel as `jdoe`"). Only then mark it in `PROTOTYPE.md`.

### If a sign-in "didn't register"

The person finished in the browser but the check still says logged out:

- **Was it the same CLI?** Under nvm, each Node version has its own global `vercel`. Run the check with the same binary you used to log in (`which -a vercel`), after `source ~/.nvm/nvm.sh && nvm use default`.
- **Did the terminal command finish?** Closing the window, or a timeout, before the browser approval lands means nothing is saved. Run it again and keep the terminal open until it prints success.
- **Email-code flows**: `vercel login <email>` uses an emailed code; the code must be typed into the same running terminal. Prefer plain `vercel login` (browser approval).
- **Network**: `curl -sI https://vercel.com` (or the provider's site) must succeed from your shell; proxies and sandboxes can block it.

Then run the sign-in again.

## 4. App keys (only when a feature needs one)

Most prototypes need none at first. When a feature needs a key, get it **automatically first**; the paste dialog is the last resort.

1. **Vercel Marketplace integration** (if the provider has one): `vercel integration add <name>` provisions the account and puts the keys on Vercel; then `secrets.sh pull-vercel` copies them into the local credential store. See `7-extend.md`.
2. **Provider CLI**: if the provider's CLI can print the key, pipe it straight into storage (example below). Nothing shows on screen.
3. **Dialog, last resort**: only if neither exists. Tell the person which key, why, and where to get it (the provider's dashboard page), say a small window will appear, then run:

   ```bash
   cd "<project>" && bash SKILL/scripts/secrets.sh ask OPENAI_API_KEY "Create a key at platform.openai.com/api-keys and paste it here"
   ```

   A window with a hidden field opens on the person's screen (macOS dialog, Windows credential prompt, or zenity/kdialog on Linux). They paste and click Save. If no dialog can be shown, the command says so; then run `secrets.sh set NAME` in a visible terminal instead.
Confirm any of these with `bash SKILL/scripts/secrets.sh list` (names only).

Provider CLI example (option 2):

```bash
# See which keys exist (names only)
supabase projects api-keys --project-ref <ref> -o json | jq -r '.[].name'

# Pipe the one you need straight into the credential store
supabase projects api-keys --project-ref <ref> -o json \
  | jq -r '.[] | select(.name=="<key-name>") | .api_key' \
  | bash SKILL/scripts/secrets.sh set NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY --stdin
```

The publishable (anon) key is meant for the browser. The secret (service role) key is server-only: never give it a `NEXT_PUBLIC_` name.

## 5. Using keys locally

Start the dev server with keys loaded from the credential store (nothing is written to disk):

```bash
bash SKILL/scripts/secrets.sh run -- npm run dev
```

If a tool insists on a file, `secrets.sh write-env` writes a git-ignored `.env.local` with owner-only permissions. Prefer `run`.

`secrets.sh` picks the store for the OS automatically. On Linux without a Secret Service (common on servers and in WSL without Windows access), it falls back to a git-ignored, owner-only `.env.local` and says so.

Record each signed-in account and key **names** in `PROTOTYPE.md`. Check off Step 2 once every needed sign-in is verified.
