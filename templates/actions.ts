"use server";

// Server work: runs on the server, where secret keys are safe.
// Call these from client components, then save results with lib/db.ts.
import { z } from "zod";

export type ActionResult<T> = { ok: true; data: T } | { ok: false; error: string };

const SuggestInput = z.object({
  title: z.string().trim().min(1, "Write something first").max(200),
});

// Example: turn an item title into a suggested next step.
// Replace the body with a real service call (AI, email, payments, ...).
export async function suggestNextStep(
  input: z.input<typeof SuggestInput>,
): Promise<ActionResult<{ suggestion: string }>> {
  const parsed = SuggestInput.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: parsed.error.issues[0]?.message ?? "Invalid input" };
  }

  // Keys come from process.env on the server only. Locally, start the app with
  // `secrets.sh run -- npm run dev`; on Vercel, push them with `secrets.sh push-vercel`.
  // const apiKey = process.env.SOME_SERVICE_API_KEY;
  // if (!apiKey) return { ok: false, error: "SOME_SERVICE_API_KEY is not set" };

  try {
    return { ok: true, data: { suggestion: `Break "${parsed.data.title}" into one 10-minute task.` } };
  } catch (err) {
    console.error("suggestNextStep failed", err);
    return { ok: false, error: "Something went wrong. Try again." };
  }
}
