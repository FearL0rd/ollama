# Market research playbook for the super-design skill

> Reference document for `.claude/agents/sd-research.md`. Bundle path: `references/market-research-playbook.md`. Everything below is prescriptive guidance for an autonomous Market Research subagent that must determine a project's niche, find competitors, audit their design language, and ship a defensible `market-analysis.md` — **without any user-supplied context**.

The agent's contract: given only a repository path, produce evidence-backed positioning recommendations. Every claim must cite a source (file path + line, or URL + quote). When evidence is insufficient, the agent says so rather than inventing. The ten sections below move from inference (what is this repo?) to synthesis (what should this brand become?) and close with the ready-to-paste agent file.

---

## 1. Niche and industry detection from a repo

The repo is a fingerprint. A modern software project leaks its vertical, audience, and design posture through eight independent signals. Score each, combine with weights, and only ask the user when confidence stays below threshold.

### 1.1 The eight signal layers (in order of signal strength)

1. **`package.json` dependencies and devDependencies** — highest signal density per byte. UI kits, auth, payments, and CMS packages are near-deterministic.
2. **Manifest files** — `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`, `composer.json`, `pubspec.yaml`, `foundry.toml`, `hardhat.config.ts`, `anchor.toml`, `dbt_project.yml`, `ProjectVersion.txt` (Unity).
3. **`README.md`** — natural-language value prop, target user, and domain lexicon. Parse the first 500 words, H1, and any badges.
4. **`CLAUDE.md` / `AGENTS.md`** — if present, the author has already summarized intent for an AI. Treat as highest-trust signal short of user confirmation.
5. **Source tree domain entities** — directory names (`src/billing`, `src/merchants`, `app/dashboard`, `prisma/schema.prisma` models, `app/api/webhooks/stripe/route.ts`).
6. **`tailwind.config.*` or `@theme` block** — brand colors, fonts, radius reveal existing design posture.
7. **i18n locales** — `zh-CN`, `ja`, `ko` → APAC; `de`, `fr`, `es`, `pt` → EU/LATAM; `en` only → US-default.
8. **CI/infra hints** — Helm charts and Kubernetes clients point at platform-engineering audiences; `vercel.json`/`netlify.toml` at modern frontend indie.

### 1.2 Dependency → vertical lookup (core mappings)

Every match contributes `weight` to a vertical score and an audience score. Final niche = top vertical; audience = top audience score.

**Payments and commerce.** `stripe`, `@stripe/*`, `paddle`, `lemonsqueezy` → payments/SaaS (weight ~0.9). `@shopify/polaris` + `@shopify/app-bridge` → Shopify App Store app (weight 0.99, near-certain). `@medusajs/medusa` or `@saleor/sdk` → headless commerce.

**AI tooling.** `langchain`, `llamaindex`, `@anthropic-ai/sdk`, `openai`, `@ai-sdk/*` → AI/LLM vertical (0.9–0.95). Vercel AI SDK (`ai`, `@ai-sdk/react`) is the dominant fingerprint of a chat product. Vector DBs (`@pinecone-database/pinecone`, `chromadb`, `@qdrant/js-client-rest`, `weaviate-ts-client`) signal RAG infra.

**Auth as audience signal.** `@clerk/nextjs` → modern B2B SaaS. `@workos-inc/*` → enterprise SSO B2B. `auth0` → enterprise. `next-auth`/`better-auth`/`lucia` → indie. `firebase-auth` → consumer.

**CMS.** `sanity`/`next-sanity` → editorial/agency. `contentful` → enterprise marketing. `payload` → TS fullstack CMS. `@storyblok/react` or `@prismicio/client` → EU marketing.

**Mobile.** `expo` + `nativewind` + `@supabase/supabase-js` → consumer mobile indie. `@shopify/*` in RN → merchant companion.

**UI kit = audience signal (strong).** `@mui/material` → enterprise/Google-ecosystem. `@chakra-ui/react` → mid-market US SaaS. `@mantine/core` → indie dev tools. `@radix-ui/*` + `class-variance-authority` + `tailwind-merge` → shadcn/ui indie modern. `antd` / `@arco-design/web-react` / `@douyinfe/semi-ui` / `tdesign-react` → China-tech enterprise. `@fluentui/react` → Microsoft-ecosystem. `@carbon/react` → IBM enterprise. `@shopify/polaris` → Shopify app. `react-bootstrap` → legacy enterprise.

**Motion and 3D.** `gsap` + `lenis` + `three` + `@react-three/fiber` → premium marketing/agency (0.9+). `framer-motion` alone is weak (ubiquitous).

**Web3.** `wagmi` + `viem` + `@rainbow-me/rainbowkit` → consumer dApp. `@solana/web3.js` → Solana DeFi. `hardhat`/`foundry` → smart-contract dev tool.

**Analytics tone.** `posthog-js` → PLG product-team. `@segment/analytics-next` + `@amplitude/analytics-browser` → data-mature SaaS. `plausible-tracker` → privacy indie.

**Data/ML.** `dbt-core` + `dagster` + `duckdb` → modern data stack vendor. `torch`/`tensorflow`/`transformers` → ML research/product.

### 1.3 Composite stack fingerprints

Certain dependency co-occurrences collapse ambiguity instantly:

| Co-occurrence | Inferred positioning |
|---|---|
| `next` + `tailwindcss` + `@radix-ui/*` + `cva` + `tailwind-merge` + `lucide-react` | shadcn indie SaaS, dev-forward B2B |
| `next` + `@mui/material` + `@mui/x-data-grid` + `auth0` | enterprise admin/dashboard |
| `next` + `@chakra-ui/react` | mid-market US SaaS |
| `next` + `antd` + `dayjs` | China-tech enterprise |
| `next` + `ai` + `@ai-sdk/*` + `@vercel/kv` | AI chat product, Vercel stack |
| `next` + `stripe` + `@clerk/*` + `drizzle-orm` | the canonical "2024–2026 indie B2B SaaS" stack |
| `next` + `@sanity/client` + `@portabletext/react` | editorial / content-led |
| `next` + `gsap` + `three` + `lenis` | premium agency marketing site |
| `expo` + `nativewind` + `@supabase/*` | indie consumer mobile |
| `wagmi` + `viem` + `@rainbow-me/rainbowkit` | consumer web3 dApp |

### 1.4 Semantic signals from README and CLAUDE.md

Parse the README's H1, first paragraph, and "Features" or "Why" section. Extract:

- **Value-prop verb** (the first active verb: "ship", "track", "analyze", "automate", "generate", "protect"). Maps to JTBD functional job.
- **Audience noun** ("for developers", "for marketers", "for growing teams", "for enterprises"). Direct B2B/B2C classifier.
- **Comparative mentions** ("an open-source alternative to X", "like Y for Z") — free competitor seeds.
- **Pricing model language** ("free forever", "self-hosted", "enterprise-grade", "usage-based") — positioning tier.
- **Badge inventory** — MIT/Apache licence, `npm version`, CI status, Discord, Product Hunt. Discord badge in README has >70% correlation with dev-tool/indie positioning.

### 1.5 Source-tree entity scan

Use `Glob` over `**/*.{ts,tsx,py,rb,go}` restricted to `src|app|server|api|models|schemas` (≤300 files). For each file, extract the top-level class/interface/model name and Route path. Cluster by stem. A repo with `Invoice`, `Subscription`, `Payout`, `CustomerPortal` is ecommerce/billing; one with `Document`, `Collection`, `Workspace`, `Block` is productivity; one with `Agent`, `Prompt`, `Tool`, `Trace` is AI tooling; one with `Campaign`, `Segment`, `Broadcast`, `Template` is marketing.

### 1.6 Tailwind/`@theme` brand read

