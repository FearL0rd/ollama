# Fix agent playbook — PLACEHOLDER

> **This file is a placeholder.** The complete content was delivered as a
> message in the conversation ("fix-agent playbook for super-design"),
> approximately 80KB of markdown. Paste it here.

## What the content covers

### §1 Safe edit patterns in Claude Code
- Edit vs MultiEdit vs Write vs NotebookEdit decision tree
- Patch-style edits vs full-file rewrites
- Minimizing blast radius (smallest possible scope)
- Preservation rules (indent, quotes, semicolons, comments, import order)
- Never delete code without justification

### §2 Propose-before-apply vs apply-directly strategies
- PROPOSE mode: generate diff, wait for approval
- APPLY mode: apply directly, trust but verify
- HYBRID (recommended): propose for risky, apply for trivial
- permissionMode mapping: default / acceptEdits / plan / dontAsk / bypassPermissions

### §3 Diff preview patterns
- Unified diffs via `git diff --unified=3`
- Rendering in chat with fenced diff block
- Before/after screenshots via Playwright
- Granularity: per-finding / per-file / per-PR
- /rewind + Esc Esc checkpoint integration

### §4 Rollback and recovery
- git stash before every fix session
- Session branch: `fix/sd-<timestamp>`
- Commit-per-fix with structured message (Aider pattern)
- Automatic rollback on test failure
- Claude Code native undo integration

### §5 Confirmation scoping
- Adaptive algorithm: per-finding / per-file / per-category / per-session
- Smart defaults by permissionMode × risk level
- Selective filtering ("Apply all fixes in /components/ui/ only")

### §6 Minimizing blast radius rules (8)
1. Single-file edits preferred
2. Scope style changes to smallest surface
3. Additive > subtractive
4. Never change component's public API
5. Don't mix formatting with substantive fixes
6. Don't touch files outside finding.files_affected
7. Document every touched file in commit body
8. Refuse to edit protected paths

### §7 Fix categories and templates
- A1-A15 accessibility templates
- V1-V8 design templates
- U1-U10 UX templates
- P1-P10 performance templates

Per template: HOW (exact code), RISK (trivial/low/medium/high), VERIFICATION
(how to confirm), PRECONDITIONS (what must be true).

### §8 Framework-aware fixes
Framework detection cascade. Per-framework attribute translation table
(React/Vue/Svelte 5/Svelte 4/Astro/HTML).

Tailwind-aware class merging via cn()/clsx/tailwind-merge/cva.

### §9 Fix agent architecture
One orchestrator + specialists vs unified agent trade-offs.
Findings input contract (JSON schema).
Output contract (fix-results.json statuses: applied / proposed / skipped / failed / needs_human).
Resume-from-failure patterns.

### §10 Interaction with user
Session opening summary format.
Batch-by-risk proposal language.
Append-only audit log at docs/super-design/fix-history.md.
CI mode flags (--dry-run, --ci, --only, --max-risk, --resume).

### §11 Verification after fix (the two-stage pattern)
Four-gate technical verification:
1. Detector replay (category-specific)
2. Type check (tsc --noEmit / vue-tsc / svelte-check)
3. Lint (eslint --max-warnings 0)
4. Tests (npm test --findRelatedTests)

PLUS semantic verification (sd-fix-verify-semantic):
- Does the fix ACTUALLY resolve the finding, not just pass gates?
- Template-specific 5-question checklist

### §12 Risk classification rubric
- TRIVIAL: single-attribute additions (alt, aria-label, lang)
- LOW: single CSS prop change, 1-3 lines JSX
- MEDIUM: component-structure changes, cross-file coordinated changes, token changes
- HIGH: dependency changes, config changes (tailwind.config, tsconfig), architectural changes

Default behavior map by level (auto-apply / propose / require approval / gh issue).

### §13 GitHub issues/PRs for complex fixes
gh issue create template with finding + WCAG refs + suggested approach + files.
gh pr create template with before/after + test plan + reviewer checklist.

### §14 Concrete agent markdown (ready-to-paste)
Full sd-fix.md content.

### §15 Testing fix agents
Seed repo with known issues.
Run audit → produce findings.
Run fix agent.
Verify issues resolved + no regressions.
Golden-file tests.

## Where super-design uses this

- **sd-fix** applies templates from §7 inline
- **sd-fix-verify-technical** implements §11 four-gate verification
- **sd-fix-verify-semantic** implements the semantic-verification layer of §11
- **Risk classification** everywhere uses §12 rubric
- **scripts/guard-paths.py** enforces §6 rule 8
- **scripts/post-edit-lint.py** enforces §11 gate 3
