# coverage-gap-playbook (e2e-audit 0.2.0)

> How to translate `uncovered.json` into actionable meta findings + spec suggestions.

## Input

`detect-uncovered.sh` produces four uncovered arrays:

- `uncovered_routes` — user-facing pages the branch changed with no test referencing their URL.
- `uncovered_http` — REST handlers the branch changed with no test referencing their path.
- `uncovered_trpc` — tRPC procedures the branch changed with no test referencing their name.
- `uncovered_actions` — server actions the branch changed with no test referencing their name.

## One finding per category

Emit at most four meta findings:

```json
{
  "id": "E2E-00XX",
  "rule": "coverage-gap-routes",
  "category": "coverage-gap",
  "severity": "medium",
  "summary": "N routes changed on branch without E2E coverage",
  "detail": "<bulleted list of paths + files>",
  "files_affected": ["<every file from the uncovered entries>"],
  "suggested_fix": { "kind": "add-test", "files": ["tests/e2e/<slug>.spec.ts"] }
}
```

Severities:

- `coverage-gap-trpc`    — `medium` (contract risk)
- `coverage-gap-http`    — `medium` (contract risk)
- `coverage-gap-routes`  — `low` if diff is cosmetic, `medium` otherwise
- `coverage-gap-actions` — `medium`

## Spec suggestions per surface type

**Page (route)**

```ts
test('GET /users/[id] renders user dashboard', async ({ authenticatedPage }) => {
  const res = await authenticatedPage.goto('/users/1');
  await expect(res!.status()).toBeLessThan(400);
  await expect(authenticatedPage.getByRole('heading')).toBeVisible();
});
```

**HTTP route handler**

```ts
test('POST /api/users creates user (200)', async ({ request }) => {
  const res = await request.post('/api/users', { data: { email: 'u@test', name: 't' } });
  expect(res.status()).toBe(200);
  expect((await res.json()).id).toBeTruthy();
});
```

**tRPC procedure**

```ts
test('users.create rejects invalid input (400)', async ({ request }) => {
  const res = await request.post('/api/trpc/users.create?batch=1', {
    data: { 0: { json: { email: 'not-an-email' } } },
  });
  expect(res.status()).toBeGreaterThanOrEqual(400);
});
```

**Server action**

```ts
test('createUser action returns redirect', async ({ page }) => {
  await page.goto('/users/new');
  await page.getByLabel('Email').fill('u@test');
  await page.getByRole('button', { name: /create/i }).click();
  await page.waitForURL(/\/users\/\d+/);
});
```

## What to NOT flag

- Unchanged surfaces. If a file is not in `uncovered.diff_files`, it did not change on this branch — no finding, even if tests are missing. Coverage auditing of the whole app is out-of-scope for branch-diff mode.
- `loading.tsx`, `error.tsx`, `layout.tsx` in Next.js — these are treated separately. A coverage gap finding should not fire for them; they are covered transitively by any page that renders through them.

## suggested_fix files

For each uncovered entry, suggest a plausible spec filename:

- `/users/[id]` → `tests/e2e/users-id.spec.ts`
- `POST /api/users` → `tests/e2e/api-users.spec.ts`
- `users.create` → `tests/e2e/trpc-users.spec.ts`

Do not CREATE the files. This skill stops at reporting.
