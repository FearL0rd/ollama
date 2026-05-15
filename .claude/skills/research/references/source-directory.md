# Source Directory — Reference

> Per-domain canonical sources, authority levels, authenticity checks, and trap patterns. Authority Level 5 = primary spec / authoritative dataset / standards body. Level 1 = aggregator / SEO content. Use the highest-authority source available for any claim.

---

## 1. Software / Web Engineering

| Source                                          | Type               | Authority         | Auth check                                                         | Common Trap                                                            |
| ----------------------------------------------- | ------------------ | ----------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| WHATWG Living Standards (HTML, DOM, Fetch, URL) | Spec               | 5                 | URL must be `spec.whatwg.org`; "Living Standard" header present    | Mid-2010s WHATWG/W3C HTML5 forks — verify which body's text is current |
| W3C Recommendations                             | Spec               | 5                 | URL `www.w3.org/TR/`; status "Recommendation" or "Living Standard" | Notes / WGs / Drafts cited as if Recommendations                       |
| ECMA-262 (TC39)                                 | Spec               | 5                 | `tc39.es/ecma262/` (latest) or `ecma-international.org` (yearly)   | Stage-2 proposals cited as language features                           |
| IETF RFC                                        | Spec               | 5                 | `rfc-editor.org/rfc/rfc####` or `datatracker.ietf.org`             | Obsoleted RFCs (check "Obsoleted by" header)                           |
| MDN Web Docs                                    | Vendor docs        | 5                 | `developer.mozilla.org`; check Browser Compat Data                 | Cached translations lag English by months                              |
| Microsoft Learn                                 | Vendor docs        | 5                 | `learn.microsoft.com`; published-date present                      | "Last updated" auto-bumped; verify content actually changed            |
| AWS / GCP / Azure docs                          | Vendor docs        | 5                 | Canonical vendor host; not a third-party mirror                    | Pricing pages cached aggressively; recheck on cloud.\*                 |
| GitHub source repository (official)             | Primary            | 5                 | Verified org badge; `package.json` `repository` field matches      | Forks renamed to look official                                         |
| npm / PyPI / crates.io / RubyGems               | Registry           | 4                 | Provenance attestation (npm sigstore); maintainer badge            | Typosquats; abandoned packages with new "maintainers"                  |
| caniuse.com                                     | Compat data        | 4                 | Sources cited (BrowserStack, vendor)                               | Aggregation lag of 1–4 weeks                                           |
| Can I email                                     | Compat data        | 4                 | Cited sources                                                      | Same lag                                                               |
| MDN Browser Compat Data (BCD)                   | Compat data        | 5                 | `github.com/mdn/browser-compat-data`                               | Subfeatures sometimes incomplete                                       |
| Stack Overflow                                  | Q&A                | 3 (vote-weighted) | Score, accepted-answer flag, last-edit                             | Outdated accepted answers; new wrong answers below                     |
| GitHub Issues / Discussions (official repo)     | Primary discussion | 4                 | In-repo, by maintainers                                            | Closed-without-resolution; comment threads cherry-picked               |
| RFC drafts (`draft-*`)                          | Working doc        | 3                 | `datatracker.ietf.org/doc/draft-*`; expiration date                | Cited as if RFC after expiration                                       |
| Vendor blog                                     | Secondary          | 3                 | Author bio with role; date present                                 | Marketing prose; future-tense roadmap as fact                          |
| Dev.to / Medium / Hashnode                      | Tertiary           | 1–2               | Author profile, sources cited                                      | AI-generated; unverified code samples                                  |

### Republication networks in software

The largest republication network is the SEO tutorial farm: `geeksforgeeks.org`, `tutorialspoint.com`, `freecodecamp.org` (mostly OK but variable), `medium.com/@*`, `dev.to/*`, plus dozens of `*-tutorials.dev`, `learn-*.com` and `coding-*.io` shells. They republish identical content with light paraphrase; the _first_ publication is rarely on these sites — it is on the vendor's docs, the maintainer's GitHub, or a conference talk. Always trace upstream.

