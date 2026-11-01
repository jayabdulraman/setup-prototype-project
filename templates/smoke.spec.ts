import { expect, test } from "@playwright/test";

test("home page loads without errors", async ({ page }) => {
  const errors: string[] = [];
  page.on("pageerror", (err) => errors.push(err.message));

  const res = await page.goto("/");
  // A protected or broken deployment returns 401/404/500, not the app.
  expect(res?.status()).toBe(200);
  await expect(page.locator("body")).toBeVisible();
  // Replace with something only your app shows, e.g. its main heading:
  // await expect(page.getByRole("heading", { name: "Study Buddy" })).toBeVisible();
  expect(errors).toEqual([]);
});

// One test per must-have in SPEC.md, walking its acceptance checks. Example:
//
// test("an added item survives a reload", async ({ page }) => {
//   await page.goto("/");
//   await page.getByLabel("New item").fill("Buy milk");
//   await page.getByRole("button", { name: "Add" }).click();
//   await page.reload();
//   await expect(page.getByText("Buy milk")).toBeVisible();
// });
