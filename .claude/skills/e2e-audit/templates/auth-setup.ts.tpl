// {{SESSION_DIR}}/auth.setup.ts — one storageState per role
// Run once via Playwright `projects[{ name: 'setup', testMatch: /.*\.setup\.ts/ }]`.
// NEVER reads .env* directly; credentials come from process.env set at invoke time.
import { test as setup } from '@playwright/test';

const ROLES = ['owner', 'admin', 'member'] as const;

for (const role of ROLES) {
  setup(`authenticate ${role}`, async ({ page }) => {
    const email    = process.env[`E2E_${role.toUpperCase()}_EMAIL`];
    const password = process.env[`E2E_${role.toUpperCase()}_PASSWORD`];
    if (!email || !password) {
      setup.skip(true, `missing E2E_${role.toUpperCase()}_EMAIL / _PASSWORD`);
      return;
    }
    await page.goto('/signin');
    await page.getByLabel(/email/i).fill(email);
    await page.getByLabel(/password/i).fill(password);
    await page.getByRole('button', { name: /sign in|log in|continue/i }).click();
    // Adjust the wait URL to your post-login destination.
    await page.waitForURL(/\/(dashboard|home|app|overview)/, { timeout: 30_000 });
    await page.context().storageState({ path: `.e2e-audit/current/auth/${role}.json` });
  });
}
