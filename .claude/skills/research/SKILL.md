---
name: research
version: 0.1.0
description: >
    Performs Baymard-Institute-grade research on any topic the user asks about
    (UX patterns, library evaluation, market analysis, academic literature, API
    integration, architectural decisions). MUST BE USED when the user mentions
    research, investigate, find info, search for, look up, pesquisar, pesquisa,
    pesquise, investigar, or asks to evaluate / compare / understand any
    technology, framework, vendor, methodology, or domain. Source-first
    pipeline: scout → query → synthesize → verify. Output goes to
    /docs/research/<topic>.md with URL+QUOTE+ACCESSED-AT+VERIFY-METHOD evidence
    per claim. Re-uses cached research when fresh, calibrated by content-type.
---

# research — evidence-backed knowledge production

> **Operating principle**: every claim in research output must be defensible
> to a skeptical stakeholder. URL resolves, quote is in source, source is
> independent. Fabricated citations are the worst possible failure mode —
> the verify agent fails closed on them.

## What this skill does

Four-phase pipeline with 4 specialist agents:

1. **Scout** (research-scout, Haiku) — decomposes the user's question, checks
   `/docs/research/` for existing fresh findings (content-type-calibrated
   freshness — fast/medium/slow/permanent buckets), proposes a scoped research
   plan + estimated query budget. Stops here for `report-then-ask` gate.
2. **Query** (research-query, Sonnet) — executes web/library searches in
   parallel, fetches pages via WebFetch + context7 (for library docs),
   extracts atomic claims with URL+QUOTE+ACCESSED-AT evidence, dumps to
   `claims.jsonl`.