Open `tailwind.config.{ts,js,mjs}` and grep for `extend.colors.primary`, `fontFamily`, `borderRadius`. For Tailwind v4 projects, the brand now lives in `@theme { --color-primary: …; --font-sans: …; --radius: …; }` inside `globals.css`. Extract primary hex → HSL; saturation >60 + lightness 40–60 = energetic; saturation <25 = premium or minimalist.

### 1.7 When to confirm vs infer silently

Compute confidence as `top_vertical_score / (top_vertical_score + second_vertical_score)`.

- **≥ 0.75**: infer silently, document reasoning in `evidence/niche.md`.
- **0.55–0.75**: infer but add a one-line "Detected niche: X (medium confidence; also consistent with Y). Override?" banner at the top of the output.
- **< 0.55**: use `AskUserQuestion` with three concrete options derived from the top three verticals. Never ask open-endedly — always offer options.
- **Always confirm** for regulated niches: fintech, healthtech, legal, gambling, crypto (regulatory design codes are strict; a wrong inference wastes work).

---

## 2. Competitor discovery strategies

Goal: produce a ranked list of **5–10 competitors** per project — enough for category-code analysis, few enough that deep audits stay tractable.

### 2.1 The seven-source crawl

Run these in parallel and dedupe by domain. Expect ~40–80 raw candidates collapsing to 5–10 after ranking.

1. **Search operators** (via `WebSearch`): `"alternatives to <seed>"`, `"<seed> vs"`, `"best <niche> for <audience>"`, `"open source <niche>"`, `intext:"powered by <seed>"`. The "powered by" operator uniquely surfaces customers-as-competitors.
2. **Product Hunt** (`https://www.producthunt.com/topics/<slug>` and GraphQL API at `api.producthunt.com/v2/api/graphql`). Topic slugs: `developer-tools`, `artificial-intelligence`, `saas`, `marketing`, `design-tools`, `no-code`, `fintech`, `productivity`. Sort by `VOTES` in last 12 months for current relevance.
3. **G2 / Capterra / TrustRadius** — category pages at `g2.com/categories/<slug>`, `capterra.com/categories/<slug>`, `trustradius.com/categories`. G2's `/products/<slug>/competitors` page returns a curated peer list. Respect robots.txt; scrape with `WebFetch`.
4. **Y Combinator directory** at `ycombinator.com/companies` with filters `batch`, `industry`, `subindustry`. Powered by an Algolia backend (`45bwzj1sgc-dsn.algolia.net`) — the search box is directly scriptable.
5. **Awesome-\* GitHub lists**: `api.github.com/search/repositories?q=awesome+<niche>+in:name+stars:>500` then `WebFetch` the top list's README.
6. **Reddit + Hacker News**. Reddit JSON: `reddit.com/search.json?q=%22alternatives+to+<seed>%22&sort=new&limit=100`. HN Algolia (no auth): `hn.algolia.com/api/v1/search?query=<seed>+alternative&tags=story`. Threads titled "Ask HN: alternatives to …" are gold.
7. **Backlink / similar-sites** — `similarweb.com/website/<domain>` "Competitors & Alternatives" tab and `similarsites.com/site/<domain>`. `builtwith.com/<domain>` and `trends.builtwith.com/websitelist/<tech>` expose other sites on the same stack (often real competitors).

Supplementary signals: **Twitter/X** queries like `"switched from <seed> to"`, `"moved off <seed>"`, `"instead of <seed>"`; **Google autocomplete** via `suggestqueries.google.com/complete/search?client=firefox&q=<query>`; **SparkToro** for audience overlap.

### 2.2 Ranking and selection decision tree

Given raw candidates, select the final 5–10:

1. **Filter for live**: domain resolves, site responds in <10s, copyright year within two years. Drop zombies.
2. **Bucket by posture**, aiming for representation in each:
   - **Category king** (1–2): the incumbent every buyer considers. Highest G2 review count or most-mentioned in "alternatives to" searches.
   - **Direct peers** (2–4): same audience, same core JTBD, similar stage (±1 funding round).
   - **Adjacent/challenger** (1–2): same audience, different value prop or opposite posture (open-source vs proprietary; all-in-one vs focused).
   - **Emerging/indie** (1–2): Product Hunt last-6-months top 10 in the category; reveals the design-language future.
   - **Enterprise anchor** (1): the "safe corporate" option — reveals category conventions.
3. **Score** each candidate: `fame = log(g2_reviews + ph_upvotes + 1)`; `similarity = jaccard(audience_tokens)`; `design_signal = has_modern_site ? 1 : 0`. Rank by `0.5·fame + 0.4·similarity + 0.1·design_signal`.
4. **Final gate**: the set must include at least one brand from each vibe quadrant the agent believes is plausibly applicable, so category-code analysis has variance to measure.

### 2.3 The "only competitor that matters" test

Before finalizing, run Neumeier's insertion test: drop each competitor's name into the project's draft onliness statement ("Our X is the only X that Y"). If the statement still holds with the competitor's name substituted, that competitor shares the same position — include it. If no competitor fits the statement, the project's position is either unique (good) or underspecified (needs work).

---

## 3. Extracting brand and design language from competitors

For each finalist competitor, visit four pages: homepage, primary product page, pricing, about. Playwright MCP (via `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_evaluate`) drives everything.

### 3.1 Browser setup

```ts
// Launch headless chromium at 1440×900 @2x, wait for networkidle.
await browser_navigate({ url });
await browser_resize({ width: 1440, height: 900 });
await browser_wait_for({ time: 1.5 }); // allow hero animations to settle
```

Save the full-page screenshot to `evidence/<competitor>/<page>.png` via `browser_take_screenshot({ fullPage: true, filename: ... })`.

### 3.2 Typography extraction

```js
// browser_evaluate
const counts = new Map();
for (const el of document.querySelectorAll('body *:not(script):not(style)')) {
  if (!el.innerText?.trim()) continue;
  const ff = getComputedStyle(el).fontFamily;
  counts.set(ff, (counts.get(ff) ?? 0) + 1);
}
return [...counts.entries()].sort((a,b)=>b[1]-a[1]).slice(0,20);
```

Interpret top three families: the dominant one is body; a secondary (used <5% but on h1–h2) is display; mono = dev-tool posture. Map family names to classifications: `Inter`, `Geist`, `Söhne`, `SF Pro` → modern sans; `GT Super`, `Canela`, `Tiempos`, `Editorial New`, `Playfair` → editorial serif; `Druk`, `Monument Grotesk` → brutalist/display; `JetBrains Mono`, `Berkeley Mono`, `IBM Plex Mono` → developer.

### 3.3 Color palette extraction (dual approach)

**CSS-first** captures the brand's own tokens:

```js
const hist = new Map();
for (const el of document.querySelectorAll('body *')) {
  const cs = getComputedStyle(el);
  const r = el.getBoundingClientRect();
  const w = Math.log2(Math.max(1, r.width * r.height) + 1);
  for (const [prop, weight] of [['backgroundColor',w],['color',1],['borderTopColor',.25],['fill',.5]]) {
    const v = cs[prop];
    if (v && v !== 'rgba(0, 0, 0, 0)' && v !== 'transparent') hist.set(v, (hist.get(v) ?? 0) + weight);
  }
}
return [...hist.entries()].sort((a,b)=>b[1]-a[1]).slice(0,30);
```

Cluster by RGB distance (ε≈24) and keep the top 6–8 representatives.

**Image-based** (node-vibrant) captures the palette the user actually perceives from hero photography:

```ts
import { Vibrant } from 'node-vibrant/node';
const p = await Vibrant.from('evidence/acme/home.png').getPalette();
// p.Vibrant, DarkVibrant, LightVibrant, Muted, DarkMuted, LightMuted — each has .hex, .population, titleTextColor, bodyTextColor
```

Merge: CSS palette = brand tokens; Vibrant palette = perceived mood. Divergence between them reveals aspirational vs actual brand (common in rebrand-in-progress).

### 3.4 CSS custom properties (the "design tokens" reveal)

