# Domain Playbooks — Reference

> Step-by-step research protocols per domain. Each playbook: scope, query templates, source priority, evidence requirements, output structure pointers. Use the playbook that matches the user's question; if multiple match, run them in parallel and merge.

---

## 1. UX/Design Pattern Research

### Scope

The user wants to understand a design pattern (modal, navigation, data table, onboarding flow, etc.) — its variants, when to use each, accessibility implications, and how leading products implement it.

### Query templates

```
"<pattern>" UX best practices 2024..2026
"<pattern>" baymard
"<pattern>" nielsen norman
"<pattern>" accessibility ARIA pattern
"<pattern>" mobile vs desktop
site:baymard.com "<pattern>"
site:nngroup.com "<pattern>"
site:w3.org/WAI/ARIA/apg "<pattern>"
"<pattern>" failure mode OR anti-pattern
"<competitor>" "<pattern>"   (×3-5 competitors)
```

### Source priority

1. WCAG 2.2 / W3C WAI-ARIA Authoring Practices (APG) — accessibility ground truth.
2. Baymard Institute (commerce-UX) and Nielsen Norman Group (general UX) — empirical research.
3. Major design systems (Material 3, Apple HIG, Fluent 2, Polaris, Carbon) — production patterns.
4. Competitor implementations (3–5) — Playwright screenshots of the actual pattern in use.
5. Smashing / A List Apart for editorial framing.

### Evidence requirements

- ≥ 1 W3C/WCAG citation for accessibility.
- ≥ 2 NN/g or Baymard citations for usability rationale.
- ≥ 3 competitor screenshots taken via Playwright at desktop (1280×800), tablet (768×1024), mobile (375×812).
- Heuristic eval against Nielsen 10 (visibility, match, control, consistency, error prevention, recognition, flexibility, minimalism, error recovery, help) — score each 1–5.
- Failure modes documented with at least one real-world example.

### Output structure

`/docs/research/ux-<pattern>.md`:

```
# <Pattern> — UX Research
## TL;DR
## Variants                           # decision tree by context
## Accessibility (WCAG 2.2 + ARIA APG)
## Heuristic Evaluation               # Nielsen 10 scores per variant
## Competitor Analysis                # 3-5 competitors with screenshots
## Mobile vs Desktop divergence
## Failure Modes / Anti-patterns
## Decision Guide                     # "use variant X when ..."
## Sources
```

---

## 2. Library / Framework Evaluation

### Scope

The user is choosing between libraries, or evaluating whether to adopt one. Output drives a "yes/no/conditional" decision with quantified trade-offs.

### Query templates

```
"<lib>" vs "<lib2>" 2024..2026
"<lib>" production case study
"<lib>" bundle size bundlephobia
"<lib>" maintainer activity GitHub
"<lib>" deprecation OR archived
"<lib>" CVE vulnerability
"<lib>" migration from "<lib2>"
"<lib>" benchmark performance
site:github.com/<org>/<repo> issues "?q=is:issue"
site:npmjs.com/package/<lib>
```

### Community health metrics (collect quantitatively)

| Metric                                | Source                               | Threshold                         |
| ------------------------------------- | ------------------------------------ | --------------------------------- |
| GitHub stars (raw)                    | github.com API `/repos/{org}/{repo}` | Context-dependent                 |
| Star growth (last 12 mo)              | star-history.com                     | Growing > flat > shrinking        |
| Issue close rate                      | GitHub Insights                      | > 70% healthy                     |
| PR merge cadence                      | Insights / Pulse                     | Weekly merges = active            |
| Last release date                     | GitHub releases / npm                | < 6mo = active                    |
| Maintainer count (active in last 6mo) | git shortlog --since                 | ≥ 2 = bus factor OK               |
| Open issues / age                     | Issues filtered                      | Median age < 60d healthy          |
| npm weekly downloads                  | npmjs.com                            | Trend matters more than absolute  |
| Bundle size (min+gzip)                | bundlephobia.com                     | Compare to alternatives           |
| Tree-shakability                      | bundlephobia "side effects"          | Important for ESM consumers       |
| TypeScript types quality              | DefinitelyTyped vs first-party       | First-party >> DT >> none         |
| Test coverage                         | Codecov / repo badges                | Self-reported, sniff              |
| Documentation completeness            | Manual review                        | API reference + guides + examples |
| Ecosystem (plugins/extensions)        | search ecosystem                     | Indicates traction                |

