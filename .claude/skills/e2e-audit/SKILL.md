---
name: e2e-audit
version: 0.2.0
description: Comprehensive E2E audit that maps all routes, APIs, tRPC procedures, middleware auth, and forms from SOURCE first, cross-references against existing tests and the current branch diff, runs Playwright against dev, then reports coverage gaps and problems with a SHOT+TRACE+ASSERT+SOURCE evidence quad. Invoke when the user mentions "e2e audit", "run the e2e", "integration test audit", "test coverage gaps", "roda o e2e", end-to-end tests, API contract check, RBAC coverage, or auditing integration tests. Report-then-ask: stop after mapping, run only on confirmation, emit a post-run-feedback report before writing findings.
---

# e2e-audit — source-first integration-test audit

> **Operating principle:** you cannot audit what you never opened. Playwright traffic logs only cover flows you already know. Read the source first, then drive the browser to close the gaps the source revealed.

## Entry contract (non-negotiable)

1. **Mapping before clicking.** Run discovery scripts, write all JSON inventories, then STOP and report. Do NOT spin up the browser before the user confirms scope.
2. **Existing tests are load-bearing.** If `tests/e2e/` (or equivalent) exists, inventory it FIRST. Reuse fixtures, auth storage state, and page objects. Warn on drift between runs.
3. **Evidence quad.** Every non-meta finding ships SHOT+TRACE+ASSERT+SOURCE — screenshot path, Playwright trace path, literal assertion string, and implicated source file. Coverage gaps (`rule=coverage-gap-*` / `uncovered-*`) are the only exceptions.
4. **Dev, not prod.** Always audit against the local dev server. Detect HTML-instead-of-JSON crashes (500 responses that render the Next/Remix error page) and surface them.
5. **Report-then-ask → run → feedback → findings.** Four gates, in order. Do not merge them.

## Output layout

```
.e2e-audit/<YYYY-MM-DD-HHMMSS>/
├── stack.json               # detect-stack.sh
├── routes.json              # discover-routes.sh
├── api-surface.json         # discover-api-surface.sh
├── existing-tests.json      # inventory-existing-tests.sh
├── uncovered.json           # detect-uncovered.sh
├── map.md                   # human-readable summary of the above
├── traces/                  # Playwright trace.zip per test
├── screenshots/             # PNGs per assertion moment
├── logs/
│   ├── dev-server.log       # piped stdout+stderr of dev server
│   └── playwright.log
├── post-run-feedback.json   # emitted AFTER runs, BEFORE findings
├── post-run-feedback.md     # human copy
└── findings.json            # final — schema at findings.schema.json
```

## Pipeline

```
PREFLIGHT        →  detect-stack, inventory-existing-tests, compute drift-hash
DISCOVERY        →  discover-routes, discover-api-surface, detect-uncovered
REPORT-THEN-ASK  →  write map.md, present to user, WAIT for confirmation
RUN              →  start dev server, tail logs, drive Playwright
FEEDBACK         →  post-run-feedback.json from logs + trace + console
FINDINGS         →  findings.json with SHOT+TRACE+ASSERT+SOURCE quad
VERIFY           →  bash scripts/verify-audit.sh <session_dir>
```

---

## Step 1 — Preflight

```bash
SESSION_DIR=".e2e-audit/$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$SESSION_DIR/traces" "$SESSION_DIR/screenshots" "$SESSION_DIR/logs"

bash .claude/skills/e2e-audit/scripts/detect-stack.sh            > "$SESSION_DIR/stack.json"
bash .claude/skills/e2e-audit/scripts/inventory-existing-tests.sh > "$SESSION_DIR/existing-tests.json"
```

**Drift check.** If a previous session exists at `.e2e-audit/.last-hash`, compare `existing-tests.json.hash` against it. On mismatch, surface a `test-drift` meta finding (non-fatal) showing which files were added, removed, or resized. Write the new hash after the run completes.

**Stack fallback.** If `stack.test_runner == "none"`, emit a `meta` finding prompting the user to install Playwright (`bun add -D @playwright/test`) and stop the pipeline. Do not proceed blind.

## Step 2 — Source-first discovery

