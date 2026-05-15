# api-contract-playbook (e2e-audit 0.2.0)

> How to turn Playwright's network observations into contract findings.

## Observations to capture per test

Wire these fixtures once (see `templates/base-fixture.ts.tpl`):

- `page.on('response')` — filter by `url` prefix matching `/api/`, `/v1/`, `/trpc/`.
- `page.on('console')` — levels `error` and `warning`.
- `page.on('pageerror')` — unhandled runtime errors in the SPA.
- `request.response()` — for explicit `page.request` calls in specs.

## Detection rules

### HTTP 4xx on a flow that should succeed

- **Rule:** `api-4xx`
- **Severity:** `high` (user-blocking) or `medium` (inconsistent UX)
- **Signal:** response status in [400, 499] on a request the test expected to succeed.
- **Evidence:** trace zip + screenshot at the assertion moment + response snippet (first 400 chars) + source_file = the route handler or tRPC procedure file.

### HTTP 5xx anywhere

- **Rule:** `api-5xx`
- **Severity:** `critical`
- **Always fails the test.** Trace zip is mandatory; Playwright's trace viewer will show the request/response payloads.

### HTML-instead-of-JSON (server crash signal)

Next.js and most frameworks render an HTML error page when the server throws. Detection:

```ts
if (
  res.status() >= 500 &&
  (res.headers()['content-type'] || '').includes('text/html') &&
  /\/api\/|\/trpc\//.test(res.url())
) emit({ rule: 'server-crash', ... });
```

Surface the last ~40 lines of `dev-server.log` in `detail` so the user can see the stack trace without opening the trace.

### Zod validation gap

- **Rule:** `zod-validation-missing`
- **Severity:** `medium`
- **Signal:** `api-surface.http_routes[].zod_schema_found == false` AND the route accepts `POST`/`PUT`/`PATCH`.
- **Evidence:** SHOT is waived (meta-ish), but `source_file` is required.

### RBAC bypass

- **Rule:** `rbac-bypass`
- **Severity:** `critical`
- **Signal:** an endpoint tagged `auth: "protected"` in `api-surface.json` returned 200 for a role that should be rejected.
- **Evidence:** trace showing the call under the "wrong" storageState + source_file (the middleware or procedure).

## What NOT to flag as a contract problem

- 404 on a page navigation the user typed manually — that's a route-missing finding, not a contract one.
- 401 on an endpoint protected BEFORE login — that's expected behavior; only flag after valid login.
- Third-party hosts (analytics, stripe, intercom) — ignore by prefix match on `stack.base_url`.
- `/api/auth/*` during login form submit — transient 4xx (invalid-credentials) is expected; only flag if the happy-path login produced it.

## Sampling

To avoid flooding findings, de-dupe by `(method, path, status)` and keep the first occurrence's trace. Add `http.count` for repeats.