### Source priority

1. Official repo + docs + changelog.
2. npm/registry provenance signals.
3. bundlephobia / pkg.size for size, snyk / GitHub advisories for security.
4. Independent benchmarks (web frameworks: krausest/js-framework-benchmark; sorting/parsing: vendor-neutral repos).
5. Production case studies on engineering blogs (Vercel, Cloudflare, Shopify, Netflix Tech Blog).
6. HackerNews / Reddit /r/<lang> threads — anecdata, weighted accordingly.

### Evidence requirements

- All community-health numbers with collection date.
- ≥ 1 production case study citing the lib at scale (or note absence).
- Bundle size comparison table against named alternatives.
- License compatibility check (cite SPDX identifier).
- CVE history (NVD search) — clean / open / patched.

### Output structure

`/docs/research/lib-<name>.md`:

```
# <Library> — Evaluation
## TL;DR — Recommendation (Adopt / Trial / Hold / Avoid)
## Community Health         # table of metrics with dates
## Bundle / Performance     # comparison vs alternatives
## API Stability            # semver discipline, breaking-change frequency
## Ecosystem Fit            # plugins, integrations, TS support
## Production Evidence      # case studies, talks
## Security Posture         # CVE history, advisory response
## Migration Cost           # if replacing existing
## Risks                    # bus factor, license, governance
## Decision                 # with explicit reversibility note
## Sources
```

---

## 3. API Integration Research

### Scope

The user is integrating against a third-party API and needs to understand auth, rate limits, SDK quality, pricing, reliability, and idiomatic usage patterns before writing code.

### Query templates

```
"<API>" authentication OAuth scopes
"<API>" rate limit "requests per"
"<API>" SDK <language> official
"<API>" pricing tier
"<API>" SLA uptime
"<API>" status page
"<API>" deprecation policy
"<API>" webhook signature verification
"<API>" pagination
"<API>" idempotency
"<API>" error codes
```

### Source priority

1. Vendor docs (canonical URL).
2. Vendor status page + history (statuspage.io / vendor-hosted).
3. Official SDKs on the vendor's GitHub org.
4. OpenAPI spec / Postman collection if published.
5. Engineering blog posts from the vendor.
6. Independent integration write-ups (treat as anecdotal).

### Evidence requirements

- Auth pattern: flow diagram + sample request/response with redacted tokens.
- Rate limits: documented numbers with units (per minute / per hour / per token / per IP).
- SDK matrix: language × maintenance status × types × last release.
- Pricing: per-tier table with included quotas + overage cost.
- SLA: uptime percentage, credit policy, exclusions.
- Reliability: status-page incident count for last 90 days.
- Webhook security: signature scheme cited (HMAC-SHA256 etc.) with verification example.

### Output structure

`/docs/research/api-<vendor>.md`:

```
# <Vendor> API — Integration Research
## TL;DR
## Authentication           # flow + scopes + token lifecycle
## Endpoints summary        # by domain, link to vendor docs
## Rate limits              # quantified, per dimension
## Pagination + idempotency
## Error model              # codes, retry strategy
## Webhooks                 # signature scheme, replay protection
## SDK matrix               # by language
## Pricing tiers
## SLA + reliability        # 90-day incident summary
## Deprecation policy
## Risks / Gotchas
## Sources
```

---

## 4. Architectural Decision Research

### Scope

The user is making a non-trivial architecture choice (database, queue, deployment topology, framework architecture, data modeling). Output is feedstock for an ADR.

### Query templates

```
"<choice-A>" vs "<choice-B>" production trade-off
"<choice-A>" RFC OR design doc
"<choice-A>" "we chose" OR "we migrated"
"<choice-A>" failure mode at scale
site:github.com/<org>/<repo>/issues "<topic>"
"<choice-A>" CAP OR consistency model
"<choice-A>" cost at scale
```

### Source priority

1. Original RFCs / design docs from the projects involved.
2. Conference talks (CMU DB Group, QCon, Strange Loop, USENIX) — highest-quality independent analysis.
3. Engineering blog post-mortems — what broke at scale.
4. Academic comparative papers.
5. Vendor documentation (read with bias correction).

### Trade-off matrix (mandatory)

Build a matrix per dimension: throughput, latency, consistency, durability, operational complexity, cost, ecosystem maturity, hireability, vendor lock-in. Each cell cites a source.

