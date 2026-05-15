---
title: "{{TITLE}}"
adr_number: {{NNNN}}
date: "{{DATE_YYYY_MM_DD}}"
status: "{{STATUS}}"           # proposed | accepted | superseded-by-NNNN | deprecated | rejected
deciders: [{{DECIDERS}}]
related_research: "{{RESEARCH_DOC_PATH}}"
session_id: "{{SESSION_ID}}"
---

# ADR-{{NNNN}}: {{TITLE}}

_Format: Michael Nygard (2011), "Documenting Architecture Decisions"._

## Status

{{STATUS}}

## Context

{{CONTEXT}}

## Decision

{{DECISION}}

## Consequences

### Positive

{{#each POSITIVE}}
- {{TEXT}}
{{/each}}

### Negative

{{#each NEGATIVE}}
- {{TEXT}}
{{/each}}

### Neutral

{{#each NEUTRAL}}
- {{TEXT}}
{{/each}}

## Alternatives Considered

{{#each ALTERNATIVE}}
### {{NAME}}

- **Why considered:** {{WHY}}
- **Why rejected:** {{WHY_NOT}}
{{/each}}

## Reversibility

- **Class:** {{REVERSIBILITY_CLASS}}   <!-- one-way-door | two-way-door (Bezos) -->
- **Cost to reverse:** {{REVERSE_COST}}
- **Trigger to reconsider:** {{REVERSE_TRIGGER}}

## References

- Research doc: [{{RESEARCH_DOC_PATH}}](../{{RESEARCH_DOC_PATH}})
- Session evidence: `docs/research/.cache/sessions/{{SESSION_ID}}/`
- Nygard 2011 — https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
