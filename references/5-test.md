# Step 5 — Test (check it like a visitor would)

Goal: automated checks pass, the app works in a real browser at phone and desktop sizes, and the person has tried it themselves.

## 1. Automated checks

```bash
npm run lint
npm run typecheck
npm run build
npm run test:e2e
```

Or all at once: `npm run check`. Run with keys if any feature needs them: `bash SKILL/scripts/secrets.sh run -- npm run check`.

`tests/smoke.spec.ts` starts as "home page loads". For each must-have in `SPEC.md`, add one Playwright test that walks its acceptance checks (click, type, reload, expect). IndexedDB persists across reloads within a test, so "reload and it's still there" is testable.

Tests that hit a paid or rate-limited service: mock the Server Action's response in the test, or skip with a clear note.

## 2. Look at it

Use your browser tool if you have one; otherwise use Playwright screenshots (`await page.screenshot({ path: "shots/home.png", fullPage: true })`).

- Desktop and phone width (375px) for every screen.
- Walk each acceptance check by hand.
- Check the browser console for errors.
- Try the edges: empty input, a very long entry, double-clicking save, reloading mid-flow.

## 3. The person tries it

Give them a short checklist built from the acceptance checks:

> Open http://localhost:3000 and try:
> 1. Add a task, then reload. It should still be there.
> 2. ...
> Tell me anything that felt off, even small things.

Fix what they find, re-run step 1, commit. Check off Step 5 in `PROTOTYPE.md`.

## When a check fails

Read the error, find the cause, fix it, re-run. Don't skip or delete a failing test to get green; if a test is wrong, fix the test and say why. If stuck after two attempts on the same failure, tell the person what's failing and what you tried.