### Reversibility scoring (Bezos two-way-door)

Per option, classify the migration cost away from it as:

- **One-way**: data shape lock-in, vendor SDKs throughout codebase, contractual lock-in.
- **Two-way**: standard interfaces (SQL, S3 API, OCI), abstraction layer in place.

Bias toward two-way doors; pay a premium for reversibility unless one-way is clearly superior.

### Evidence requirements

- ≥ 2 production post-mortems per option (or note absence and what that implies).
- Cost model with explicit assumptions.
- Operational-complexity assessment with team-size assumptions.
- Migration path _out_ of the choice, not just _in_.

### Output structure

`/docs/research/arch-<topic>.md`:

```
# <Topic> — Architectural Decision Research
## TL;DR Recommendation
## Options considered
## Trade-off matrix          # dimensions × options
## Reversibility analysis    # per option
## Production evidence       # post-mortems per option
## Cost model
## Operational requirements
## Risks
## Open questions
## Sources
## ADR draft                 # template-ready: Status / Context / Decision / Consequences
```

---

## 5. Market / Competitive Research

### Scope

The user wants market context: TAM/SAM/SOM, players, positioning, differentiation, growth trajectories, regulatory headwinds.

### Query templates

```
"<market>" market size 2024..2026
"<market>" CAGR forecast
"<market>" Gartner Magic Quadrant
"<market>" Forrester Wave
"<competitor>" funding round
"<competitor>" 10-K annual report
"<market>" regulatory
"<market>" Porter five forces
```

### Frameworks to apply

- **TAM / SAM / SOM** (Total / Serviceable / Serviceable-Obtainable).
- **Porter 5 Forces** (Porter 1980): entry threat, supplier power, buyer power, substitutes, rivalry.
- **Positioning quadrant** (2 chosen axes; cite why those axes).
- **Jobs-to-be-done** if behavioral framing matters.

### Source priority

1. Public 10-K / 10-Q filings (SEC EDGAR) — primary financial data.
2. Tier-1 analyst reports (Gartner, Forrester, IDC).
3. Industry trade press (sector-specific).
4. CB Insights, PitchBook, Crunchbase for private-market data.
5. Founder/exec interviews on podcasts or Substack.

### Evidence requirements

- TAM number with methodology cited (top-down vs bottom-up).
- ≥ 5 competitors profiled with: HQ, founded year, employees, funding to date, last round, primary product, pricing model.
- Positioning quadrant with axes justified.
- ≥ 1 regulatory citation if relevant (GDPR, HIPAA, PCI-DSS, sector-specific).

### Output structure

`/docs/research/market-<segment>.md`:

```
# <Segment> — Market Research
## TL;DR
## Market sizing            # TAM/SAM/SOM with methodology
## Competitor matrix        # ≥ 5 profiles
## Positioning              # quadrant + JTBD
## Porter 5 Forces
## Regulatory context
## Trends + tailwinds/headwinds
## Sources
```

---

## 6. Academic Literature Review

### Scope

The user wants the state of academic knowledge on a topic — methods, findings, replications, open questions. Default to **PRISMA-ScR scoping flow** (Tricco AC et al. _Ann Intern Med_ 2018, doi:10.7326/M18-0850) when narrative is too light and full systematic is too heavy.

### Query templates

By database:

- **PubMed**: `("<concept1>"[Title/Abstract]) AND ("<concept2>"[MeSH]) AND ("2020"[PDAT] : "2026"[PDAT])`
- **arXiv**: `cat:cs.* AND (abs:"<phrase>")`
- **Google Scholar**: `"<phrase>" -site:wikipedia.org` with date range
- **Semantic Scholar**: API `/paper/search?query=...&year=2020-2026`
- **Crossref**: `https://api.crossref.org/works?query.bibliographic=...&filter=from-pub-date:2020`

### Inclusion / exclusion criteria template

```
Inclusion:
- Published 2020–2026 (adjust per topic)
- Peer-reviewed OR preprint with ≥ X citations
- English (or extend per question)
- Reports empirical data OR systematic synthesis OR formal proof
- Topic match: covers <concept1> AND <concept2>

Exclusion:
- Editorials, opinions, letters without data
- Withdrawn papers (Retraction Watch check)
- Predatory journals (Beall's archive / DOAJ check)
- Conference posters without proceedings
- Conflict of interest undisclosed
```

### Source priority