A second category is the **AI-generated framework explainer** (post-2023): "Top 10 React Server Components in 2025" articles that hallucinate APIs and conflate React versions. Detect via §10.

A third is the **vendor-funded comparison post**: "Why we picked X over Y" written by a partner / investor. Check the page footer / About for sponsorship.

---

## 2. UX / Design

| Source                                 | Type          | Authority | Auth check                                               | Common Trap                                                        |
| -------------------------------------- | ------------- | --------- | -------------------------------------------------------- | ------------------------------------------------------------------ |
| Baymard Institute                      | Research firm | 5         | `baymard.com`; benchmark report ID                       | Paywalled detail; cite teaser quote + report number                |
| Nielsen Norman Group                   | Research firm | 5         | `nngroup.com`; author bio links to staff page            | "Articles" 1995–2005 still cited; check if updated                 |
| Interaction Design Foundation (IxDF)   | Education     | 4         | `interaction-design.org`; primary citations in body      | Encyclopedia-style entries can be too general                      |
| W3C WAI ARIA Authoring Practices (APG) | Spec/Pattern  | 5         | `w3.org/WAI/ARIA/apg/`; matches ARIA 1.2/1.3             | APG patterns updated more frequently than ARIA spec — note version |
| WCAG (2.1 / 2.2)                       | Spec          | 5         | `w3.org/TR/WCAG2*/`; Recommendation status               | Quoting WCAG 2.0 when 2.1/2.2 supersede                            |
| Deque University / axe docs            | Accessibility | 5         | `dequeuniversity.com`, `deque.com/axe`                   | Axe-core rule changes between versions                             |
| Material Design 3                      | Design system | 5         | `m3.material.io`; component spec page                    | Material 2 examples mixed in; verify M3                            |
| Apple HIG                              | Design system | 5         | `developer.apple.com/design/human-interface-guidelines/` | iOS-version-specific guidance                                      |
| Microsoft Fluent 2                     | Design system | 5         | `fluent2.microsoft.design`                               | Fluent 1 vs 2 terminology drift                                    |
| Shopify Polaris                        | Design system | 5         | `polaris.shopify.com`                                    | Internal-only patterns excluded from public                        |
| IBM Carbon                             | Design system | 5         | `carbondesignsystem.com`                                 | React vs Vue vs vanilla parity gaps                                |
| Atlassian Design System                | Design system | 4         | `atlassian.design`                                       | Atlassian-product-specific guidance                                |
| Smashing Magazine                      | Editorial     | 3         | Author bylines; references in body                       | Commercial sponsor disclosure variable                             |
| A List Apart                           | Editorial     | 4         | Established editorial process                            | Older articles (pre-2018) often outdated                           |
| UX Planet / UX Collective (Medium)     | Editorial     | 1–2       | Author bio                                               | Anyone can publish; no editorial gating                            |
| Dribbble / Behance                     | Visual ref    | 2         | Designer profile                                         | Aspirational mockups, not production patterns                      |

### Republication networks in UX

The "10 best UX patterns of 2025"-style article cluster on Medium publications (`UX Collective`, `UX Planet`, `Bootcamp`) — these are _editor-curated but not peer-reviewed_. Treat as inspiration, cross-check claims against NN/g or Baymard before citing.

Image-heavy boards (Dribbble, Behance, Pinterest) show one-off concept work, not validated production UI. Never cite a Dribbble shot as evidence of a pattern's effectiveness.

---

## 3. Academic

