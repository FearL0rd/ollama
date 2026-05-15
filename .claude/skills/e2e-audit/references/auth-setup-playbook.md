# auth-setup-playbook (e2e-audit 0.2.0)

> How to obtain and reuse authenticated browser state, per auth provider. Goal: one `storageState.json` per role × per audit session, produced exactly once.

## Principles

1. **Never read `.env*`** inside this skill. If credentials are needed, ask the user inline. State files live under `$SESSION_DIR/auth/` and are gitignored (caller's responsibility).
2. **Reuse before synthesize.** If `existing-tests.storage_states` contains files, use them. Check freshness: any file older than 7 days is considered stale; regenerate.
3. **One role per file.** `owner.json`, `admin.json`, `member.json` — do not collapse roles.
4. **State files contain secrets.** They must not enter `findings.json`, `map.md`, or any output that ships to the user beyond the session dir.

## Playwright baseline

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'authed',
      dependencies: ['setup'],
      use: {
        ...devices['Desktop Chrome'],
        storageState: '.e2e-audit/current/auth/owner.json',
      },
    },
  ],
});
```

## Per-provider recipes

### next-auth / Auth.js (credentials provider)

```ts
// tests/e2e/auth.setup.ts
import { test as setup } from '@playwright/test';
setup('authenticate owner', async ({ page }) => {
  await page.goto('/signin');
  await page.getByLabel('Email').fill(process.env.E2E_OWNER_EMAIL!);
  await page.getByLabel('Password').fill(process.env.E2E_OWNER_PASSWORD!);
  await page.getByRole('button', { name: /sign in/i }).click();
  await page.waitForURL(/\/(dashboard|home)/);
  await page.context().storageState({ path: '.e2e-audit/current/auth/owner.json' });
});
```

### Clerk

Use Clerk's `@clerk/testing` helper. It writes a session via `setupClerkTestingToken()` and then calls `storageState`.

### better-auth / Lucia

Same pattern as next-auth: drive the login form, then persist storage state. Both libraries store a session cookie which storageState captures.

### Supabase (JWT)

After login, `localStorage` holds the session. `storageState` serializes localStorage so no extra work is needed. If the dev project uses PKCE, ensure the setup runs in a chromium context.

### Custom (cookie-session / JWT header)

If the app does not have a login form (API-only auth), seed storage via `page.context().addCookies([...])` using a short-lived token the user pastes in. Never store long-lived tokens in `auth/*.json`.

## RBAC coverage

For every role declared in `stack.auth`:

1. Drive one happy-path login per role.
2. For each `trpc_procedures[]` with `auth == "protected"`, attempt the call with a role that should be forbidden. Expect 401 or 403. If 200, emit an `rbac-bypass` finding.

## Global teardown

Do NOT teardown or delete storageState files at the end of a run — the skill keeps them inside `$SESSION_DIR`, which is the audit's own sandbox.