1. Peer-reviewed journal articles with DOI.
2. Conference proceedings (top-tier: NeurIPS, ICML, ICLR for ML; SOSP, OSDI, NSDI for systems; CHI, UIST for HCI).
3. Preprints (arXiv, bioRxiv) flagged as such.
4. Theses / dissertations.
5. Working papers / technical reports.

### Evidence requirements

- PRISMA-ScR-style flow diagram: identification → screening → eligibility → included counts.
- Inclusion/exclusion criteria stated explicitly.
- Per-paper extraction: study design, n, key findings, limitations, replication status.
- Disagreements / contradictions explicitly listed.

### Output structure

`/docs/research/lit-<topic>.md`:

```
# <Topic> — Literature Review
## TL;DR
## Question + framing
## Method                   # databases, dates, query strings, inclusion/exclusion
## PRISMA-ScR flow          # identified / screened / eligible / included
## Findings synthesis       # by sub-question
## Disagreements
## Replication status       # per major finding
## Open questions
## Sources                  # full bibliography (BibTeX / CSL-JSON)
```

---

## 7. News & Current-Events Research

### Scope

A breaking or recent event needs reconstruction: timeline, actors, claims, disputed claims, current state.

### Query templates

```
"<event>" site:reuters.com OR site:apnews.com
"<event>" before:YYYY-MM-DD after:YYYY-MM-DD
"<event>" timeline
"<event>" fact check
"<event>" original document OR primary source OR transcript
"<actor>" "<event>"
```

### Source priority

1. Wire services (Reuters, AP, AFP) as the temporal anchor.
2. Newspapers of record (NYT, WSJ, FT, The Economist, Washington Post, Guardian).
3. Subject-matter trade press (e.g., The Verge for tech, STAT for biotech).
4. Primary documents: court filings, regulatory disclosures, official transcripts, archived statements.
5. Fact-check organizations (Snopes, PolitiFact, FactCheck.org) — for _their sources_, not their verdict alone.
6. Wayback Machine for verifying what a URL said on a given date.

### Bias detection