```bash
bash .claude/skills/e2e-audit/scripts/discover-routes.sh       > "$SESSION_DIR/routes.json"
bash .claude/skills/e2e-audit/scripts/discover-api-surface.sh  > "$SESSION_DIR/api-surface.json"
bash .claude/skills/e2e-audit/scripts/detect-uncovered.sh \
  "$SESSION_DIR/routes.json" \
  "$SESSION_DIR/api-surface.json" \
  "$SESSION_DIR/existing-tests.json" \
  "${BASE_REF:-origin/main}" > "$SESSION_DIR/uncovered.json"
```

Then write `map.md` summarising:

- **Stack**: framework + router style + test runner + auth providers + ORMs.
- **Surface counts**: routes, HTTP handlers, tRPC procedures (by auth tier), server actions.
- **Branch diff**: files changed vs `BASE_REF`; highlight those without test references.
- **Uncovered**: bulleted list of every item in `uncovered_routes / uncovered_http / uncovered_trpc / uncovered_actions`.
- **Existing test inventory**: count + hash + drift status.

## Step 3 — Report-then-ask (HARD STOP)

Present `map.md` to the user with a short prompt:

> Mapping complete. Found N routes, M uncovered surfaces, K existing specs. Scope to run:
>  - (a) uncovered + changed (default, recommended)
>  - (b) full suite (all existing specs + uncovered surfaces)
>  - (c) custom subset (user lists paths)
> Reply with a/b/c before I touch the browser.

Do NOT proceed to Step 4 without a reply. This is the mandatory report-then-ask gate.

## Step 4 — Run against dev

1. **Start dev server in background**, redirect stdout+stderr to `$SESSION_DIR/logs/dev-server.log`:
   ```bash
   nohup sh -c "$(jq -r .dev_command "$SESSION_DIR/stack.json")" \
     > "$SESSION_DIR/logs/dev-server.log" 2>&1 &
   echo $! > "$SESSION_DIR/logs/dev.pid"
   ```
2. **Wait** for `$(jq -r .base_url stack.json)` to respond 200 within 90s. Fail loud if not.
3. **Auth setup**: if `stack.auth` is non-empty, use/create `storageState` per role. Start from any existing state in `existing-tests.storage_states`; only synthesize new states via explicit user-provided credentials (never read env files and print them). See `references/auth-setup-playbook.md`.
4. **Spec selection** per Step 3 answer. Prefer existing specs when coverage exists.
5. **Run Playwright** with tracing forced on:
   ```bash
   npx playwright test \
     --trace=on \
     --output="$SESSION_DIR/traces" \
     --reporter=list,json \
     2>&1 | tee "$SESSION_DIR/logs/playwright.log"
   ```

Capture for each test:

- Screenshot at the key assertion step (`await page.screenshot({path, fullPage: true})`).
- Trace zip (auto when `--trace=on`).
- All `page.on('console')` messages with level + URL + line.
- All responses via `page.on('response')`: filter 4xx/5xx on `/api/` `/v1/` `/trpc/` paths.
- HTML-instead-of-JSON: any response where `Content-Type: text/html` hits an API path → `server-crash` rule.

## Step 5 — Post-run feedback

BEFORE writing `findings.json`, consolidate into `post-run-feedback.json`:

```jsonc
{
  "session": "<session_dir>",
  "duration_s": 128,
  "tests_total": 42,
  "tests_failed": 3,
  "problems": [
    { "kind": "api-5xx",         "where": "POST /api/users", "count": 2, "sample_trace": "traces/users-create-1.zip" },
    { "kind": "console-error",   "where": "dashboard",       "count": 7, "sample": "Uncaught TypeError: Cannot read ..." },
    { "kind": "rbac-bypass",     "where": "member sees /admin", "count": 1 },
    { "kind": "server-crash",    "where": "POST /api/x returned text/html 500" },
    { "kind": "auth-flow-broken","where": "login redirect loop after valid credentials" },
    { "kind": "dev-server-log",  "where": "unhandledRejection at server:1234" }
  ],
  "uncovered_carried_forward": { "routes": 4, "http": 2, "trpc": 9, "actions": 1 }
}
```

Also mirror to `post-run-feedback.md`. Present a short summary to the user; do not dump the full JSON.

## Step 6 — Write findings

For every problem in `post-run-feedback.problems` that is tied to a specific failure, emit one finding. Allocate IDs `E2E-0001`, `E2E-0002`, … sequentially.

