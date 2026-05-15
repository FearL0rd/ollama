---
description: Run the research skill (cache-aware, source-first, evidence-verified)
---

Invoke the research skill with flags / question: $ARGUMENTS

Follow SKILL.md entry flow:

1. Preflight + cache check (content-type-calibrated freshness)
2. Scout — decompose, propose scoped plan, estimate budget
3. Report-then-ask — STOP for user confirmation before any query
4. Query — parallel searches, atomic claim extraction with URL+QUOTE+ACCESSED-AT
5. Synthesize — SKOS ontology, Denzin triangulation, render /docs/research/<slug>.md
6. Verify — citation grep + Crossref check; fail closed on unverified claims
7. Persist — update-index.sh, append .research-state.jsonl
8. Return ≤5-sentence summary

Do not paste the rendered doc into chat.
