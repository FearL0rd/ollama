---
name: claude-seo
description: "ALWAYS invoke when doing SEO analysis, audits, schema markup, sitemaps, or content optimization. Do NOT skip SEO checks when building public-facing pages or marketing content."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# SEO Analysis

Comprehensive SEO analysis for any website or business type.

> Source: `AgriciDaniel/claude-seo` (adapted for project conventions)

## Commands

| Command | What it does |
|---------|-------------|
| `/seo audit <url>` | Full website audit with parallel analysis |
| `/seo page <url>` | Deep single-page analysis |
| `/seo sitemap <url>` | Analyze or generate XML sitemaps |
| `/seo schema <url>` | Detect, validate, and generate Schema.org markup |
| `/seo images <url>` | Image optimization analysis |
| `/seo technical <url>` | Technical SEO audit (crawlability, indexability, CWV) |
| `/seo content <url>` | E-E-A-T and content quality analysis |
| `/seo geo <url>` | AI Overviews / Generative Engine Optimization |
| `/seo plan <type>` | Strategic SEO planning by business type |

## SEO Health Score (0-100)

| Category | Weight |
|----------|--------|
| Technical SEO | 25% |
| Content Quality (E-E-A-T) | 25% |
| On-Page SEO | 20% |
| Schema / Structured Data | 10% |
| Performance (Core Web Vitals) | 10% |
| Images | 5% |
| AI Search Readiness | 5% |

## Industry Detection

- **SaaS**: pricing page, /features, /docs, "free trial"
- **Local Service**: phone, address, service area, Google Maps
- **E-commerce**: /products, /cart, "add to cart", product schema
- **Publisher**: /blog, /articles, article schema, author pages
- **Agency**: /case-studies, /portfolio, client logos

## Audit Workflow

1. Detect business type from homepage signals
2. Run parallel analysis: technical, content, schema, sitemap, performance
3. Generate unified report with SEO Health Score
4. Create prioritized action plan (Critical → High → Medium → Low)

## Priority Levels

- **Critical**: Blocks indexing or causes penalties (immediate fix)
- **High**: Significantly impacts rankings (fix within 1 week)
- **Medium**: Optimization opportunity (fix within 1 month)
- **Low**: Nice to have (backlog)

## Quality Gates

- Never recommend HowTo schema (deprecated Sept 2023)
- FAQ schema only for government and healthcare sites
- All Core Web Vitals references use INP, never FID
- Warn at 30+ location pages (enforce 60%+ unique content)
- Hard stop at 50+ location pages (require user justification)

## AI Search Readiness (GEO)

Check accessibility for AI crawlers:
- GPTBot, ClaudeBot, PerplexityBot in robots.txt
- llms.txt compliance
- Brand mention signals
- Passage-level citability

## Critical Rules

1. **INP not FID** — FID is deprecated, always use INP for Core Web Vitals
2. **No HowTo schema** — Deprecated since Sept 2023
3. **E-E-A-T framework** — Experience, Expertise, Authoritativeness, Trustworthiness
4. **Parallel analysis** — Run all audit categories simultaneously
5. **Business-type aware** — Tailor recommendations to industry
6. **GEO included** — Always check AI search readiness alongside traditional SEO