```js
const out = {};
const cs = getComputedStyle(document.documentElement);
for (let i = 0; i < cs.length; i++) {
  const p = cs.item(i);
  if (p.startsWith('--')) out[p] = cs.getPropertyValue(p).trim();
}
return out;
```

Token-namespace fingerprints: `--primary`, `--background`, `--foreground`, `--ring` = shadcn/ui (if paired with `data-slot` attrs, confirmed). `--color-brand-500` = Tailwind v4 `@theme`. `--mui-palette-primary-main` = MUI. `--chakra-colors-brand-500` = Chakra. Radix Themes uses `--accent-9`, `--gray-3`.

### 3.5 Spacing and radius rhythm

Histogram padding/margin/gap values; compute the GCD of the top six — Tailwind projects cluster on multiples of 4, MUI on 8. Radius distribution bins (0 / ≤4 / ≤16 / >16) reveal posture: sharp-dominant = brutalist/editorial; rounded-dominant = modern SaaS; pill-dominant = playful/consumer.

### 3.6 Motion characteristics

Pull `animation`, `transition`, `transition-timing-function`, and look for `cubic-bezier` curves. Snapshot scroll-triggered behavior by calling `page.evaluate('window.scrollTo(0, 2000)')`, then a second screenshot. Network trace (`browser_network_requests`) for `.lottie`, `.glb`, GSAP, Framer Motion bundle presence.

### 3.7 Photography vs illustration

Query `document.querySelectorAll('img, svg, video')`. Count SVG children vs raster images in the hero section (first viewport). >70% SVG = illustration-led (Notion, Linear early, Stripe). >70% photo = human-centered (Webflow enterprise, HubSpot). Mixed = editorial.

### 3.8 Layout patterns to catalogue

- **Hero structure**: left-aligned vs centered; imagery-right vs full-bleed; CTA count (1 hard + 1 soft is modern SaaS default).
- **Social proof placement**: immediately under hero ("Trusted by" bar) vs after first scroll vs not at all.
- **Pricing architecture**: 3-tier cards (default), slider/calculator (usage-based), "Contact sales" only (enterprise).
- **Footer depth**: number of columns and total link count. Dense footers (>40 links) = enterprise; sparse (<12) = indie.

### 3.9 Copy harvest

```js
return {
  hero: document.querySelector('h1')?.innerText.trim(),
  subhead: document.querySelector('h1 ~ p')?.innerText.trim(),
  ctas: [...document.querySelectorAll('a[role=button], button, a.btn')].map(e => e.innerText.trim()).filter(t => t && t.length < 40).slice(0, 20),
  headings: [...document.querySelectorAll('h1,h2,h3')].map(h => h.innerText.trim()),
  allText: document.body.innerText.replace(/\s+/g,' ').slice(0, 10000),
};
```

Store verbatim for archetype scoring (§4) and tone analysis (§7).

### 3.10 Evidence file layout

```
evidence/<competitor-slug>/
  home.png        # fullPage screenshot
  product.png
  pricing.png
  about.png
  tokens.json     # CSS vars + extracted palette
  typography.json # font frequency table
  copy.json       # hero, subhead, ctas, headings, allText
  notes.md        # agent's annotations with line-referenced quotes
```

---

## 4. Brand archetype and positioning classification

### 4.1 Mark & Pearson 12 archetypes (Mark & Pearson, *The Hero and the Outlaw*, McGraw-Hill, 2001)

The archetypes cluster in four motivational quadrants. An auditable brand usually presents one primary + one supporting.

| Archetype | Core desire / motto | Visual signals | Copy signals | Example brands |
|---|---|---|---|---|
| **Innocent** | Paradise / safety. "Free to be you and me." | Pastels (white, sky blue, pale yellow); rounded sans or script; high-key photography; whitespace | Short sentences; "pure/simple/happy/natural"; gentle CTAs ("Discover", "Enjoy") | Dove, Innocent Drinks, Aveeno, Method |
| **Sage** | Truth / understanding. "The truth will set you free." | Navy/forest/burgundy + cream; classical serifs; editorial layouts; data viz; monochrome portraits | Authoritative third person; cited stats; long clauses; "Learn more", "Read the report" | Google, BBC, The Economist, Harvard, Bloomberg |
| **Explorer** | Freedom, discovery. "Don't fence me in." | Earthy palettes (rust, olive, slate); geometric sans (Futura); wide landscape hero; maps, compasses | Second person "you"; imperatives; "Find your…"; "Start the journey" | Patagonia, The North Face, Jeep, Airbnb, GoPro |
| **Outlaw** | Revolution. "Rules are made to be broken." | Black + one saturated accent (red, neon); heavy condensed/industrial type; grit textures; high contrast | Short, confrontational; anti-establishment questions; "Join the revolution" | Harley-Davidson, Diesel, Liquid Death, Oatly, Vice |
| **Magician** | Transformation. "I make things happen." | Deep purple/indigo + gold; gradient meshes; particle/glow effects; futuristic sans | "Transform", "unlock", "reveal", "imagine"; before/after demos | Disney, Tesla, Polaroid, Dyson, MasterClass |
| **Hero** | Mastery through courage. "Where there's a will there's a way." | Bold red/black/white or navy/gold; muscular sans (Knockout, Tungsten); athletes mid-motion; dramatic light | 1–3 word imperative taglines; challenge framing; "Push harder", "Rise" | Nike, Under Armour, BMW, FedEx, Adidas |
| **Lover** | Intimacy, sensual pleasure. "You're the only one." | Rich reds/burgundies/blush; Didone serifs (Didot, Bodoni); soft-focus warm light; tactile textures | Sensory adjectives; romantic syntax; "Indulge", "Fall in love" | Chanel, Victoria's Secret, Häagen-Dazs, Alfa Romeo |
| **Jester** | Live in the moment. "You only live once." | Saturated primaries (yellow, hot pink, cyan); rounded display; illustration > photo; mascots, emoji | Puns, exclamations, rhetorical Qs; "Let's play", "Get silly" | M&M's, Old Spice, Dollar Shave Club, Cards Against Humanity, Mailchimp |
| **Everyman** | Belonging. "All people are created equal." | Muted neutrals (denim, warm gray, brick); humanist sans (Helvetica, Open Sans); candid documentary photos | Plainspoken; contractions; "we/us"; "Join us", "Get started" | IKEA, Target, Levi's, Home Depot, eBay |
| **Caregiver** | Protect others. "Love your neighbor as yourself." | Soft blue/pink + white; rounded humanist sans; touching hands, parent-child imagery | Empathetic; "we're here for you"; "Care for…" | Johnson & Johnson, UNICEF, Volvo, Pampers, TOMS |
| **Ruler** | Control, prosperity. "Power is the only thing." | Black, gold, navy, burgundy; Trajan/Bodoni serifs; symmetrical layouts; crests, monograms | Superlatives ("the finest", "world's leading"); formal third person; "Become a member" | Rolex, Mercedes-Benz, AmEx (Centurion), Louis Vuitton, IBM |
| **Creator** | Realize a vision. "If you can imagine it, it can be done." | Monochrome + bold accent; experimental/custom type; whitespace; tools/process imagery | "Make/build/craft"; short aphorisms; "Create", "Build your…" | Apple, LEGO, Adobe, Figma, Canva, Etsy |

**Detection algorithm.** Score each archetype 0–10 by summing: (a) color-palette match against canonical hues; (b) typographic class match; (c) lexical match on ~20 archetype-specific tokens extracted from `copy.allText`; (d) imagery class (photo/illustration/3D match); (e) CTA verb match. Normalize; take top two. Confidence = score[0] − score[1]. Flag `mixed` if < 2.0.

### 4.2 Aaker Brand Personality Dimensions (Aaker, *Journal of Marketing Research*, 34(3):347–356, August 1997)