- Evidence quad required (`screenshot_path`, `trace_path`, `assertion`, `source_file`).
- `source_file` must point at the route handler / procedure / action / middleware implicated — not the spec file.
- Add `http.method`, `http.path`, `http.status`, `http.response_snippet` for api-contract + server-crash findings.

Meta findings (no evidence quad required):

- `coverage-gap-routes` / `coverage-gap-http` / `coverage-gap-trpc` / `coverage-gap-actions` — one per non-empty `uncovered.*` array, with the array echoed into `detail`.
- `test-drift` — emitted by Step 1 when the test-corpus hash changed since last run.
- `stack-detect` — info-level snapshot of `stack.json` for traceability.
- `post-run-feedback` — aggregate, links to `post-run-feedback.json`.

Schema: `.claude/skills/e2e-audit/findings.schema.json`. Validate with `jq --slurpfile schema findings.schema.json` or skip strict validation and lean on `verify-audit.sh`.

## Step 7 — Verify + persist

```bash
bash .claude/skills/e2e-audit/scripts/verify-audit.sh "$SESSION_DIR"
jq -r '.hash' "$SESSION_DIR/existing-tests.json" > .e2e-audit/.last-hash
```

Kill the dev server: `kill "$(cat "$SESSION_DIR/logs/dev.pid")"`.

## Final response to user

≤5 sentences. Report: session dir, # findings, # coverage gaps, # problems, and one-line guidance on whether to invoke a fix agent or hand-fix. Do NOT paste `map.md` or `findings.json` bodies.

---

## Invocation triggers (already enforced by SessionStart hook)

Keywords that MUST trigger this skill: `e2e audit`, `roda o e2e`, `run the e2e`, `integration test audit`, `test coverage gaps`, `coverage gap`, `audit my tests`, `api contract check`, `rbac coverage`, `end-to-end tests`. Claude must read this file before improvising a plan.

## Boundaries (what this skill does NOT do)

- Does not write fixes. Fix work is out of scope; hand the finding list to a sd-fix-style agent or the user.
- Does not audit design / UX — that's `super-design`. If the user asked for a UX audit, hand off.
- Does not run against production. Only local dev. If `stack.base_url` points to prod, refuse.
- Does not invent credentials. Never read `.env*` files; only use credentials the user provides inline for the session.
- Does not delete existing tests. Drift is reported, never "resolved" by removing specs.

## References

- `references/auth-setup-playbook.md` — storageState + role patterns per auth provider.
- `references/api-contract-playbook.md` — HTTP-4xx / HTTP-5xx / HTML-instead-of-JSON detection.
- `references/coverage-gap-playbook.md` — how to translate `uncovered.*` into meta findings + suggested specs.
- `references/post-run-feedback-playbook.md` — how to consolidate Playwright run signals into feedback.

## Templates

- `templates/base-fixture.ts.tpl` — `test.extend` with `apiErrors` + `authenticatedPage` fixtures.
- `templates/auth-setup.ts.tpl` — globalSetup shape that writes storageState per role.
- `templates/findings-report.md.tpl` — human-readable summary rendered from findings.json.
- `templates/post-run-feedback.md.tpl` — the mirror of post-run-feedback.json.

## Attention points

- **tRPC v10 vs v11.** Procedure nesting works differently; `createCaller()` exists in both but the router introspection APIs diverge. Treat `discover-api-surface.sh` output as names-only.
- **Route groups.** Next `(marketing)` style segments are stripped in URL computation; don't emit findings that name the parenthesis.
- **Parallel & intercepting routes.** `@modal` slots and `(.)photo` shortcuts are surfaces that Playwright can miss; the route discovery already flags them — propose specs that hit them directly.
- **Middleware.** If `middleware.has_auth_guard == true` and a public matcher exists, any public URL the audit hit should not have triggered auth redirects. Mismatches = findings.
- **Windows paths.** `.claude/skills/e2e-audit/scripts/*.sh` must run via Git Bash or WSL. If `bash` isn't available, abort with a meta finding; never fall back to half-runs.
- **Dev server crashes mid-run.** If `dev.pid` exits unexpectedly during Playwright execution, mark all remaining tests as inconclusive and emit `server-crash` findings with the last 40 lines of `dev-server.log` in `detail`.
