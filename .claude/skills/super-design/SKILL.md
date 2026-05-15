---
name: super-design
description: >
  Performs end-to-end design audits on web projects. MUST BE USED when the user
  mentions super-design, design audit, UX review, accessibility review, design
  critique, competitor analysis, WCAG, Core Web Vitals, usability audit, or asks
  to evaluate their website's design quality. Produces market analysis, live-site
  UX audit (WCAG 2.2 AA, Nielsen heuristics, Baymard, CWV), and synthesized
  overview. Re-audits only what changed since last run. On explicit user request,
  applies surgical fixes with full rollback.
version: 0.7.0
---

# super-design

## What this skill does

Four-phase pipeline with 6 specialist agents:

1. **Market research** (sd-research) — auto-detects niche from repo, finds 5–10
   competitors, extracts design language AND component vocabulary (buttons,
   nav, cards, modals, forms, tokens — per competitor × mobile+desktop),
   produces market-analysis.md + component-comparison.md.
2. **UI/UX audit** (sd-audit) — drives browser via Playwright MCP directly.
   Six layers:
   - Route discovery + static snap (Nielsen + WCAG 2.2 AA + Baymard + CWV)
   - **Step 1.5 source-first discovery** (0.7.0+) —
     `discover-surfaces.sh` reads the repo FIRST and emits an authoritative
     inventory of modals, forms, triggers, internal nav, and Next.js
     layout/error/loading/not-found/parallel/intercepting routes BEFORE
     Playwright runs. `extract-project-rules.sh` parses FORBIDDEN tables
     from CLAUDE.md / AGENTS.md / .cursorrules into audit-applicable
     rules. Runtime cross-checks surface these as `modal-coverage-gap`,
     `form-coverage-gap`, and `project-forbidden-<slug>` findings.
   - **Step 2.5 component/modal/flow discovery** (Phase A inventory, B modal
     enumeration, C flow exercising, D state matrix, E form coverage) — this
     is where modal contents, empty/loading/error states, and flow errors
     get real evidence instead of "checklist hypothetical". Phase B now
     cross-references `surfaces.json` and files a `modal-coverage-gap`
     finding for anything declared in source but never opened.
   - **Step 3g design-intelligence scoring** (17-category rubric → DIS 0–100)
     catches implicit best practices checklists miss (cards-in-flex-col,
     low density, weak CTA hierarchy, vibecode smell). Emits MANDATORY
     `design-intelligence-craft-summary` finding per page × viewport so
     overview.md has one holistic verdict row ("admin mobile is 38/100
     WEAK — holistic redesign scope") per combination, not just discrete
     per-category findings.
   - **Step 3h mobile-native audit** (21-item Duolingo/Linear/Arc/Cash-App
     checklist) — replaces "responsive-web-on-a-phone" thinking.
   - **Step 3i project-rule enforcement** (0.7.0+) — consumes
     `project-rules.json` and fires primary findings keyed to the
     project's own FORBIDDEN wording (e.g. `project-forbidden-use-cards-on-mobile`)
     when the rule is violated at runtime. Not a tag, not a severity
     bump — the project owner's rule IS the rule source.
   - C16 ≤ 4 → **DSC-choice** proposal: sd-synthesis runs
     `scripts/score-typeui.mjs --from-audit <dir>` to derive a 7-axis site
     fingerprint (density/contrast/geometry/color/typography/motion/audience)
     and rank all installed typeui-* skills by fit 0-1. Top-3 are written to
     `typeui-proposal.json` + shown in overview.md with a copy-paste CLI.
   Produces findings.json + design-intelligence.json with SHOT+QUOTE+SEL+VAL.
3. **Synthesis** (sd-synthesis) — unifies research + audit + design-intelligence
   into overview.md (per-page DIS table + executive summary + typeui proposal
   when craft ≤ 4).
4. **Fix** (sd-fix + two-stage verify) — optional. Applies safe fixes with
   technical gates (types/lint/tests) AND semantic verification ("does this
   fix actually resolve the finding, or just mask it?"). Template families:
   A1-A15 a11y · V1-V8 design · U1-U10 ux · P1-P10 perf · **M1-M15 mobile**
   (cards-in-flex-col → compact list, table-on-mobile → card-per-row,
   centered-modal → bottom-sheet, etc.) · **DSC-1 design-skill advisory**
   (proposes typeui-* direction). With `--typeui <name>` flag, sd-fix loads
   the chosen typeui skill (tokens: primary, radius, spacing scale,
   typography) and rebrands V1-V8 fixes so every spacing/color/radius target
   snaps to that direction's scale — turning advisory into applied. After each
   successful fix, re-drives Playwright to capture an after-screenshot (full
   page + element crop) and emits `docs/super-design/sessions/<id>/fix-report.md`:
   a self-contained visual diff with before/after images, file diffs,
   verification status, and commit SHA per finding.

## Entry flow

### Step 1: Preflight

```bash
STATE=docs/super-design/.audit-state.json
if [[ ! -f "$STATE" ]]; then MODE=first-audit
elif ! bash .claude/skills/super-design/scripts/validate-state.sh; then MODE=first-audit
else MODE=incremental-candidate
fi
```

### Step 2: Scope decision (if incremental)

Apply cascade from `references/change-detection-playbook.md` §4:
- Run `scripts/detect-changes.sh $LAST_SHA` → classify changed files.
- theory_doc_sha changed OR tokens changed OR major dep bump OR >180d old → FULL.
- Only components changed → re-audit pages importing them (N=3 hops via madge).
- Only routes added → audit those routes only.
- Only content changed → rerun a11y+content on affected pages.
- Nothing design-relevant → exit with note.

Record scope in overview.md changelog banner.

### Step 3: Dispatch (via Task tool)

```
1. sd-research    (skip if market-analysis.md <90d AND no dep/README change)
2. sd-audit       (only scoped pages — uses Playwright MCP directly)
3. sd-synthesis   (always; rebuilds overview.md)
4. sd-fix         (ONLY if user asked; uses verify-technical + verify-semantic)
```

Pass findings via files under `.super-design/sessions/<id>/`, not chat.

### Step 4: Write state + history

- Atomic write `.audit-state.json` via `scripts/write-state.sh` (takes JSON
  on stdin, writes `.tmp`, validates with `jq`, then renames). Do NOT write
  the state file directly.
- Append session to `audit-history.md`.
- `git notes --ref=super-design add -f -m <json> HEAD`.
- First-time notes setup (run once per clone, also in `setup-git-notes.sh`
  if you extract it): `git config --add remote.origin.fetch '+refs/notes/super-design/*:refs/notes/super-design/*'`
  — without this, notes don't round-trip across clones (artifact §7).

### Step 5: Return summary (≤5 sentences)

Do NOT paste overview into chat.

## User flags

- `--force-full` — ignore state, full audit
- `--refresh-research` — rerun sd-research
- `--only <cat>` — a11y | design | ux | perf | research
- `--scope <url>` — specific route
- `--app <name>` — scope the entire run to one monorepo app (matches a
  `name` entry from `scripts/detect-apps.sh`). Required when `--scope <url>`
  is ambiguous between multiple apps.
- `--fix` — run sd-fix after audit
- `--typeui <name>` — combine with `--fix` to apply fixes aligned to a
  chosen typeui direction (e.g. `--fix --typeui application`). Loads tokens
  from `~/.claude/skills/typeui-<name>/SKILL.md` and rebrands V1-V8 targets
  to that scale. Picked from the top-3 proposed in overview.md typeui
  block. Without this flag, DSC-1 stays advisory. Run
  `bash scripts/score-typeui.mjs --list` to see all installed directions.
- `--harvest-typeui` — run `scripts/harvest-typeui.sh` first to pull
  missing typeui-* and related design skills (typeui.sh registry with
  built-in catalog fallback). Idempotent; add `--refresh` to re-download.
- `--dry-run` — artifacts without committing state
- `--ci` — non-interactive, create PR, exit non-zero on blockers
- `--update-baselines` — Re-hash pages and tokens without re-auditing (use after accepted cosmetic drift). Also accepted by `scripts/visual-regression.sh` to overwrite `.super-design/baselines/*.png` with the current capture.
- `--visual-regression` — Run `scripts/visual-regression.sh` after hashing. Reads the `visual_regression` block from `.audit-state.json` (engine: pixelmatch | odiff | sha256-fallback; threshold 0.1; max_diff_pixel_ratio 0.01). See artifact §16.
- `MASK_SELECTORS=<sel,sel,...>` (env) — Extra CSS selectors masked in every screenshot captured by `scripts/hash-pages.sh`. Artifact §3.4 defaults (`[data-timestamp], .relative-time, [data-react-hydration], video, canvas`) are always applied.

## Monorepo support

Audit state is per-app (artifact §11 line 902) so independent deploys
carry independent freshness, `git_sha_at_audit`, and tool results. Layout
is auto-detected; nothing else to configure.

### Detection

`scripts/detect-apps.sh` reads the first workspace manifest it finds:

| Manifest | Source of globs |
|----------|-----------------|
| `pnpm-workspace.yaml` | `packages:` list |
| `package.json` | `workspaces: [...]` or `workspaces.packages: [...]` (npm, yarn, Bun) |
| `turbo.json` | Presence → uses pnpm/npm/yarn workspaces; falls back to `apps/*` + `packages/*` if none |
| `nx.json` | `workspaceLayout.appsDir` / `libsDir` (default `apps/*`, `libs/*`) |
| `bunfig.toml` | Presence → falls back to `apps/*` + `packages/*` if package.json has no workspaces |

Each matched directory that also has a `package.json` becomes an app
with `name` taken from `package.json#name` (scope stripped), `path` the
directory, and `state_path` = `<path>/docs/super-design/.audit-state.json`.
If nothing matches, `detect-apps.sh` emits a `single` layout with
`path: "."` and the repo-root state path — preserving existing single-app
behavior.

### Per-app pipeline

- **Preflight**: per app, read `<app>/docs/super-design/.audit-state.json`
  via `validate-state.sh <app_path>`.
- **Change detection**: `scripts/detect-changes.sh --all-apps` loops over
  every app and narrows `git diff` to `-- <app_path>/` so each app's
  scope decision sees only its own files. Single-app shape is preserved
  with `detect-changes.sh <last_sha>`.
- **Write state**: `scripts/write-state.sh <app_path>` derives the target
  path; for single-app repos pass `.` or omit.

### URL → app disambiguation

`--scope <url>` still targets one URL. When the URL maps cleanly to a
single app (e.g. `apps/admin` serves `https://admin.example.com`), the
pipeline picks that app automatically. When mapping is ambiguous
(multiple apps serve overlapping hostnames, or URL patterns cross apps),
the user MUST pass `--app <name>` — otherwise the skill aborts with a
`{"error":"ambiguous-app","candidates":[...]}` verdict instead of
guessing.

## Scripts

Reusable shell helpers under `scripts/`. All POSIX/bash, tested on
Windows git-bash + Linux.

- `discover-routes.sh` — emits `route_map` as a JSON array. Dynamic
  segments (`[slug]`, `[[...all]]`, `$id`, `:uid`) are suffixed with
  `@fixture-<id>` (artifact §2.7). Fixtures resolved from sibling
  `*.fixture.json`, `fixtures/<name>.json`, or `$SUPER_DESIGN_FIXTURES`
  env JSON; falls back to `@fixture-default` with a warning. Consumers
  (hash-pages, sd-audit) MUST strip the suffix before navigating.
- `discover-surfaces.sh` (0.7.0+) — source-first static scan for
  modals (`<Dialog|Sheet|Drawer|Modal|Popover|AlertDialog|DropdownMenu|CommandDialog|...>`),
  forms (`<form>` / `useForm(` / `<Form>`), triggers (`<*Trigger>`),
  internal navigation (`<Link href>` / `router.push`), and Next.js
  `layout.tsx` / `error.tsx` / `loading.tsx` / `not-found.tsx` / parallel
  routes (`@foo/`) / intercepting routes (`(.)foo/`). Emits
  `$SESSION_DIR/surfaces.json`. sd-audit Step 2.5 Phase B cross-checks
  runtime observations against this inventory and files
  `modal-coverage-gap` / `form-coverage-gap` findings for declared
  components never exercised.
- `extract-project-rules.sh` (0.7.0+) — parses FORBIDDEN tables from
  `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `.claude/CLAUDE.md` /
  `.cursorrules` into an authoritative rule source. Classifies each
  rule as audit-applicable (mobile / design / ux / perf / a11y) or
  code-level (skip — belongs to typecheck/lint). Emits
  `$SESSION_DIR/project-rules.json`. sd-audit Step 3i fires primary
  findings keyed to the project's own wording (e.g.
  `project-forbidden-use-cards-on-mobile`) — the project owner's rule
  IS the rule source, not a tag or severity bump.
- `build-import-graph.sh` — builds `.super-design/import-graph.json`
  (`{nodes, edges, hash, backend}`) and persists `import_graph_sha` to
  state. Prefers `npx madge --json <roots>`; falls back to a regex
  scanner (JS/TS only, no alias resolution) if madge is missing.
  - Query: `bash .../build-import-graph.sh importers <file> --hops 3`
    → BFS over reversed edges; `detect-changes.sh` uses this to close
    the component→pages gap when only components changed (Step 2 scope
    decision: "Only components changed → re-audit pages importing them
    (N=3 hops via madge)").
- `hash-pages.sh` — captures 3 viewports per URL (mobile_375, tablet_768,
  desktop_1280), emits `{html_hash, dom_structure_hash, viewport_hashes:
  {<vp>: {sha256, phash, png_path}}}` per page to
  `docs/super-design/.cache/hashes/hashes.json` and persists each PNG to
  `<cache>/screenshots/<url-enc>/<vp>.png`. Applies artifact §3.4 mask
  defaults plus `MASK_SELECTORS`; `phash` uses `sharp` when available
  (tagged `phash:`) or a deterministic PNG fingerprint otherwise
  (tagged `fpr:`, only useful for exact-match comparison).
- `visual-regression.sh [--update-baselines] [<state>]` — reads the
  `visual_regression` block from `.audit-state.json` and diffs current
  screenshots against `.super-design/baselines/`. Engine chain:
  `pixelmatch` → `odiff` → `sha256-fallback`. Emits
  `{page, viewport, diff_ratio, threshold, pass, diff_image_path}` to
  `<diff_dir>/results.json`. Exits non-zero if any page fails.

## References (Read on demand)

- `references/design-theory.md`
- `references/audit-methodology.md`
- `references/market-research-playbook.md`
- `references/change-detection-playbook.md`
- `references/fix-agent-playbook.md`
- `references/playwright-mcp-reference.md`
- `references/skills-subagents-reference.md`

## Hard rules

1. Every finding MUST cite SHOT+QUOTE+SEL+VAL.
2. Every fix MUST reference a finding ID in commit message.
3. Never auto-apply fixes above LOW risk without user approval.
4. Never edit outside configured source roots.
5. Never commit to main — all fixes on session branch.
6. Playwright MCP is the ONLY way to interact with live site.
7. Summary to user ≤5 sentences; report lives in overview.md.
8. Two-stage verify: technical gates (types/lint/tests) AND semantic ("does
   this actually resolve the finding?"). Both must pass.
