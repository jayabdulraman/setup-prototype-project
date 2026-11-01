# Step 3 — Spec (shape the idea)

Goal: a short `SPEC.md` the person approves. It is the build plan for Step 4 and the test plan for Step 5.

## How to run the conversation

- Rounds of **at most 3 questions**. Offer options with a recommendation so they can just pick.
- Use their words. Reflect back a one-line summary after each round.
- Push toward small: one person, one moment, one core journey. A prototype proves one thing.
- Stop asking once every section of the template can be filled. Fill gaps with sensible defaults and mark them "(assumed)".

Round 1 — the moment
1. Who is this for, and what moment are they in when they reach for it?
2. What do they do today instead, and what's annoying about it?
3. If the demo goes perfectly, what does the audience see happen?

Round 2 — the journey
1. Walk me through it: first screen, what they tap, what they get.
2. What must be saved, and should it still be there tomorrow?
3. Does anyone else need to see the same data? (If yes, flag Supabase for later. Still start on IndexedDB unless it's core to the demo.)

Round 3 — the edges
1. Does it need anything outside the app: AI, email, payments, maps, calendar, login? (Each one runs through `7-extend.md`.)
2. Look and feel: a brand or design system to follow? (If a design-system skill is installed, offer it.)
3. What's explicitly out for this version?

## Write the spec

Copy `templates/SPEC.md` to the project root and fill it. Keep it to about one page. Each must-have feature gets 1–3 acceptance checks a person can try in the browser ("Add a task, reload the page, the task is still there").

Optional: if the person wants to see it before building, sketch the main screens as a quick wireframe (a rendered diagram or a static page), not paragraphs.

## Lock it

Show the spec summary and ask: "Lock this spec and start building?" On yes, commit `SPEC.md`, check off Step 3 in `PROTOTYPE.md`, and list any new tools the spec needs (they run through `7-extend.md` before the feature that needs them).

Later changes are fine: edit `SPEC.md`, note the change under Decisions in `PROTOTYPE.md`.
