# Step 4 — Build (one feature at a time)

Goal: every must-have feature in `SPEC.md` works on `localhost`, built in small slices the person reacts to.

## Before you write code

Read `AGENTS.md` in the project. Next.js changes fast; the Next.js block there points to version-matched docs in `node_modules/next/dist/docs/`. Check them before using an API you are unsure of.

## The loop (repeat per feature, in spec order)

1. Say which feature is next, in one sentence.
2. If it needs a new tool or key, run `7-extend.md` first.
3. Build the thinnest version that passes its acceptance checks. Data, UI, and server work together, so it runs end to end.
4. Run `npm run lint && npm run typecheck`. Fix errors yourself.
5. Show it running on `localhost` (open it, or share a screenshot) and ask: "Does this match what you pictured? Anything to change?"
6. Apply their feedback, commit (`git add -A && git commit -m "<feature>"`), check it off in `PROTOTYPE.md`.

Don't batch features. A visible slice every few minutes keeps the person in the driver's seat.

## Where things go

Paths follow the shadcn preset layout (no `src/`). If the project has a `src/` folder, the same paths live under it.

| Part | Location | Rule |
|---|---|---|
| Pages | `app/**/page.tsx` | Server Components by default |
| Interactive UI | `components/*.tsx` | Add `"use client"` only where there's state, effects, or browser APIs |
| UI parts | `components/ui/` | Add with `npx shadcn@latest add <name>` before hand-building. Don't edit generated files unless needed |
| Data | `lib/db.ts` | **All** reads and writes go through the functions exported here. Components never touch Dexie tables directly |
| Server work | `app/actions.ts` or `app/<route>/actions.ts` | `"use server"`. Validate input with zod. Read keys from `process.env` |

## Data: IndexedDB with Dexie

`templates/db.ts` shows the pattern: a typed Dexie database, a few repository functions, and a `useLiveQuery` hook for live-updating lists.

- On the first feature, replace the example `Item` model, `items` table and the `"prototype-app"` database name with the spec's real data (e.g. `StudySession`, `sessions`, `"study-buddy"`). Likewise replace `suggestNextStep` in `actions.ts`, or delete the file if nothing needs server work yet.
- IndexedDB lives in the visitor's browser. Use it only from client components or hooks, never from Server Components or Server Actions.
- Changing a table's shape: before the first deploy, edit `version(1)` freely (clear the browser's site data if it complains). After people have used the live link, add `db.version(2).stores({...})` instead, so their saved data upgrades.
- Each visitor to the live link gets their **own** data. Add a "Load sample data" button (and "Reset") so demos never start empty.
- Keeping all access in `db.ts` means a later move to Supabase replaces one file, not the app.

## Server work: Server Actions

Use a Server Action when the work needs a secret or an outside service: AI calls, sending email, payment sessions, third-party APIs. `templates/actions.ts` shows the shape: validate with zod, call the service, return a small result object (`{ ok: true, data }` or `{ ok: false, error }`). Don't throw raw errors to the UI.

The usual flow: a client component calls the action, gets the result, and saves it to IndexedDB through `db.ts`.

Keys: read from `process.env.NAME` on the server only. Never use a `NEXT_PUBLIC_` prefix for a secret. Run the dev server through `secrets.sh run -- npm run dev` so keys are present.

## UI quality bar

- Every screen handles empty, loading, and error states.
- Works at phone width (375px) and desktop.
- Use shadcn components and Tailwind tokens; keep a consistent spacing scale.
- If the person named a brand or a design-system skill is installed, apply it.
- Feedback for actions: a toast (`sonner`) on save, delete, and failure.
- Labels on every input, buttons that say what they do, visible focus states.

## Done when

All must-haves pass their acceptance checks on `localhost`, lint and typecheck are clean, and the work is committed. Check off Step 4 and move to Step 5.