3. **Synthesize** (research-synthesize, Sonnet) — builds a lightweight
   SKOS-adapted ontology, triangulates each claim across ≥3 independent
   sources (Denzin's 4 types, not just count), produces final
   `/docs/research/<topic>.md` and updates `index.md`.
4. **Verify** (research-verify, Haiku) — anti-hallucination gate. For every
   citation in the final doc: resolves URL, greps the literal quote, checks
   DOI via Crossref. Fails closed on any unverified citation. Writes
   `verify.json` with per-citation status.

## Entry flow

### Step 1 — Preflight + cache check

```bash
TOPIC_SLUG=$(echo "$USER_QUESTION" | bash .claude/skills/research/scripts/check-cache.sh --slugify)
SESSION_DIR="docs/research/.cache/sessions/$(date +%Y-%m-%d-%H%M%S)-$TOPIC_SLUG"
mkdir -p "$SESSION_DIR"

bash .claude/skills/research/scripts/check-cache.sh \
  --topic "$TOPIC_SLUG" \
  --question "$USER_QUESTION" \
  > "$SESSION_DIR/cache-check.json"
```

`cache-check.json` reports: existing doc path (if any), age in days,
content-type bucket (fast/medium/slow/permanent), freshness verdict
(fresh / aging / stale / outdated), recommended action
(reuse | delta-update | full-research).

If verdict is `reuse`, return the existing doc path to the user and exit. Do
not burn query tokens on a cache hit.

### Step 2 — Scout (Task tool → research-scout)

Pass `cache-check.json` + the user question. Scout returns
`scout-plan.json`:

```jsonc
{
	"topic_slug": "react-server-components-data-fetching",
	"question": "...",
	"decomposition": ["sub-q1", "sub-q2", "..."],
	"domain": "software-engineering",
	"playbook": "library-evaluation", // from references/domain-playbooks.md
	"content_type_bucket": "fast", // fast | medium | slow | permanent
	"estimated_queries": 12,
	"estimated_minutes": 8,
	"cache_strategy": "delta-update", // from cache-check.json
	"blockers": [],
}
```

### Step 3 — Report-then-ask (HARD STOP)

Present a ≤6-line summary to the user:

```
Topic: react-server-components-data-fetching
Domain: software-engineering · Playbook: library-evaluation
Plan: 3 sub-questions, ~12 queries, ~8 min
Cache: delta-update of /docs/research/react-server-components-data-fetching.md (47d old)
Proceed? (y / scope-down / cancel)
```

Do NOT proceed to Step 4 without an explicit reply. Mirror the e2e-audit
report-then-ask gate.

### Step 4 — Query (Task tool → research-query)

Dispatch with `scout-plan.json`. Agent runs parallel searches, writes
`claims.jsonl` (one atomic claim per line) and `sources.jsonl` (one source
per line, with accessed-at timestamp). Each claim references its source by
ID. Hard rule: every claim has at least one verbatim quote from its source.

### Step 5 — Synthesize (Task tool → research-synthesize)

Dispatch with `claims.jsonl` + `sources.jsonl`. Agent:

1. Builds ontology from `references/ontology-patterns.md` vocabulary.
2. Triangulates: groups claims by assertion, requires ≥3 INDEPENDENT
   sources (Denzin types, not just count) for high-confidence claims.
3. Renders `/docs/research/<topic-slug>.md` from
   `templates/research.md.tpl`.
4. Writes ADR to `/docs/research/decisions/NNNN-<slug>.md` if the
   user's question implies a decision.
5. Calls `scripts/update-index.sh` to regenerate `/docs/research/index.md`
   and any MOCs.

### Step 6 — Verify (Task tool → research-verify)

Dispatch with the rendered doc. Agent runs
`scripts/verify-citations.sh <doc>` which:

- For each `Source` row → fetches URL, checks HTTP 200, greps the
  associated quote.
- For DOIs → hits Crossref API.
- Writes `verify.json` to the session dir.
- Returns non-zero on any failed citation.

If verify fails, the synthesize agent is re-dispatched with the failure
report to fix or remove unverifiable claims. Three failed verify rounds →
abort and surface findings to the user.

### Step 7 — Persist + summarize

```bash
bash .claude/skills/research/scripts/update-index.sh
echo "$TOPIC_SLUG $(date -u +%Y-%m-%dT%H:%M:%SZ) $VERIFY_STATUS" \
  >> docs/research/.research-state.jsonl
```

Return ≤5 sentences to the user: doc path, claim count, sources cited,
confidence levels, open questions count. Do NOT paste the doc body.

## User flags

- `--force-fresh` — ignore cache, full research even if fresh exists
- `--delta-only` — only update sections that changed since the cached version
- `--scope <bucket>` — narrow content-type bucket (fast | medium | slow | permanent)
- `--playbook <name>` — override playbook detection (from `references/domain-playbooks.md`)
- `--no-verify` — skip verify gate (NOT recommended; only for offline runs)
- `--lang <code>` — output language (default: `en`; accepts `pt`, `es`, etc.)
- `--max-queries <N>` — cap total queries (default 20)
- `--dry-run` — produce scout-plan.json then stop

## Output layout

```
docs/research/
├── index.md                          # auto-regenerated by update-index.sh
├── .research-state.jsonl             # append-only audit log
├── <topic-slug>.md                   # one per topic — main deliverable
├── decisions/
│   ├── index.md
│   └── NNNN-<slug>.md                # ADR (Nygard 2011 format)
├── moc/                              # Maps of Content (Nick Milo)
│   └── <theme>.md
└── .cache/
    └── sessions/<id>/
        ├── cache-check.json
        ├── scout-plan.json
        ├── claims.jsonl
        ├── sources.jsonl
        ├── verify.json
        └── snapshots/<n>.html        # WebFetched page caches for grep
```

## Evidence protocol — URL+QUOTE+ACCESSED-AT+VERIFY-METHOD

Adapted from super-design's SHOT+QUOTE+SEL+VAL. Every non-meta claim in the
output ships:

| Field             | Meaning                                                          |
| ----------------- | ---------------------------------------------------------------- |
| **URL**           | Resolvable HTTP 200 URL OR DOI resolved through Crossref         |
| **QUOTE**         | Verbatim string greppable in the fetched source page             |
| **ACCESSED-AT**   | UTC ISO-8601 timestamp of the fetch                              |
| **VERIFY-METHOD** | `web-fetch` / `crossref-api` / `screenshot` / `archive-snapshot` |

`scripts/verify-citations.sh` enforces this contract. Coverage-gap and
"open question" findings are exempt (no claim to verify).

## Freshness — content-type buckets (NOT one-size)

| Bucket        | Examples                                                  | Fresh | Aging   | Stale    | Outdated |
| ------------- | --------------------------------------------------------- | ----- | ------- | -------- | -------- |
| **fast**      | frontend frameworks, AI/LLM SOTA, cloud pricing           | <30d  | 30–90d  | 90–180d  | >180d    |
| **medium**    | established libraries, design patterns, UX best practices | <90d  | 90–180d | 180–365d | >365d    |
| **slow**      | language fundamentals, CS theory, HCI research            | <365d | 1–2y    | 2–5y     | >5y      |
| **permanent** | math theorems, physical laws, historical facts            | <5y   | 5–10y   | 10–20y   | >20y     |

Bucket detection lives in `scripts/check-cache.sh`. Override with `--scope`.

## Triangulation — Denzin's 4 types, not "3 sources"

Per `references/research-methodology.md` §4. A claim achieves
**high-confidence** only when it survives ≥3 INDEPENDENT sources where
"independent" means satisfying ≥1 of:

- **Data triangulation** — different time/place/persons
- **Investigator triangulation** — different authors with no shared
  funding/employer
- **Theoretical triangulation** — different theoretical framings reach
  the same conclusion
- **Methodological triangulation** — different methods (survey vs
  interview vs telemetry) converge

Republication chains and citation cascades count as **one** source.
`scripts/verify-citations.sh` flags suspected republication via shared DOM
fingerprints + ownership trees.

## Scripts (`.claude/skills/research/scripts/`)

| Script                | Purpose                                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------------------- |
| `check-cache.sh`      | Slugify topic, scan `/docs/research/`, classify content-type bucket, return reuse/delta/full verdict |
| `verify-citations.sh` | Per citation: HTTP 200, quote grep, DOI Crossref check, write verify.json                            |
| `dedup-research.sh`   | Detect overlap between docs (jaccard on concept lists + citation overlap), suggest merge             |
| `update-index.sh`     | Regenerate `/docs/research/index.md` + per-folder indexes from frontmatter                           |
| `extract-claims.py`   | Pull atomic claims with citations from a rendered doc into JSONL                                     |

## Templates (`.claude/skills/research/templates/`)

| Template                     | Output                                      |
| ---------------------------- | ------------------------------------------- |
| `research.md.tpl`            | Main `/docs/research/<slug>.md` deliverable |
| `adr.md.tpl`                 | Nygard ADR for decision questions           |
| `moc.md.tpl`                 | Map of Content for cross-topic themes       |
| `index.md.tpl`               | TOC for `/docs/research/index.md`           |
| `research-state.schema.json` | Schema for state JSONL entries              |

## References (read on demand)

- `references/research-methodology.md` — the 15-topic deep methodology bible
- `references/ontology-patterns.md` — SKOS-adapted relationship vocabulary + LLM-friendly ontology examples
- `references/source-directory.md` — per-domain authoritative sources, authority hierarchies, AI-content red flags
- `references/domain-playbooks.md` — step-by-step protocols per research domain (UX, library eval, API, ADR, market, academic, news, security, pricing)

## Hard rules

1. **Cache first**. Never burn query tokens on a fresh cache hit.
2. **Report-then-ask**. After scout, STOP for user confirmation before query.
3. **Every claim has URL+QUOTE+ACCESSED-AT+VERIFY-METHOD**. Verify gate fails closed on violations.
4. **No fabricated citations, ever**. If a quote cannot be greppped in the fetched page, the claim is dropped.
5. **Triangulate by Denzin type, not raw count**. 3 republications of one wire story = 1 source.
6. **Content-type freshness**. Don't apply fast-bucket aging to slow-bucket topics or vice versa.
7. **Output to `/docs/research/`** — never to `.claude/skills/research-cache/` (legacy).
8. **English output by default** — even when triggered in Portuguese. Override with `--lang pt`.
9. **Summary to user ≤5 sentences**. Doc body lives in the file.
10. **Skill ⊥ super-design ⊥ e2e-audit**. If the user asked for a UX audit or test audit, hand off — do not improvise.

## Boundaries (what this skill does NOT do)

- Does NOT implement code based on its own findings. Hand the doc to the user / implementing agent.
- Does NOT replace `super-design` for design audits or `e2e-audit` for test audits.
- Does NOT publish research outside `/docs/research/`.
- Does NOT invent fixtures or scrape behind paywalls.
- Does NOT bypass robots.txt or honor restrictions on cited sites.

## Invocation triggers (enforced by SessionStart hook)

EN: `research`, `investigate`, `find info`, `search for`, `look up`,
`evaluate`, `compare`, `audit literature`, `competitor analysis`,
`market research`, `library evaluation`, `prior art`.

PT: `pesquisar`, `pesquisa`, `pesquise`, `investigar`, `buscar info`,
`procurar info`, `comparar`, `avaliar biblioteca`, `análise de
mercado`, `análise de concorrentes`.

The hook injects this context at session start. Claude must read this
SKILL.md before improvising a research plan.
