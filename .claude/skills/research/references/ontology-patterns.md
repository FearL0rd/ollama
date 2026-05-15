# Ontology Patterns — Reference

> Practical, LLM-friendly ontology encoding for `/docs/research/`. SKOS-shaped, markdown-native, round-trippable through `extract-claims.py`.

---

## 1. Why SKOS Beats OWL for LLM-Consumed Docs

OWL (Web Ontology Language; W3C Rec 2012, <https://www.w3.org/TR/owl2-overview/>) gives you description-logic reasoning: subsumption, equivalence, disjointness, cardinality. The tax: every concept needs an IRI, every property needs a domain/range, every assertion is a triple, and serializations balloon.

SKOS (Simple Knowledge Organization System; W3C Rec 2009, <https://www.w3.org/TR/skos-reference/>) gives you the 80% case — concepts, broader/narrower/related, prefLabel/altLabel, scopeNote — at a fraction of the surface area. SKOS is _intentionally informal_ about logic; it expects retrieval, not inference.

**For LLM consumption (Claude reading research docs to ground future answers), SKOS wins on:**

| Dimension                     | OWL                              | SKOS                                    |
| ----------------------------- | -------------------------------- | --------------------------------------- |
| Token cost per concept        | High (axioms, IRIs, domains)     | Low (label + a few links)               |
| Looseness tolerated           | Reasoner breaks on inconsistency | Retrieval still works on contradictions |
| Markdown round-trip           | Hard (needs Turtle/RDF/XML)      | Trivial (frontmatter + inline lines)    |
| Author burden                 | High (must understand DL)        | Low (broader/narrower/related)          |
| Reasoning needed at read time | Often                            | Rarely                                  |

The skill therefore uses SKOS-shaped semantics encoded directly in markdown, with a closed vocabulary of relationships extended slightly past stock SKOS to cover engineering/research needs.

---

## 2. Recommended Relationship Vocabulary

This is the **closed list** for `/docs/research/`. `extract-claims.py` recognizes exactly these verbs (case-insensitive, hyphenated). Anything else is a free-text sentence and is _not_ indexed as a relationship.

| Relation         | Direction | Meaning                                 | SKOS analogue       |
| ---------------- | --------- | --------------------------------------- | ------------------- |
| `is-a`           | A → B     | A is a subtype/specialization of B      | skos:broader        |
| `has-a`          | A → B     | A includes/owns B as a part             | (custom; mereology) |
| `composed-of`    | A → B     | A is built from multiple B (collection) | (custom)            |
| `instance-of`    | A → B     | A is a concrete instance of category B  | rdf:type            |
| `depends-on`     | A → B     | A requires B to function                | (custom)            |
| `constrained-by` | A → B     | A's behavior is bounded by rule/spec B  | (custom)            |
| `resolved-by`    | A → B     | Problem A is addressed by solution B    | (custom)            |
| `precedes`       | A → B     | A happens before B (temporal/causal)    | (Allen `before`)    |
| `equivalent-to`  | A ↔ B     | A and B refer to the same concept       | skos:exactMatch     |
| `related-to`     | A — B     | A and B are associated; no hierarchy    | skos:related        |
| `contradicts`    | A — B     | A and B make incompatible claims        | (custom)            |
| `extends`        | A → B     | A builds on B, adding capability        | (custom)            |
| `deprecated-by`  | A → B     | A is superseded by B                    | (custom)            |

Notes:

- `is-a` is transitive: if `A is-a B` and `B is-a C`, the indexer materializes `A is-a C`. Use sparingly to avoid exploding the graph.
- `equivalent-to` is symmetric and merges concept neighborhoods at index time.
- `contradicts` is symmetric and is what the synthesis agent uses to populate the `## Disagreements` section.
- `related-to` is the catch-all. Prefer a typed verb if available — `related-to` is for when the connection is real but the type is ambiguous.

---

## 3. Encoding in Plain Markdown

Two valid encodings, both parsed by `extract-claims.py`:

### 3.1 Frontmatter declaration (concepts list)

```yaml
---
title: React Data Fetching
concepts:
    - server-components
    - suspense
    - streaming-ssr
    - use-hook
    - data-cache
---
```

Concepts in this list are local to the doc and are slugged (`kebab-case`, lowercased, ASCII). They become first-class nodes in the knowledge graph.

### 3.2 Inline relationship lines

A line that matches the regex `^([A-Za-z0-9-]+)\s+(is-a|has-a|composed-of|instance-of|depends-on|constrained-by|resolved-by|precedes|equivalent-to|related-to|contradicts|extends|deprecated-by)\s+([A-Za-z0-9-]+)\s*(\.|$|—.*)$` is a relationship triple.

Examples:

```
server-components is-a react-rendering-model.
suspense depends-on react-fiber.
use-hook extends react-hooks-api — adds promise unwrapping.
fetch-on-render deprecated-by render-as-you-fetch.
streaming-ssr related-to progressive-hydration.
```

The trailing period is required so prose sentences that happen to mention these verbs are not falsely matched. The em-dash + free text after is allowed for short scope notes; the indexer ignores it for graph building but keeps it in the doc.

### 3.3 Block form (when you have many relations to one concept)

```
## server-components

- is-a react-rendering-model.
- depends-on react-flight-protocol.
- composed-of rsc-payload, server-runtime, client-bridge.
- contradicts client-only-rendering — coexistence requires careful boundary design.
- related-to streaming-ssr.
```

Lines starting with `- ` under an H2/H3 whose slug matches a frontmatter concept are auto-prefixed with that concept as the subject.

---

## 4. Concept Schemes — When and When Not

A **concept scheme** (skos:ConceptScheme) is a controlled vocabulary scoped to a project or topic family. Use one when:

- You have ≥ 3 docs in `/docs/research/` covering related topics.
- The same concept is referenced from multiple docs with potential label drift (e.g., "RSCs" vs "react-server-components" vs "Server Components").
- You need a single source of truth for `prefLabel` and `altLabel`.

Skip when:

- The topic is one-off (single doc, no expected follow-ups).
- The concepts are jargon-stable (HTTP status codes, ISO date formats — already canonicalized elsewhere).

When in use, the concept scheme lives at `/docs/research/_concepts.md`:

```yaml
---
title: Concept Scheme
type: skos:ConceptScheme
---
## react-server-components

- prefLabel: React Server Components
- altLabel: RSC, RSCs, Server Components
- definition: React components that render on the server and stream their output to the client; first stable in React 19.
- scopeNote: Distinct from SSR. Specific to React's Flight protocol.
- broader: react-rendering-models
- related: streaming-ssr, suspense
- source: https://react.dev/reference/rsc/server-components

## suspense

- prefLabel: Suspense
- altLabel: React Suspense
- definition: ...
- broader: react-async-primitives
- related: react-server-components, use-hook
- source: https://react.dev/reference/react/Suspense
```

Each doc in `/docs/research/` that references a concept by its slug inherits the labels and definition from the scheme. If a doc redefines `prefLabel` or `definition` for the same slug, the indexer flags **ontology drift** as a build error.

---

## 5. Wikilink Conventions

- `[[concept-slug]]` — outbound link to the concept's canonical doc (or to the scheme if no dedicated doc exists).
- `[[concept-slug|Display Text]]` — outbound with custom anchor text.
- Backlinks are auto-generated in `/docs/research/index.md#backlinks` by `build-ontology.py`.

Rules:

- Slugs are stable. Renaming a concept requires a migration entry in `/docs/research/_migrations.md` mapping old → new.
- Wikilinks may target a concept (`[[suspense]]`), a doc (`[[react-data-fetching]]`), or a scheme entry (`[[_concepts#suspense]]`).
- Markdown link syntax `[label](url)` is for _external_ sources only. Internal cross-references must be wikilinks so backlinks work.

---

## 6. Worked Example A — React Data Fetching

`/docs/research/react-data-fetching.md`:

```yaml
---
title: React Data Fetching (2026 state)
created: 2026-04-25
updated: 2026-04-25
freshness: fresh
concepts:
    - server-components
    - suspense
    - use-hook
    - streaming-ssr
    - render-as-you-fetch
    - fetch-on-render
    - data-cache
tags: [react, data-fetching, ssr]
---
```

Body, ontology slice:

```
## Concept relationships

- server-components is-a react-rendering-model.
- server-components depends-on react-flight-protocol.
- server-components composed-of rsc-payload, server-runtime, client-bridge.
- suspense is-a react-async-primitive.
- suspense depends-on react-fiber.
- use-hook extends react-hooks-api — promise unwrapping inside components.
- use-hook depends-on suspense.
- streaming-ssr is-a server-rendering-strategy.
- streaming-ssr related-to server-components.
- render-as-you-fetch is-a data-fetching-pattern.
- fetch-on-render is-a data-fetching-pattern.
- fetch-on-render deprecated-by render-as-you-fetch.
- data-cache constrained-by react-cache-api — request-scoped, not session-scoped.
```

Findings using these concepts:

```
### Finding 1 — Server Components ship zero client JS by default

Claim: Server Components render exclusively on the server and emit a serialized payload that the client reconciles without shipping component code. [[server-components]] [[react-flight-protocol]]

> "Server Components have no interactivity ... they don't use state or effects. They render once, on the server."
> — React docs, "Server Components", accessed 2026-04-25.

URL: https://react.dev/reference/rsc/server-components
ACCESSED-AT: 2026-04-25T14:00Z
VERIFY-METHOD: HTTP 200 + quote-grep ✓
Confidence: High (primary source — React official docs)
```

---

## 7. Worked Example B — OAuth 2.0 Authorization Code Flow

`/docs/research/oauth2-auth-code-flow.md`:

```yaml
---
title: OAuth 2.0 Authorization Code Flow with PKCE
created: 2026-04-25
updated: 2026-04-25
freshness: fresh
concepts:
    - oauth2
    - authorization-code-grant
    - pkce
    - access-token
    - refresh-token
    - id-token
    - authorization-server
    - resource-server
    - client
tags: [oauth2, security, auth]
---
```

Ontology slice:

```
## Concept relationships

- oauth2 is-a authorization-framework.
- oauth2 constrained-by rfc-6749.
- authorization-code-grant is-a oauth2-grant-type.
- authorization-code-grant constrained-by rfc-6749-section-4-1.
- pkce extends authorization-code-grant — adds code_verifier/code_challenge.
- pkce constrained-by rfc-7636.
- pkce resolved-by code-interception-attack.
- access-token has-a expiration.
- refresh-token precedes access-token-renewal.
- id-token is-a jwt.
- id-token related-to oidc.
- id-token contradicts access-token — different audience and purpose.
- authorization-server depends-on client-registry.
- resource-server constrained-by access-token-validation.
- implicit-grant deprecated-by authorization-code-grant — see OAuth 2.1 draft.
```

Three findings cross-linking the concepts:

```
### Finding 1 — PKCE is mandatory for public clients

Claim: RFC 7636 mandates PKCE for clients that cannot keep a secret (mobile, SPA), and OAuth 2.1 draft extends this to all clients. [[pkce]] [[authorization-code-grant]] [[client]]

> "All clients SHOULD use PKCE ... clients without a client secret MUST use PKCE."
> — draft-ietf-oauth-v2-1-11, accessed 2026-04-25.

URL: https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-11
ACCESSED-AT: 2026-04-25T14:05Z
VERIFY-METHOD: HTTP 200 + quote-grep ✓
Confidence: High

### Finding 2 — Implicit grant should not be used in new systems

Claim: The implicit grant is removed from OAuth 2.1 and OWASP recommends authorization-code + PKCE in all cases. [[implicit-grant]] [[authorization-code-grant]] [[pkce]]

URL: https://oauth.net/2.1/
ACCESSED-AT: 2026-04-25T14:07Z
VERIFY-METHOD: HTTP 200 + quote-grep ✓
Confidence: High

### Finding 3 — Refresh-token rotation mitigates token theft

Claim: Rotating refresh tokens on each use, combined with reuse-detection, allows the authorization server to invalidate a compromised session. [[refresh-token]] [[authorization-server]]

URL: https://datatracker.ietf.org/doc/html/rfc6819#section-5.2.2.3
ACCESSED-AT: 2026-04-25T14:10Z
VERIFY-METHOD: HTTP 200 + quote-grep ✓
Confidence: High
```

---

## 8. Anti-Patterns

### 8.1 Over-Typed Relationships

Defining a new relation verb for every nuance (`maintained-by`, `documented-by`, `tested-by`, `deployed-by`...). The closed vocabulary in §2 covers the cases that survive retrieval. New verbs must be added to `extract-claims.py` and `ontology-patterns.md` together — a pull-request, not a one-off.

### 8.2 Premature OWL

Adding `owl:disjointWith`, cardinality restrictions, or property characteristics to concepts that no reasoner will ever consume. The marker is: are you running a Pellet/HermiT reasoner over `/docs/research/`? If no — keep it SKOS.

### 8.3 Ontology Drift

Same concept slug given different `prefLabel`, `definition`, or `broader` in different docs. Detector: `build-ontology.py --check-drift`. Resolution: move the canonical definition to `_concepts.md` and reference it from each doc.

### 8.4 Slug Instability

Renaming `react-server-components` to `rsc` in one doc, leaving the rest. Wikilinks break, backlinks vanish. Resolution: never rename in place; add an alias migration in `_migrations.md` and let the indexer rewrite gradually.

### 8.5 Unencoded Hierarchy

Writing prose like "Suspense is one of React's async primitives" without the `is-a` line. The graph misses it; cross-doc retrieval misses it. The rule: if it is true and worth saying, it is worth a triple.

### 8.6 Concept Sprawl

Creating concepts for every noun phrase. Concepts should be **reusable**: if a concept appears in only one doc and is unlikely to recur, leave it as prose. Threshold: a concept earns a slug when it has ≥ 2 expected docs or ≥ 3 expected relationships.

### 8.7 Mixing English and Slug

```
React-Server-Components is-a React rendering model.    # WRONG
react-server-components is-a react-rendering-model.    # RIGHT
```

The extractor is case-insensitive on verbs but strict on identifiers (kebab-case, ASCII). Mixed prose breaks the round-trip.

---

## 9. The Round-Trip Rule

Every relationship encoded in markdown must survive: `markdown → extract-claims.py → triples.json → build-ontology.py → graph.ttl → render in /docs/research/index.md → human reads → wikilink click → back to markdown`.

**If `extract-claims.py` cannot parse a relationship line, it is wrong.** The script is the spec. To validate before commit:

```
python .claude/skills/research/scripts/extract-claims.py docs/research/<topic>.md --strict
```

Failures must be fixed before the doc is considered indexed. The script's exit code is a quality gate.

---

## 10. Quick Reference Card

```
Encoding cheatsheet
-------------------
Concept declaration:    frontmatter `concepts:` list, kebab-case slugs
Cross-doc reference:    [[concept-slug]] wikilink
External source:        [label](url) — only for off-site
Relationship:           subject verb object.       (one line, period required)
Verbs (closed set):     is-a, has-a, composed-of, instance-of, depends-on,
                        constrained-by, resolved-by, precedes, equivalent-to,
                        related-to, contradicts, extends, deprecated-by
Concept scheme:         /docs/research/_concepts.md (when ≥ 3 docs share concepts)
Drift detection:        build-ontology.py --check-drift
Round-trip validation:  extract-claims.py <file> --strict
```

When in doubt: prefer `related-to` over inventing a verb, prefer prose over a fragile triple, prefer the scheme over redefining a concept inline.