Five dimensions, 15 facets, 42 traits, validated against Big-Five (OCEAN). A brand typically peaks on one dimension with a strong secondary.

- **Sincerity** (down-to-earth, honest, wholesome, cheerful): warm whites/cream, sky blue, soft yellow; rounded humanist sans or friendly serif; sun-lit candid photography; kraft textures. *Examples:* Hallmark, Dove, Patagonia, Ben & Jerry's.
- **Excitement** (daring, spirited, imaginative, up-to-date): neon/saturated; bold geometric display; motion blur; asymmetric layouts; graphic illustration. *Examples:* Red Bull, MTV, Tesla, Spotify.
- **Competence** (reliable, intelligent, successful): navy + steel gray + white; grotesk sans (Helvetica, Inter); grid-based; data viz; clean product photography on white. *Examples:* IBM, Microsoft, Volvo, FedEx, WSJ.
- **Sophistication** (upper class, charming): black, ivory, gold, blush; high-contrast Didone serifs; generous whitespace; editorial fashion photography. *Examples:* Chanel, Mercedes-Benz, Tiffany & Co., Apple (premium).
- **Ruggedness** (outdoorsy, tough): earth tones; slab serifs or condensed industrial sans; wide landscapes; weathered textures; natural light. *Examples:* Levi's, Jeep, Timberland, Carhartt.

Score each dimension 1–7 by counting trait-evoking signals across home + product pages.

### 4.3 Kapferer's Brand Identity Prism (Kapferer, *Strategic Brand Management*, 1992; refined eds. through 2012)

Six facets on two axes — vertical (Picture of Sender ↔ Picture of Receiver) and horizontal (Externalization ↔ Internalization).

1. **Physique** (external/sender) — logo, colors, type, packaging, signature visual assets. *Audit:* extracted tokens (§3).
2. **Personality** (internal/sender) — the brand-as-person. *Audit:* map body copy onto Aaker or the 12 archetypes.
3. **Culture** (internal/sender) — values, heritage, ideology. *Audit:* About/Mission/Manifesto pages, origin story, ESG statements.
4. **Relationship** (external/receiver) — mode of brand↔customer conduct. *Audit:* onboarding tone, support copy, community features, promised exchange.
5. **Reflection** (external/receiver) — stereotyped user portrayed in ads (not actual buyer). *Audit:* every photo of a person: age, gender, ethnicity, lifestyle.
6. **Self-image** (internal/receiver) — how the customer feels using the brand. *Audit:* testimonial phrasing, identity-laden copy ("for those who…"), community posts.

Score each 1–5 for clarity; flag inconsistencies (e.g., Personality reads playful but Relationship copy is corporate → weak Prism).

### 4.4 Keller's CBBE pyramid (Keller, *Journal of Marketing*, 1993; MSI WP 01-107, 2001)

Four levels, asked as four questions. Audit by locating each level's cues on the competitor site.

1. **Salience** — "Who are you?" Category clarity above the fold, tagline specificity, SEO meta.
2. **Performance + Imagery** — "What are you?" Specs, certifications, comparison tables (left/rational); lifestyle photography, heritage, personality words (right/emotional).
3. **Judgments + Feelings** — "What about you?" Star ratings, expert endorsements, awards (left); emotional words in testimonials, imagery mood (right).
4. **Resonance** — "What about you and me?" Community (Discord, forum), UGC volume, referral program, repeat-purchase signals (subscriptions, memberships), advocacy.

Bottleneck analysis: score 1–5 per block; the weakest block is the brand's current ceiling.

---

## 5. Category codes analysis

Category codes are the visual and copy patterns nearly every brand in a vertical shares — the "obey for trust" signals. Differentiating is about choosing which codes to **obey**, **extend**, or **subvert** (Neumeier, *Zag*, 2006).

### 5.1 Building the competitor matrix

After §3's extraction for each of the 5–10 finalists, assemble a matrix. Rows = competitors. Columns = dimensions:

| Dimension | Cell value |
|---|---|
| Primary hex | `#0A2540` |
| Accent hex | `#635BFF` |
| Palette saturation | avg HSL S |
| Palette lightness | avg HSL L (reveals light vs dark mode default) |
| Display font class | modern-sans / editorial-serif / grotesque / mono / custom |
| Body font | computed family |
| Radius posture | sharp / subtle / rounded / pill |
| Hero layout | left-copy-right-image / centered / full-bleed / split-screen |
| Imagery | illustration / photo / 3D / hybrid / abstract |
| Motion | none / subtle / moderate / heavy-scroll-driven |
| Archetype (primary) | Sage / Creator / Hero / … |
| Aaker peak | Competence / Sophistication / Excitement / … |
| Vibe | premium / tech-futuristic / calm-corporate / etc. |
| Tone (NN/g 4D) | F-S / F-C / R-I / E-M tuple |
| Hero verb | ship / send / scale / automate / … |
| CTA pattern | hard+soft / enterprise-only / dev-docs-led |
| Social proof | trusted-by bar / testimonials / none |
| Pricing posture | 3-tier / usage / contact-sales |

### 5.2 Frequency analysis → obey/extend/subvert

For each column, compute how many of 5–10 competitors share the modal value.

- **Near-universal (≥80% share the same value)** → **category code**. Obey unless the brand is an explicit challenger. Regulated verticals (fintech, healthtech, legal) require obeying; divergence triggers mistrust.
- **Split 40–70%** → **extend**. Choose the side that aligns with archetype; add a signature twist. Evolutionary differentiation.
- **Fragmented (no mode >40%)** → **open territory**. Any choice is defensible; pick based on archetype and target audience.
- **Homogeneous on a bad code** (e.g., everyone uses stock photography) → **subvert**. Challenger brands gain memorability by violating a boring convention.

### 5.3 Byron Sharp's Distinctive Brand Assets framework (Sharp, *How Brands Grow*, OUP 2010; Romaniuk, *Building Distinctive Brand Assets*, OUP 2018)

DBAs are non-brand-name elements that trigger the brand into memory — colors, shapes, mascots, fonts, jingles, taglines, packaging. Romaniuk's Distinctive Asset Grid plots **Fame** (% of category buyers who link the asset to the brand) against **Uniqueness** (% who link it *only* to this brand).

| | Low Fame | High Fame |
|---|---|---|
| **High Uniqueness** | **Invest** — protect and build exposure | **Use or lose** — defend, deploy widely, can replace brand name |
| **Low Uniqueness** | **Test or ignore** | **Avoid/Solo** — famous but co-owned with category; competitors free-ride |

Canonical DBAs: Coca-Cola red (Pantone 484), Nike Swoosh, McDonald's Golden Arches, Tiffany Blue (PMS custom 1837), Cadbury royal purple (Pantone 2685C), Geico Gecko, Intel's five-note bong.

**Audit use**: for each competitor, inventory candidate assets; for the current project, identify one-to-three DBAs worth investing in, avoiding colors/shapes already occupied by the category king.

### 5.4 Marty Neumeier's *Zag* (2006) — finding whitespace

Neumeier's thesis: "when everybody zigs, zag." A zag must be **good** (customers value it) and **different** (surprising, fresh). Different alone = quirky failure; good alone = me-too.

**The onliness statement formula:**

> Our ___[WHAT]___ is the only ___[WHAT]___ that ___[HOW]___ for ___[WHO]___ in ___[WHERE]___ who ___[WHY]___ in an era of ___[WHEN]___.

Minimal form: "Our X is the only X that Y." Harley-Davidson worked example from the book: "Our motorcycle company is the only one that makes big, loud motorcycles for macho guys (and macho wannabes) mostly in the US who want to join a gang of cowboys in an era of decreasing personal freedom."

**Whitespace procedure:** plot competitors on a 2×2 of differentiating attribute pairs (affordable↔premium × functional↔expressive; or open-source↔proprietary × all-in-one↔focused). The unoccupied quadrants are candidate zags. Test each candidate with the insertion test: substitute any competitor's name into the onliness statement — if it still holds, the position is not unique.