| Source                  | Type         | Authority | Auth check                                                               | Common Trap                                          |
| ----------------------- | ------------ | --------- | ------------------------------------------------------------------------ | ---------------------------------------------------- |
| DOI via Crossref        | Identifier   | 5         | `GET https://api.crossref.org/works/{doi}` returns 200; metadata matches | Hallucinated DOIs; Crossref returns 404              |
| ORCID                   | Author ID    | 5         | `https://orcid.org/{0000-0000-0000-0000}` resolves; affiliation matches  | Multiple authors with same name; ORCID disambiguates |
| PubMed (NLM)            | Index        | 5         | PMID resolves; MEDLINE-indexed                                           | "Indexed for MEDLINE" vs "as supplied by publisher"  |
| arXiv                   | Preprint     | 4         | `arxiv.org/abs/{id}`; check if peer-reviewed since                       | Withdrawn papers; v1 vs vN                           |
| bioRxiv / medRxiv       | Preprint     | 3         | URL resolves; "Peer review status" banner                                | Preprints contradicted in peer review                |
| Semantic Scholar        | Index        | 4         | API at `api.semanticscholar.org/graph/v1`                                | Auto-extracted citations sometimes wrong             |
| Google Scholar          | Index        | 3         | Search only; verify source                                               | Includes predatory journals; no quality filter       |
| Scopus / Web of Science | Index        | 5         | Subscription DBs; CiteScore / Impact Factor                              | Paywalled; coverage gaps in newer fields             |
| ResearchGate            | Hosting      | 2         | Not a peer-review venue                                                  | Self-uploaded copies — go to publisher of record     |
| OSF Preregistration     | Process      | 5         | `osf.io/{id}`; date-stamped                                              | Preregistration ≠ publication                        |
| Crossref Funders        | Funding meta | 4         | API endpoint                                                             | Disclosure may be incomplete                         |
| Retraction Watch        | Vigilance    | 5         | `retractionwatch.com`; PubPeer link                                      | Always check whether a citation has been retracted   |

### DOI verification protocol

```
GET https://api.crossref.org/works/{doi}
→ 200 with .message.title matching cited title
→ 200 with .message.author array matching cited author(s)
→ 200 with .message.published.date-parts[0][0] matching cited year
→ .message.type indicates "journal-article" / "book-chapter" / etc.

If any mismatch → flag "citation-DOI mismatch"
If 404           → flag "fabricated-DOI" (high prior on hallucination)
```

For non-DOI sources, fall back to Semantic Scholar's `paperId` lookup or a Google Scholar `"<exact title>"` search; if nothing returns, the citation is suspect.

### ORCID verification

`https://pub.orcid.org/v3.0/{orcid}/person` returns JSON with `name.given-names`, `name.family-name`, and `employments`. Match against cited author + affiliation.

---

## 4. Business / Market

| Source                              | Type            | Authority | Auth check                               | Common Trap                                       |
| ----------------------------------- | --------------- | --------- | ---------------------------------------- | ------------------------------------------------- |
| Gartner Magic Quadrant              | Analyst report  | 5         | Report ID; publication date              | Quadrant positions shift annually — cite the year |
| Gartner Hype Cycle                  | Analyst report  | 5         | Report ID; date                          | "Trough" position used as opinion vs methodology  |
| Forrester Wave                      | Analyst report  | 5         | Report title/year/segment                | Vendor "Leader" status without scoring detail     |
| IDC MarketScape                     | Analyst report  | 5         | Report ID                                | Same as above                                     |
| HBR / MIT Sloan / Strategy+Business | Editorial       | 4         | Editorial process; peer commentary       | Opinion pieces vs research-backed                 |
| McKinsey / BCG / Bain insights      | Consultancy     | 4         | On firm domain                           | Marketing-flavored; check for primary data        |
| CB Insights                         | Market data     | 4         | Subscription tier; author                | Aggregated startup data has lag                   |
| PitchBook / Crunchbase              | Data            | 4         | Profile shows source citations           | User-edited fields can be stale                   |
| a16z / Sequoia / Bessemer           | VC research     | 3         | On firm domain                           | Conflicts of interest with portfolio              |
| Statista                            | Data aggregator | 3         | Cited sources at chart bottom            | Aggregator — go to primary survey                 |
| Public 10-K / 10-Q (SEC)            | Primary         | 5         | SEC EDGAR `sec.gov/cgi-bin/browse-edgar` | Forward-looking statements not facts              |
| Earnings call transcripts           | Primary         | 4         | Seeking Alpha / company IR               | Unscripted commentary cherry-picked               |

