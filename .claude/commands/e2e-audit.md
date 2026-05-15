---
description: Run e2e-audit (source-first integration-test audit + coverage-gap detection)
---

Invoke the e2e-audit skill with flags: $ARGUMENTS

Follow SKILL.md entry flow:
1. Preflight — detect stack, inventory existing tests, hash for drift
2. Source-first discovery — routes + api-surface + uncovered (branch diff)
3. Report-then-ask — show map, STOP for user confirmation
4. Dev server + Playwright run — capture SHOT+TRACE+ASSERT+SOURCE
5. Post-run feedback — API errors, RBAC, console, server crashes
6. Write findings.json + run verify-audit.sh
7. Return ≤5-sentence summary

Do not paste the full map into chat.
