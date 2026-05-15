## {{session_date}} · `{{session_id}}` · branch `{{branch}}`

**Counts:** Applied {{applied}} · Proposed {{proposed}} · Skipped {{skipped}} · Failed {{failed}}
**Base:** `{{base_sha}}` · **Tip:** `{{tip_sha}}`
**Visual report:** [`sessions/{{session_id}}/fix-report.md`](./sessions/{{session_id}}/fix-report.md) — before/after screenshots per finding

### Applied
| Finding | Category | Files | Commit | Before/After |
|---|---|---|---|---|
{{applied_table}}

### Proposed (awaiting approval)
| Finding | Category | Files | Patch | Before |
|---|---|---|---|---|
{{proposed_table}}

### Skipped (HIGH risk — tracked as issues)
| Finding | Issue | Reason |
|---|---|---|
{{skipped_table}}

### Failed (rolled back)
| Finding | Gate | Reason | Before |
|---|---|---|---|
{{failed_table}}

---