### 5.5 The obey/extend/subvert rubric

For each category code identified:

1. **Obey** when: (a) the code signals safety in a trust-critical category (fintech, healthtech, legal, enterprise IT); (b) the brand is new and needs to clear the category-recognition bar; (c) deviating would confuse the buyer about what category the product is in.
2. **Extend** when: (a) the code is a split majority; (b) the brand has a supporting archetype that motivates a twist; (c) the twist preserves category legibility.
3. **Subvert** when: (a) the brand is a challenger positioning against the category leader; (b) the dominant code is genuinely boring or broken (stock photos, buzzword taglines); (c) the archetype is Outlaw, Jester, or Creator (explicitly differentiating archetypes).

---

## 6. Audience research methodologies

### 6.1 Inferring audience from copy and screenshots

The clearest signals: second-person addressing ("you" = direct user), first-person-plural pitch ("we help you" = service posture), third-person institutional ("organizations can" = enterprise B2B). CTAs are the B2B/B2C classifier: "Request a demo" / "Contact sales" / "Book a call" = B2B-enterprise. "Get started free" / "Try free for 14 days" = B2B SMB or PLG. "Sign up" / "Download the app" = consumer. Pricing visibility: public tiered = PLG; "Contact us" only = enterprise; no pricing page = pre-revenue or agency.

### 6.2 Hofstede's six cultural dimensions (Hofstede, *Culture's Consequences*, Sage 1980; Hofstede, Hofstede & Minkov, *Cultures and Organizations*, 3rd ed., McGraw-Hill 2010)

Each scored 0–100 per country at hofstede-insights.com.

- **Power Distance (PDI).** High (Malaysia 100, China 80, Mexico 81) → display credentials, executive bios, formal portraits, deep hierarchy, gold/dark palettes, honorifics. Low (Austria 11, Denmark 18, USA 40) → flat IA, first-name copy, peer testimonials.
- **Individualism (IDV).** High (USA 91, UK 89, Netherlands 80) → "you/your", single-user hero shots, achievement framing. Collectivist (Guatemala 6, Indonesia 14, China 20) → "we/us/family", group photography, harmony framing.
- **Masculinity / Motivation toward Achievement (MAS).** High (Japan 95, Italy 70, USA 62) → competitive language, performance metrics, sharp geometry, superlatives. Low (Sweden 5, Netherlands 14) → quality-of-life imagery, consensus copy, rounded forms, sustainability.
- **Uncertainty Avoidance (UAI).** High (Greece 112, Japan 92, France 86) → detailed FAQs, warranties, certifications, structured navigation, free trials as risk reducers. Low (Singapore 8, USA 46, China 30) → experimental layouts, beta-tolerant.
- **Long-Term Orientation (LTO).** High (South Korea 100, China 87, Germany 83) → heritage claims, roadmap pages, long-term ROI. Low (USA 26, Australia 21) → instant results, "today/now", tradition respected.
- **Indulgence vs Restraint (IVR).** Indulgent (Mexico 97, USA 68) → smiling people, leisure, bright palettes, "treat yourself". Restrained (Pakistan 0, Russia 20, China 24) → disciplined imagery, duty framing, muted palettes.

Localize by scoring the brand site 1–5 against each dimension's target-country profile; flag mismatches.

### 6.3 Jobs-to-be-Done

Three canonical schools:

- **Christensen** (HBS, *Competing Against Luck*, 2016) — the milkshake study; "customers hire products to make progress in a particular circumstance."
- **Tony Ulwick** (Strategyn, *Jobs to be Done: Theory to Practice*, 2016) — Outcome-Driven Innovation (ODI). Universal Job Map: Define → Locate → Prepare → Confirm → Execute → Monitor → Modify → Conclude. Desired outcomes written as: "[minimize/increase] [unit: time, likelihood] [object] [context]." 50–150 outcomes per typical market; opportunities = `importance + max(importance − satisfaction, 0)`.
- **Bob Moesta** (Re-Wired Group, *Demand-Side Sales 101*, 2020) — Switch Interview and Four Forces of Progress:

| Force | Direction |
|---|---|
| **Push** of the situation | drives away from current solution |
| **Pull** of the new solution | attracts to alternative |
| **Anxiety** of the new | resists change |
| **Habit** of the present | resists change |

Demand exists when *Push + Pull > Anxiety + Habit*.

**Job taxonomy:** functional ("get a healthy meal on the table in 20 minutes"), emotional ("feel like a competent parent"), social ("be seen as a thoughtful host").

**Job Story format** (Klement/Intercom): *When [SITUATION], I want to [MOTIVATION], so I can [EXPECTED OUTCOME].* Persona-agnostic and solution-agnostic.

**Agent use.** Infer the competitor's JTBD from hero headline ("Send better email" → "get email opened"), use-case pages (enumerate functional jobs), testimonials (emotional/social). Which competitors are named in "alternatives to" searches reveals the real competitive set — and hence the real job.

### 6.4 Alan Cooper persona methodology (*The Inmates Are Running the Asylum*, SAMS 1999; *About Face*, 4th ed. 2014)

Goal-Directed Design operates on three goal layers: **experience goals** (how the user wants to feel — "not stupid"), **end goals** (outcome to accomplish), **life goals** (long-term self-image).

