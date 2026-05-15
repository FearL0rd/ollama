---
title: "{{THEME_TITLE}}"
type: moc
date: "{{DATE_YYYY_MM_DD}}"
theme: "{{THEME_SLUG}}"
---

# MOC — {{THEME_TITLE}}

_Map of Content (Nick Milo, "Linking Your Thinking"). A curated entry
point that links related research docs around a theme._

## Overview

{{OVERVIEW}}

## Topics in this map

{{#each TOPIC}}
- [{{TITLE}}](../{{SLUG}}.md) — {{ONE_LINER}}
{{/each}}

## ADRs in this map

{{#each ADR}}
- [ADR-{{NNNN}}: {{TITLE}}](../decisions/{{NNNN}}-{{SLUG}}.md)
{{/each}}

## Recurring concepts

{{#each CONCEPT}}
- **{{CONCEPT_NAME}}** — appears in: {{IN_DOCS}}
{{/each}}

## Open questions across topics

{{#each OPEN_Q}}
- {{TEXT}}
{{/each}}
