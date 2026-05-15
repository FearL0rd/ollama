# post-run-feedback-playbook (e2e-audit 0.2.0)

> How to consolidate every signal emitted during a Playwright run into one feedback document that precedes findings.json.

## Why a separate document?

Findings are atomic and per-problem; the user needs a 30-second summary of "what broke during this run" before drilling into specifics. `post-run-feedback.md` answers that. `findings.json` answers "what do I fix."

## Signals to consolidate

Pull from these inputs:

1. Playwright JSON reporter output (`--reporter=json`).
2. `$SESSION_DIR/logs/dev-server.log` (last-N-lines per crash).
3. Console + pageerror logs captured by fixtures.
4. Network responses matching 4xx/5xx on API paths.
5. Dev-server PID status at run end (exited unexpectedly?).

## Classification

| kind               | trigger                                                      | severity |
| ------------------ | ------------------------------------------------------------ | -------- |
| `api-4xx`          | unexpected 4xx on a test's expected-success request          | high     |
| `api-5xx`          | any 5xx response on API path                                 | critical |
| `server-crash`     | 5xx AND `Content-Type: text/html` on API path                | critical |
| `console-error`    | `page.on('console')` level=error, de-duped by message stem   | medium   |
| `pageerror`        | `page.on('pageerror')` raised                                | high     |
| `rbac-bypass`      | protected endpoint returned 200 to wrong role                | critical |
| `auth-flow-broken` | redirect loop or 401 on happy-path login                     | critical |
| `dev-server-log`   | unhandledRejection / uncaughtException in dev-server.log     | high     |
| `test-timeout`     | test exceeded Playwright timeout                             | medium   |
| `flake`            | retried test passed on retry (suggests flake)                | low      |

## Output shape

`post-run-feedback.json`:

```jsonc
{
  "session": "<abs path to session dir>",
  "duration_s": 128,
  "tests_total": 42,
  "tests_passed": 39,
  "tests_failed": 3,
  "tests_flaky": 1,
  "problems": [
    {
      "kind": "server-crash",
      "where": "POST /api/users",
      "count": 2,
      "severity": "critical",
      "sample_trace": "traces/users-create-1.zip",
      "sample_log_tail": "TypeError: Cannot read properties of undefined (reading 'id')\n    at ..."
    }
  ],
  "uncovered_carried_forward": {
    "routes": 4, "http": 2, "trpc": 9, "actions": 1
  }
}
```

`post-run-feedback.md` renders the same data as a human document with:

1. A one-line verdict ("3 tests failed, 2 critical problems, 16 uncovered surfaces — requires attention").
2. Top 5 problems by severity.
3. Link to the trace zip for each.
4. Next-step recommendations (add spec / fix handler / update RBAC middleware).

## De-duplication

- `console-error`: group by the first 120 chars of `text` (to collapse stack variation across retries).
- `api-4xx`/`api-5xx`: group by `(method, path, status)`.
- `pageerror`: group by the error message line.

## What NOT to include

- Full trace bytes — only file paths.
- Full stack traces for every occurrence — only a single `sample_log_tail` per group.
- Source code excerpts — that belongs in a finding's `source_quote`, not the feedback.
- Secret values (tokens, session cookies) — actively scrub any `Authorization:` header fragments out of `sample_log_tail`.