Persona cast: **Primary** (the one the UI is designed for — cannot be satisfied by a UI designed for any other persona), **Secondary** (satisfied by primary's UI plus a few non-conflicting needs), **Supplemental** (fully satisfied by primary's UI), **Customer** (buyer, different from user), **Served** (affected but doesn't use), **Negative** (explicit anti-target).

Persona components: name and photo; demographics (only if relevant); job/role; behavior patterns (the empirical core); goals (experience, end, life); pain points; skills and tech proficiency; environment; representative quote; motivations and values.

For the market research agent, synthesize one primary + one secondary persona per major audience segment inferred from the stack. Derive patterns from G2 reviews (pull 20 quotes from competitor profiles) and Reddit threads.

### 6.5 B2B vs B2C vs B2B2C signals

B2B signals: enterprise logos above the fold; "Contact sales" as primary CTA; compliance badges (SOC 2, HIPAA, GDPR, ISO 27001); "Trusted by" with company names; long-form case studies; whitepapers; ROI calculators; grade-level 9–12 copy; jargon density >1.5%; pricing either tiered with an enterprise "Contact us" or absent. B2C signals: App Store / Play Store badges; "Download the app"; grade-level <8; "you" heavy; emotional testimonials from individuals; 4.8★ review counts. B2B2C signals: dual-audience landing pages or separate `/business` routes (Shopify Partners, Stripe Atlas).

### 6.6 Decision-maker vs user vs buyer (B2B triangle)

In enterprise SaaS three personas usually diverge:

- **User** (daily operator) — cares about ergonomics, time saved, daily frustration removed. Targeted by product-page UX copy, onboarding flow screenshots.
- **Buyer** (procurement/finance) — cares about price, contract terms, legal/security. Targeted by pricing page and trust-center sections.
- **Decision-maker** (executive sponsor) — cares about ROI, strategic fit, risk mitigation. Targeted by homepage hero and exec-level case studies.

If the competitor site has exactly one CTA ("Request a demo") and enterprise logos but no product UI screenshots, it is decision-maker-first. If it shows product screenshots and a free tier with in-app onboarding, it is user-first (PLG).

### 6.7 Generational aesthetic preferences

Loose but useful when the target audience age-band is known: **Gen Z** (Y2K revival — chrome, blur, hyper-saturated pinks, 3D pill buttons, squiggles, stickers); **Millennial** (sans-serif minimalism, pastel-muted palettes, Circular/Inter, rounded; the "Airbnb-era" aesthetic); **Gen X** (functional, dense, data-forward, grotesk sans, moderate density); **Boomer** (convention — blue/red/white, serif headlines, high contrast, larger text sizes, direct CTAs). Hofstede still dominates when culture and generation conflict.

---

## 7. Tone of voice analysis

### 7.1 Nielsen Norman Group 4D tone model (Moran, "The Four Dimensions of Tone of Voice," NN/g, July 2016; updated Aug 2023)

Four axes, each a 3-point scale (–1 / 0 / +1), producing 81 possible profiles:

1. **Funny ↔ Serious** — did the writer attempt humor (regardless of whether the joke lands)?
2. **Formal ↔ Casual** — contractions, slang, fragments, emoji vs full sentences, no contractions, jargon-free professionalism.
3. **Respectful ↔ Irreverent** — reverent treatment vs sarcasm, satire, edge.
4. **Enthusiastic ↔ Matter-of-fact** — exclamation marks, emotive adjectives vs neutral declaratives.

NN/g's 2016 study found casual variants were rated +0.7 friendlier, +0.3 more trustworthy, and +0.4 more likely-to-recommend than serious counterparts (5-point scales). Mailchimp-style brands (Funny+Casual+Respectful+Enthusiastic) vs gov.uk-style (Serious+Formal+Respectful+Matter-of-fact) sit at opposite poles.

**Scoring procedure.** Sample 8–12 copy chunks spanning contexts: hero headline, subhead, CTA, feature card, error message, 404, support article, pricing fine print, About page. Place each on each axis. Report mean and variance. Healthy brands are **constant on voice**, **variable on tone** (enthusiastic on hero, matter-of-fact on error).

### 7.2 Mailchimp Voice & Tone (styleguide.mailchimp.com, now at contentdesign.intuit.com)

Canonical distinction: **voice is constant, tone is variable.** Mailchimp's voice is plainspoken, genuine, a translator of B2B jargon, subtly humorous. Tone adjusts to reader state: empathetic when confused, playful when celebrating, precise when legal. Mechanics: active voice, contractions, serial commas, person-first language, brief but clarity-first, positive framing.

### 7.3 Quantitative readability

Three formulas, each computed from word/sentence/syllable counts (use the `syllable` npm package for reliable syllable counts).

**Flesch Reading Ease** (Flesch, *J. Applied Psychology*, 32(3):221–233, 1948):

> RE = 206.835 − 1.015 × (words/sentences) − 84.6 × (syllables/words)

Higher = easier. 60–70 = plain English; <30 = academic.

**Flesch–Kincaid Grade Level** (Kincaid et al., Naval TTC Report 8-75, 1975):

> GL = 0.39 × (words/sentences) + 11.8 × (syllables/words) − 15.59

Output is a US grade level. Lower = easier. Adopted by US DoD, IRS, and many state regulators.

**Gunning Fog Index** (Gunning, *The Technique of Clear Writing*, McGraw-Hill, 1952):

> Fog = 0.4 × [ (words/sentences) + 100 × (complex words / words) ]

"Complex" = 3+ syllables, excluding proper nouns, familiar compounds, and –es/–ed/–ing inflections. Output is US grade level.

**Targets for consumer web copy:** landing/homepage RE 60–80, FK 6–8, Fog 7–9. Product pages FK 8–10. Support docs FK 7–9. B2B/SaaS tolerates FK 9–11. Legal unavoidably 12+ — pair with plain-English summary.

### 7.4 Jargon, pronoun, and CTA analysis

Compute on harvested copy:

- **Jargon density** = jargon-token count / total tokens. Build the jargon set per domain (AI: embedding, RAG, inference, throughput; fintech: settlement, ACH, reconciliation; devtools: idempotent, observability, gRPC). >2% = enterprise-technical; <0.3% = consumer.
- **Pronoun ratio** per 100 words: `we/our/us`, `you/your/yours`, `they/their/them`. `you`/`we` > 1 → customer-centric; `we`/`you` > 1.5 → brand-centric (often a warning sign).
- **Sentence length** median and mean. <10 words = punchy/direct; 12–18 = typical SaaS; >22 = formal/corporate.
- **Exclamation per 100 sentences.** >5 = playful/energetic; 0–1 = serious/corporate.
- **CTA classification** via regex buckets: hard_sell (`/^(buy|subscribe now|upgrade)/i`), enterprise (`/^(request a demo|talk to sales|contact sales|book a call)/i`), soft_entry (`/^(get started|try|start free)/i`), explore (`/^(explore|learn more|see how|discover)/i`), dev (`/^(read the docs|view on github|star on github)/i`), community (`/^(join|become|apply|follow)/i`).

### 7.5 Prompt for Claude to assign a 4D tone profile

```
You are a tone-of-voice analyst using the Nielsen Norman Group 4-dimensional model.

Given the copy samples below, score the writer's tone on each of four axes. Use integers in {−1, 0, +1}, where:
- Funny(+1)↔Serious(−1): did the writer attempt humor (puns, jokes, irony)? Yes = +1; neutral = 0; somber = −1.
- Formal(−1)↔Casual(+1): contractions, slang, fragments, emoji = +1; no contractions, professional diction = −1.
- Respectful(−1)↔Irreverent(+1): reverent treatment = −1; sarcasm, satire, edge = +1.
- Enthusiastic(+1)↔Matter-of-fact(−1): exclamations, emotive adjectives = +1; neutral declaratives = −1.

For each axis, quote the single most diagnostic phrase from the samples that justifies the score. If samples are mixed, score the dominant tendency and note variance.

Return JSON: { "funny_serious": int, "formal_casual": int, "respectful_irreverent": int, "enthusiastic_matter_of_fact": int, "evidence": { "<axis>": "<quote>" }, "variance_flag": bool, "overall_label": "<concise tone descriptor>" }

Copy samples:
<paste hero, subhead, 5 CTAs, 3 headings, 1 error message, 1 support line>
```

---

## 8. Output structure — the `market-analysis.md` artifact

The agent writes exactly one file at `market-analysis.md` in the repo root (or a path provided by the orchestrator). Strict schema:

```markdown
# Market analysis — <project name>

_Generated by sd-research on <ISO date>. Confidence: <high|medium|low>._

## 1. Niche identification
- **Detected vertical**: <top vertical> (score <X>, second <Y> at <Z>)
- **Detected audience**: <top audience>
- **Positioning tier**: <indie | SMB | mid-market | enterprise | consumer>
- **Primary evidence**: <3–5 bullets, each with a file path + line reference or quote>
- **Uncertainty flags**: <any signals pointing to alternative interpretations>

## 2. Competitor matrix
| Competitor | Archetype | Aaker peak | Vibe | Primary hex | Display font | Radius | Hero pattern | Tone (4D) | Hero verb |
|---|---|---|---|---|---|---|---|---|---|
| Acme | Creator | Competence | minimalist | #0A2540 | GT America | subtle | left-copy-right-product | −1/+0/−1/+0 | ship |
| Beta | Sage | Competence | calm-corporate | #1E3A8A | Inter | rounded | centered | −1/−1/−1/−1 | learn |
| ... | | | | | | | | | |

_Source: `evidence/<competitor>/tokens.json` and `copy.json`._

## 3. Category codes — obey, extend, subvert
### Near-universal codes (≥80% of competitors)
- **<code>**: observed in N/M competitors. Recommendation: **obey** because <rationale>.

### Split codes (40–70%)
- **<code>**: observed in <majority> — recommendation: **extend** by <specific twist>.

### Open territory
- **<dimension>**: no dominant convention. Recommendation: <choice> aligned with target archetype.

### Subversion opportunities
- **<boring code>**: everyone does <thing>; subvert by <alternative> — this fits an Outlaw/Creator positioning.

## 4. Recommended brand archetype for this project
- **Primary**: <archetype> — rationale tied to niche + audience + whitespace.
- **Supporting**: <archetype>.
- **Why not <alternative>**: <one sentence>.

## 5. Color palette recommendation
- **Primary**: `#<hex>` — HSL <h,s,l>. Rationale: <why>.
- **Secondary / accent**: `#<hex>`.
- **Neutrals**: `#<hex>` (bg), `#<hex>` (surface), `#<hex>` (border), `#<hex>` (fg).
- **Semantic**: success, warning, danger, info.
- **Avoided colors**: <hexes used by closest 2 competitors — do not copy>.

## 6. Typography recommendation
- **Display**: <family> — rationale (archetype fit, category convention, contrast with competitors).
- **Body**: <family>.
- **Mono** (if applicable): <family>.
- **Type scale**: base 16px, ratio <1.125|1.200|1.250>.

## 7. Target audience profile
- **Primary persona**: name, role, 2 goals, 2 pains, representative quote.
- **Secondary persona**: same shape.
- **Negative persona**: explicit exclusion.
- **B2B / B2C / B2B2C**: <classification>; user/buyer/decision-maker mapping if B2B.
- **Hofstede localization notes**: <only if non-US or multi-market>.
- **Primary JTBD (Job Story format)**: "When <situation>, I want to <motivation>, so I can <outcome>."

## 8. Tone of voice recommendation
- **NN/g 4D target**: F/S <±1>, F/C <±1>, R/I <±1>, E/M <±1>.
- **Reading-level target**: FK grade <X>, Flesch RE <Y>.
- **Pronoun posture**: "you" forward / "we" forward / balanced.
- **CTA pattern**: primary "<verb>" + secondary "<verb>".
- **Jargon policy**: allow <domain terms>; forbid <buzzwords>.
- **Do/Don't examples**: three each, written for this specific project.

## 9. Actionable recommendations
A prioritized list of ≤10 concrete moves for the super-design builder, each with: action, rationale, linked evidence.

## 10. Onliness statement (draft)
> Our <CATEGORY> is the only <CATEGORY> that <HOW> for <WHO> in <WHERE> who <WHY> in an era of <WHEN>.

## Appendix — evidence
- `evidence/<competitor>/home.png`, etc. — full-page screenshots.
- `evidence/<competitor>/tokens.json` — extracted CSS variables, palette, type stack.
- `evidence/<competitor>/copy.json` — hero, CTAs, headings, body sample.
- `evidence/niche.md` — dependency → vertical scoring trace.
- `evidence/sources.md` — every external URL cited, with retrieval date.
```

Two hard rules: (a) every claim in §§1–10 resolves to either a repo file path or an `evidence/` artifact; (b) competitor count must be within 5–10 or the agent self-rejects and redoes discovery.

---

## 9. Agent prompt engineering best practices

Five principles shape the `sd-research` system prompt.

**Role first, procedure second, format third.** Claude follows the first strong instruction most reliably. Open with a one-sentence role, then a numbered "When invoked" block, then an explicit output-schema block. This is the Anthropic-documented pattern used by the `code-reviewer` and `data-scientist` examples.

**Be specific about triggers in `description`.** Claude undertriggers agents whose description is merely capability-shaped ("market researcher"). Trigger phrases ("MUST BE USED when…", "Use proactively when…", "Invoked at the start of every super-design run") improve auto-delegation markedly.

**Evidence requirements must be non-negotiable.** Explicit rules: "Every factual claim cites a file path with line number or a URL captured in this session. Fabricated URLs or invented API names are a hard failure. If evidence is absent, write `INSUFFICIENT EVIDENCE` and stop." Claude 4.5 respects literal constraints; pair this with a self-check block.

**Self-check before returning.** The last section of every good research-agent prompt is a three-to-five-item checklist the agent walks before writing its final output: schema conformance, source verification, no invented names, confidence scoring honest.

**Progressive disclosure.** Keep the agent's own system prompt under ~2,000 words. Offload reference material (this playbook, archetype lookups, dependency maps) to `references/*.md` loaded with `Read` on demand. The agent knows *where* to look; it doesn't carry all knowledge in context.

Supporting practices: use XML tags (`<procedure>`, `<output_format>`, `<evidence_rules>`) — Claude was trained on this structure; prefer explicit tools allowlist (principle of least privilege); forbid the `Agent` tool (subagents can't spawn subagents); use absolute paths in Bash (cd doesn't persist between calls); remind the agent that `cd` doesn't persist and that it won't see the parent's `CLAUDE.md`.

---

## 10. Concrete agent file — `.claude/agents/sd-research.md`

The ready-to-paste file. Assumes the super-design skill lives at `.claude/skills/super-design/` and this playbook is at `.claude/skills/super-design/references/market-research-playbook.md`. Playwright MCP is scoped inline so its tool schemas don't leak into the parent context.

```markdown
---
name: sd-research
description: MUST BE USED at the start of every super-design run to produce market-analysis.md. Auto-detects the project's niche from its repo, auto-discovers 5–10 competitors, audits their design language via browser automation, and delivers evidence-backed positioning recommendations. Use proactively whenever the user invokes the super-design skill, mentions competitors, brand positioning, market research, design direction, or asks "what should this product look like?"
tools: Read, Write, Glob, Grep, Bash, WebSearch, WebFetch
model: sonnet
color: purple
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
---

# Role
You are a senior design researcher and brand strategist. You combine three disciplines: (1) programmatic repository analysis to infer a project's niche and audience; (2) competitive design-language extraction via browser automation; (3) synthesis into a defensible positioning brief grounded in canonical branding frameworks — Mark & Pearson archetypes, Aaker, Kapferer, Keller, Ehrenberg-Bass, Neumeier, NN/g tone, Christensen/Ulwick/Moesta JTBD, Hofstede, Cooper personas.

Your output is exactly one file: `market-analysis.md` in the repo root, plus an `evidence/` directory of screenshots, extracted tokens, and copy samples. You never fabricate. Every claim cites a repo file path or an in-session URL.

<procedure>
## When invoked

1. **Locate the repo root** (cwd; do not assume paths). Read `package.json`, `README.md`, `CLAUDE.md`, `AGENTS.md` if present, and any manifest files (`pyproject.toml`, `Cargo.toml`, `go.mod`, `pubspec.yaml`, `foundry.toml`, `hardhat.config.ts`, `anchor.toml`, `dbt_project.yml`). Use `Read` and `Glob`.
2. **Load the playbook.** Read `.claude/skills/super-design/references/market-research-playbook.md` for dependency-to-vertical mappings, archetype detection heuristics, and extraction snippets. When in doubt, defer to the playbook.
3. **Detect niche.** Apply the 8-signal scoring algorithm (playbook §1). Score verticals and audiences by dependency weight, manifest signals, README semantics, domain-entity clustering, and i18n locales. Compute confidence = top / (top + second). If < 0.55, use `AskUserQuestion` with three concrete options drawn from top verticals; otherwise infer silently and record reasoning in `evidence/niche.md`.
4. **Discover competitors.** Run the 7-source crawl (playbook §2): WebSearch for "alternatives to <seed>" and "<seed> vs"; WebFetch Product Hunt topics, G2/Capterra/TrustRadius category pages, YC directory, awesome-* lists, Reddit and HN Algolia queries, SimilarWeb/BuiltWith. Dedupe by registrable domain. Rank using fame×similarity×design-signal. Finalize 5–10 covering category-king, peers, challenger, emerging, and enterprise-anchor buckets.
5. **Audit each competitor.** For each finalist, use the Playwright MCP tools to visit homepage, primary product page, pricing, and About. For every page:
   - `browser_navigate` → `browser_resize({width:1440,height:900})` → `browser_wait_for({time:1.5})`.
   - `browser_take_screenshot({fullPage:true, filename:"evidence/<slug>/<page>.png"})`.
   - `browser_evaluate` using the snippets in playbook §3.2–3.11: font-family frequency, color histogram, CSS custom properties, heading hierarchy, spacing histogram, radius distribution, Tailwind/shadcn telltale detection, copy harvest, shadow/elevation.
   - Save extracted data to `evidence/<slug>/tokens.json`, `typography.json`, `copy.json`.
6. **Classify each competitor.** Assign primary+supporting archetype (playbook §4.1), Aaker peak (§4.2), vibe class (§3 table + classification function), NN/g 4D tone (§7.1 via the tone-analysis prompt), and hero-pattern taxonomy.
7. **Build the category-code matrix.** Tabulate every competitor across the dimensions in playbook §5.1. Compute frequency for each column. Classify each code as obey / extend / subvert / open-territory per playbook §5.2.
8. **Synthesize recommendations.** Pick primary+supporting archetype for the current project that sits in whitespace (Neumeier insertion test, playbook §5.4). Derive palette, typography, tone, audience profile, and JTBD. Draft the onliness statement.
9. **Write `market-analysis.md`** following the exact schema in playbook §8.
10. **Run self-check** (below). If any check fails, fix and re-verify before returning.
</procedure>

<evidence_rules>
## Evidence rules (non-negotiable)

- Every factual claim resolves to (a) a repo path with line reference, (b) a file in `evidence/`, or (c) a URL retrieved this session.
- Never invent URLs, API names, library names, or company facts. If uncertain, write `[UNVERIFIED]` or `INSUFFICIENT EVIDENCE` and stop.
- Screenshots are mandatory for every audited competitor. No screenshot → drop the competitor.
- Quotes from competitor copy are verbatim, in quotation marks, with the page URL.
- Confidence scoring is honest: high only when top vertical score > 2× second; medium otherwise; low when discovery produced fewer than 5 viable competitors.
- Do not copy competitor colors, fonts, or taglines for the current project. Recommendations must differentiate, not imitate.
</evidence_rules>

<output_format>
## Output format

Write exactly one file, `market-analysis.md`, matching the 10-section schema in playbook §8. Sections: (1) Niche identification, (2) Competitor matrix, (3) Category codes, (4) Archetype recommendation, (5) Color palette, (6) Typography, (7) Audience profile, (8) Tone of voice, (9) Actionable recommendations, (10) Onliness statement, plus Evidence appendix. Every table uses markdown table syntax. Every recommendation is numbered and cites evidence by filename.

Return to the parent agent a three-to-five-sentence summary — no more — announcing the detected niche, top three competitors, recommended archetype, and the path to `market-analysis.md`. Do not paste the full analysis into chat.
</output_format>

<self_check>
## Self-check before returning

- [ ] `market-analysis.md` exists and matches the schema in playbook §8.
- [ ] Exactly 5–10 competitors; each has a full row in the matrix and a screenshot in `evidence/`.
- [ ] Every recommendation in §9 cites an evidence filename or repo path.
- [ ] No invented URLs, library names, or company facts — spot-check three claims at random.
- [ ] Confidence level in the header is honestly calibrated.
- [ ] Onliness statement fails the insertion test for every competitor (no competitor's name can be substituted and still make it true).
- [ ] Recommendations differentiate from (rather than imitate) the closest two competitors.
- [ ] The summary returned to the parent agent is ≤5 sentences.
</self_check>

## Tool-use notes

- Use `Read`, `Glob`, `Grep` instead of `bash cat`/`find`/`grep`. Faster and structured.
- `cd` in `Bash` does NOT persist between calls. Always use absolute paths.
- You do not inherit the parent's `CLAUDE.md` or conversation; rely on this prompt + the playbook + what you `Read` from the repo.
- You cannot spawn further subagents; you are the research layer.
- When a competitor site blocks Playwright or times out, retry once with a 5s `browser_wait_for` then fall back to `WebFetch`. Log the degradation in `evidence/<slug>/notes.md`.

## Example output summary (what you send back to the parent)

> Detected niche: **indie B2B SaaS (AI chat product, Vercel stack)**, confidence high (0.82). Top three competitors audited: Linear, Vercel, Cursor. Recommended archetype: **Creator** (primary) + **Sage** (supporting), positioned in the whitespace between Linear's minimalist competence and Cursor's dev-outlaw posture. Full report at `market-analysis.md` with 7 competitors, 28 screenshots, and a draft onliness statement.

## Example output excerpt — `market-analysis.md` (abbreviated)

```markdown
# Market analysis — acme-ai

_Generated by sd-research on 2026-04-18. Confidence: high._

## 1. Niche identification
- **Detected vertical**: ai-chat (score 4.6; second: ai-tooling at 2.1)
- **Detected audience**: chat-products (indie B2B SaaS)
- **Positioning tier**: indie / PLG
- **Primary evidence**:
  - `package.json:23` — `"ai": "^3.4.0"` (Vercel AI SDK, vertical=ai-chat weight 0.95)
  - `package.json:24` — `"@ai-sdk/anthropic": "^0.2.0"` (weight 0.95)
  - `package.json:18` — `"@clerk/nextjs": "^5.0.0"` (audience=B2B-saas-modern, 0.95)
  - `README.md:1–3` — "Acme AI is a conversational assistant for product teams" (B2B, product-team audience)
  - `app/api/chat/route.ts:1–12` — streaming chat endpoint using `ai` SDK
- **Uncertainty flags**: none.

## 2. Competitor matrix
| Competitor | Archetype | Aaker peak | Vibe | Primary | Display font | Radius | Hero | Tone | Verb |
|---|---|---|---|---|---|---|---|---|---|
| Linear | Creator | Competence | minimalist | #5E6AD2 | Inter Display | subtle | centered | −1/+0/−1/−1 | build |
| Vercel | Sage | Competence | tech-futuristic | #000000 | Geist | subtle | centered | −1/+0/−1/−1 | ship |
| Cursor | Outlaw | Excitement | tech-futuristic | #000000 | Inter | subtle | left-copy | +0/+1/−1/+0 | code |
| v0 | Creator | Excitement | tech-futuristic | #000000 | Geist | subtle | centered | +0/+1/−1/+0 | generate |
| ... | | | | | | | | | |

_Source: `evidence/linear/`, `evidence/vercel/`, etc._

## 4. Recommended brand archetype
- **Primary**: Creator — rationale: the target audience (product teams) hires AI tools to *make* things; the Creator motto "if you can imagine it, it can be done" fits the value prop; three of seven competitors already land here but none execute it with editorial typography.
- **Supporting**: Sage — reinforces trustworthiness in an AI category where hallucination concerns dominate.
- **Why not Outlaw**: Cursor and v0 already occupy the dev-rebel slot; differentiation requires a calmer posture.

## 10. Onliness statement (draft)
> Our AI assistant is the only AI assistant that generates production-ready product specs for cross-functional product teams in modern SaaS companies who need to ship twice as fast in an era of AI-native product development.
```
```

---

## Conclusion

The Market Research Agent succeeds when it behaves like a senior brand strategist who happens to read code. Three disciplines must fuse in one pass: programmatic **inference** from the repo's fingerprint (dependencies, manifests, domain entities, design tokens), disciplined **extraction** from competitor surfaces via Playwright-driven computed-style harvesting and dual-path palette analysis, and canonical-framework **synthesis** across twelve archetypes, five Aaker dimensions, six Kapferer facets, four Keller levels, Ehrenberg-Bass distinctive assets, Neumeier's onliness test, NN/g four-dimensional tone, JTBD in three voices (Christensen, Ulwick, Moesta), Hofstede localization, and Cooper personas. The novel insight: the repo itself is the highest-trust brief the agent ever receives — a well-chosen auth library or UI kit reveals audience more cleanly than any user interview. Evidence discipline and confidence calibration are what turn inference into a defensible recommendation rather than a confident guess; the self-check block at the bottom of the agent file exists because Claude 4.5 will skip citation without explicit instruction. Used together, these ten sections let a fresh `claude code` session walk into an unfamiliar repo and emerge, forty minutes later, with a market-analysis.md that a design lead would recognize as real work.