- **AllSides** (<https://www.allsides.com/>) — outlet bias rating left/center/right.
- **Ad Fontes Media** (<https://adfontesmedia.com/>) — bias × reliability chart.

For any contested claim, cite at least one source from each side of the bias spectrum and note their respective ratings.

### Timeline construction

Build a chronological table: timestamp (UTC) | event | source | confidence. Use the wire-service timestamp as anchor; later corrections noted as separate rows.

### Evidence requirements

- ≥ 2 wire-source citations for the core facts.
- ≥ 1 primary document if one exists (court filing, press release, regulatory filing).
- Wayback snapshot for any URL whose content might change.
- Bias-spread coverage for contested claims.

### Output structure

`/docs/research/news-<slug>.md`:

```
# <Event> — News Research
## TL;DR + as-of timestamp
## Timeline                 # chronological table
## Actors
## Established facts        # with wire-service citations
## Disputed claims          # both sides with bias ratings
## Primary documents        # links + Wayback fallbacks
## What's missing / unknown
## Sources
```

---

## 8. Security Research

### Scope

A library, service, or pattern needs a security review: known vulnerabilities, advisory chain, vendor disclosure history, mitigations.

### Query templates

```
"<lib/product>" CVE
"<lib/product>" GHSA
"<lib/product>" security advisory
"<lib/product>" OWASP
"<lib/product>" responsible disclosure
"<lib/product>" supply chain attack
site:nvd.nist.gov "<lib>"
site:github.com/advisories "<lib>"
```

### Source priority

1. **NVD** (NIST National Vulnerability Database, <https://nvd.nist.gov/>) — authoritative CVE store with CVSS scores.
2. **GitHub Advisory Database** (<https://github.com/advisories>) — language/ecosystem-aware, often ahead of NVD.
3. **MITRE CVE** (<https://cve.org/>) — original record.
4. **Vendor security pages** — official advisories.
5. **OSV.dev** (<https://osv.dev/>) — Open Source Vulnerability database aggregating multiple feeds.
6. **CISA KEV** (Known Exploited Vulnerabilities, <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>) — actively exploited.
7. **OWASP Top 10** for category context.

### CVSS scoring

CVSS v3.1 / v4.0 vector strings: `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` style. Always cite the vector, not just the score number, so reviewers can recompute.

### Evidence requirements

- All CVEs in the last 36 months with: CVE ID, CVSS score + vector, affected versions, fixed versions, published date, exploitation status (per CISA KEV).
- Vendor disclosure-to-patch timeline per CVE.
- Advisory chain: CVE → vendor advisory → distro/package advisory → user-visible release.
- Mitigations: configuration, network controls, version pinning.

### Output structure

`/docs/research/sec-<topic>.md`:

```
# <Topic> — Security Research
## TL;DR risk assessment
## Vulnerability history     # CVE table with scores + vectors
## Vendor disclosure record  # mean time-to-patch
## OWASP categories triggered
## Supply chain considerations  # registry provenance, signing
## Recommended controls
## Mitigations               # config, network, version pinning
## Sources
```

---

## 9. Pricing & Cost Research

### Scope

The user is sizing the cost of using a vendor / running infrastructure / scaling a feature. Output supports a TCO model.

### Query templates

```
"<vendor>" pricing
"<vendor>" pricing changed OR pricing increase
"<vendor>" hidden fees OR egress
"<vendor>" deprecated tier
"<vendor>" SLA credit
"<vendor>" reserved instance OR commitment discount
"<vendor>" billing surprise reddit
```

### Source priority

1. Vendor pricing page (canonical URL) at access date.
2. Vendor pricing history — Wayback Machine snapshots quarterly for last 2 years.
3. Vendor public price reductions / increases (engineering blog).
4. Independent cost-comparison sites (only as supporting; verify against vendor).
5. Reddit / HackerNews for "billing surprise" anecdata — anecdotal, follow up to vendor docs.

### Cost model components

| Component               | Always check                                 |
| ----------------------- | -------------------------------------------- |
| Per-unit price          | Per-request, per-GB, per-seat, per-vCPU-hour |
| Tier thresholds         | Free tier, growth tier, enterprise gate      |
| Included quotas         | Per tier                                     |
| Overage cost            | Per unit beyond included                     |
| Egress / network        | Often hidden, often dominant                 |
| Storage at rest         | Per-GB-month                                 |
| Redundancy multiplier   | Multi-AZ / multi-region pricing              |
| Support tier cost       | Often a percentage of base spend             |
| Ramp / commit discounts | Reserved, savings plans                      |
| Currency / region       | EU vs US vs APAC pricing differences         |

### Hidden-fee detection

Look explicitly for: data egress, API call surcharges, premium-region multipliers, support-tier minimums, audit-log retention, premium-encryption add-ons, dedicated-tenant premiums, "enterprise" feature gates that are on the page only at quote-only pricing.

### Deprecation pricing risk

- Has the vendor deprecated a tier and migrated users to a more expensive one in the past? (Wayback diff.)
- What is the customer's exit cost (egress + re-platform)?

### Evidence requirements

- Pricing snapshot (URL + Wayback timestamp).
- Cost model spreadsheet-style table with unit, qty assumption, per-unit, total.
- ≥ 1 historical pricing data point (12+ months ago via Wayback) to estimate trajectory.
- Egress numbers explicit and in their own line.

### Output structure

`/docs/research/cost-<vendor>.md`:

```
# <Vendor> — Pricing & Cost Research
## TL;DR per-month estimate at <usage profile>
## Pricing snapshot          # URL + Wayback timestamp
## Tier table
## Cost model                # spreadsheet-style
## Hidden fees
## Pricing history (24mo)    # Wayback diffs
## Deprecation risk
## Comparison to alternatives
## Exit cost
## Sources
```

---

## Cross-playbook conventions

- **Every doc** carries the URL+QUOTE+ACCESSED-AT+VERIFY-METHOD evidence quad per claim.
- **Every doc** ends with a `## Sources` section listing every URL cited, in order, with access date.
- **Every doc** is linked from `/docs/research/index.md` and tagged in `/docs/research/_tags.md`.
- **Re-running a playbook** on the same topic re-verifies cached claims (HEAD checks, quote-grep) and only re-queries claims that have aged past their content-type half-life (see `research-methodology.md` §7).
- **When playbooks overlap** (e.g., library evaluation + security research), produce both files and cross-link with `[[lib-name]]` ↔ `[[sec-lib-name]]`.

When the user's question doesn't fit a playbook cleanly, fall back to the **scoping-review** narrative format described in `research-methodology.md` §1.6, with PRISMA-ScR-inspired transparency about what was searched and what was excluded.