### Gartner / Forrester naming conventions

- **Gartner Magic Quadrant for {Category}, {Year}** — e.g., "Gartner Magic Quadrant for Cloud AI Developer Services, 2024".
- **Forrester Wave™: {Category}, Q{N} {Year}** — e.g., "The Forrester Wave™: Customer Data Platforms, Q3 2024".

When citing, always include the year/quarter; positions and methodology change.

### Republication networks in business

Press releases distributed via PR Newswire, BusinessWire, GlobeNewswire are republished by hundreds of outlets verbatim. A "story" appearing on 50 sites within an hour is a press release; trace to the issuer and treat as company-stated, not journalist-verified.

---

## 5. News / Current Events

| Source                              | Type                | Authority | Auth check                                    | Common Trap                                                         |
| ----------------------------------- | ------------------- | --------- | --------------------------------------------- | ------------------------------------------------------------------- |
| Reuters                             | Wire                | 5         | `reuters.com`; bylined                        | Paywall; check archive.org                                          |
| Associated Press                    | Wire                | 5         | `apnews.com`                                  | Same                                                                |
| AFP                                 | Wire                | 5         | `afp.com`                                     | French original > syndicated translations                           |
| The New York Times                  | Newspaper of record | 5         | `nytimes.com`; corrections page               | Op-eds vs news section                                              |
| Wall Street Journal                 | Newspaper           | 5         | `wsj.com`                                     | Editorial vs newsroom                                               |
| Financial Times                     | Newspaper           | 5         | `ft.com`                                      | Lex column = opinion                                                |
| The Economist                       | Magazine            | 5         | `economist.com`                               | Anonymous bylines; institutional voice                              |
| The Washington Post                 | Newspaper           | 5         | `washingtonpost.com`                          | Same as NYT                                                         |
| The Guardian                        | Newspaper           | 4         | `theguardian.com`; Editor's Code of Practice  | UK/US edition divergence                                            |
| BBC News                            | Broadcaster         | 4         | `bbc.com/news`; editorial guidelines          | Older URLs sometimes redirect to summaries                          |
| Axios                               | Digital             | 4         | Bylines                                       | Smart Brevity favors summary over nuance                            |
| The Verge / Ars Technica            | Tech press          | 4         | `theverge.com`, `arstechnica.com`             | Vendor relationships disclosed inconsistently                       |
| Wayback Machine                     | Archive             | 5         | `web.archive.org/web/{ts}/{url}`              | Some pages blocked from archiving                                   |
| archive.today                       | Archive             | 4         | `archive.ph`                                  | Less complete than Wayback                                          |
| Snopes / PolitiFact / FactCheck.org | Fact-check          | 4         | IFCN signatory list                           | Politically scrutinized — cite for sourcing chain not verdict alone |
| AllSides                            | Bias rating         | 3         | `allsides.com`; methodology page              | Coarse left/center/right; one input among many                      |
| Ad Fontes Media                     | Bias rating         | 3         | `adfontesmedia.com`; bias × reliability chart | Same                                                                |

### Wire-vs-primary chain

Newsroom story chain typically: event → wire (Reuters/AP) → newspaper of record → trade press → aggregator → social. Earlier in chain = closer to primary. When citing a fast-breaking story, prefer the wire source over downstream rewrites.

For fact-disputes: Snopes / PolitiFact / FactCheck cite their _sources_ — those are what to cite, not the fact-check verdict by itself.

---

## 6. Technical Standards

| Source             | Type          | Authority | Auth check                                           | Common Trap                                                                 |
| ------------------ | ------------- | --------- | ---------------------------------------------------- | --------------------------------------------------------------------------- |
| ISO                | Standards     | 5         | `iso.org/standard/{id}.html`; status "Published"     | Paywalled; cite by `ISO/IEC NNNN-N:YYYY`. Withdrawn standards still indexed |
| IEC                | Standards     | 5         | `webstore.iec.ch`                                    | Joint ISO/IEC standards have dual numbers                                   |
| IEEE               | Standards     | 5         | `standards.ieee.org`; status                         | "Active" vs "Superseded"                                                    |
| NIST               | Pubs          | 5         | `nvlpubs.nist.gov` (free); SP / FIPS / IR series     | Withdrawn SPs (e.g., NIST SP 800-63 generations)                            |
| W3C                | Web standards | 5         | `w3.org/TR/`; status header                          | Note vs Working Draft vs Recommendation                                     |
| IETF               | Internet      | 5         | `datatracker.ietf.org`; RFC status                   | Obsoleted by / Updates by                                                   |
| OASIS              | Standards     | 5         | `oasis-open.org`; standards page                     | Consortium standards vs ISO-ratified                                        |
| ECMA International | Standards     | 5         | `ecma-international.org/publications-and-standards/` | ECMA-262 numbered yearly (ES2024 etc.)                                      |
| Unicode Consortium | Char encoding | 5         | `unicode.org`; UAX number                            | Version pinning matters (UTS #39, etc.)                                     |

### Citation format

`{Body} {Number}{:Year}, "{Title}", §{section}` — e.g., "ISO/IEC 27001:2022 §6.1.2" or "RFC 9110 §6.4".

To verify a number is _current_:

1. Visit the standard's landing page on the issuing body's site.
2. Check status: "Published" / "Active" / "Recommendation".
3. Look for "superseded by" / "obsoleted by" notices.
4. Cross-check the publication year matches the citation.

---

## 7. Open Data

| Source                | Type         | Authority | Auth check                             | Common Trap                                     |
| --------------------- | ------------ | --------- | -------------------------------------- | ----------------------------------------------- |
| data.gov (US)         | Catalog      | 5         | `data.gov`; agency-published           | Catalog entries can lag underlying data         |
| Eurostat              | Statistical  | 5         | `ec.europa.eu/eurostat`                | EU-aggregate vs member-state divergence         |
| World Bank Open Data  | Statistical  | 5         | `data.worldbank.org`; methodology link | Country classifications change                  |
| OECD                  | Statistical  | 5         | `data.oecd.org`                        | Membership changes affect aggregates            |
| UN Data               | Statistical  | 5         | `data.un.org`                          | Reporting countries vary                        |
| US BLS / BEA / Census | Statistical  | 5         | `bls.gov`, `bea.gov`, `census.gov`     | Series IDs change between methodology revisions |
| FRED (Fed St. Louis)  | Series store | 5         | `fred.stlouisfed.org`; series ID       | Discontinued series still indexed               |
| GitHub awesome-lists  | Aggregator   | 2         | Last commit date                       | Often stale                                     |
| Kaggle Datasets       | Aggregator   | 3         | Author + license                       | User-uploaded; verify provenance                |

---

## 8. Patents

| Source           | Type          | Authority | Auth check                            | Common Trap                        |
| ---------------- | ------------- | --------- | ------------------------------------- | ---------------------------------- |
| USPTO            | Patent office | 5         | `patents.uspto.gov`; Patent Number    | Application vs grant; check status |
| EPO Espacenet    | Patent search | 5         | `worldwide.espacenet.com`             | Family vs single-jurisdiction      |
| WIPO PATENTSCOPE | Patent search | 5         | `patentscope.wipo.int`                | PCT publication ≠ national grant   |
| Google Patents   | Mirror        | 4         | `patents.google.com`                  | OCR errors; check the official PDF |
| Lens.org         | Index         | 4         | `lens.org`; aggregates USPTO/EPO/WIPO | Indexing lag                       |

---

## 9. Legal

| Source                          | Type         | Authority | Auth check                                 | Common Trap                             |
| ------------------------------- | ------------ | --------- | ------------------------------------------ | --------------------------------------- |
| US: Federal Register            | Regulations  | 5         | `federalregister.gov`                      | Proposed vs final rules                 |
| US: Code of Federal Regulations | Codified     | 5         | `ecfr.gov`                                 | eCFR is current; printed CFR lags       |
| US: CourtListener / RECAP       | Court docs   | 5         | `courtlistener.com`                        | District vs circuit precedential weight |
| US: PACER                       | Court docs   | 5         | `pacer.uscourts.gov` (paid)                | Sealed docs not visible                 |
| US: SCOTUS                      | Court        | 5         | `supremecourt.gov`; slip opinion           | Slip opinion vs final reporter          |
| EU: EUR-Lex                     | EU law       | 5         | `eur-lex.europa.eu`; CELEX number          | Directives need national transposition  |
| UK: Legislation.gov.uk          | UK law       | 5         | `legislation.gov.uk`; "in force" indicator | Pre-Brexit retained EU law              |
| FindLaw / Justia                | Mirror       | 3         | Cite primary, link to mirror               | Outdated annotations                    |
| Westlaw / LexisNexis            | Subscription | 5         | Subscription DBs                           | Paywalled; cite primary                 |

---

## 10. AI Content Red Flags

Detectable signs that a "source" is LLM-generated and therefore not citable:

| Signal                           | Indicator                                                                                                    |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Over-clean prose                 | No typos, no asides, no informalisms; uniformly mid-register                                                 |
| Hallucinated citations           | Authors with no other publications; DOIs that don't resolve in Crossref; journals slightly mis-named         |
| Perfectly balanced bullets       | Every bullet identical word-count and structure; suspiciously parallel                                       |
| Em-dash overuse                  | Em-dashes connecting clauses where humans would use commas or periods                                        |
| "It's important to note that..." | This phrase, "delve into", "in today's fast-paced world", "navigate the complexities", "tapestry", "elevate" |
| Generic byline                   | "Staff writer", "Editorial Team", no headshot, no author archive                                             |
| No primary quotes                | No interviews, no transcripts, no direct quotation of a source person                                        |
| No screenshots / figures         | All-text article on a topic that should have visual evidence                                                 |
| Dates with no method             | "Recent studies show..." with no citation                                                                    |
| Rebranded paraphrase             | Article structure matches another article exactly; words are swapped synonyms                                |
| No author expertise              | Byline links to a profile with 200 articles across 30 unrelated topics in 6 months                           |
| Comments section disabled        | Or filled with bot replies that match article style                                                          |
| Site infrastructure              | Generic CMS theme, no About page with names, registration recent (`whois`)                                   |
| Suspicious uniformity            | All articles on the site published exactly weekly, same length, same tone                                    |

When in doubt, run a distinctive 8–12-word string from the article through a quoted Google search. If it appears verbatim across many sites: republication. If it appears nowhere else: novel — but check author credibility before citing.

A useful heuristic: an LLM-generated article _summarizes_ but does not _report_. If the article cannot answer "where did this fact come from", it is not a source — it is an aggregation of sources, and you must trace upstream.

---

## 11. Authenticity Checks Cheat Sheet

```
URL resolves (HTTP 200/301)         → curl -I {url}
DOI in Crossref                     → curl https://api.crossref.org/works/{doi}
ORCID + affiliation match           → curl https://pub.orcid.org/v3.0/{orcid}/person
Quote-in-source                     → fetch page; grep -F "{quote}"
Wayback first-seen                  → https://web.archive.org/web/*/{url}
Author publication history          → Semantic Scholar / Google Scholar by name
Publisher reputation                → Beall's List archive; DOAJ for OA journals
Site WHOIS                          → whois {domain}; check creation date
Republication detection             → quoted Google search of distinctive phrase
Image provenance                    → reverse image search (Google / TinEye)
Screenshot evidence                 → Playwright `browser_take_screenshot`
```

The research-verify agent runs the first four on every claim. The remainder are escalations when the first four are ambiguous.
