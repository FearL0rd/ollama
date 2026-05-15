# Design Intelligence Rubric

> The missing layer between WCAG/Nielsen checklists and "does this feel
> designed or vibecoded?" — used by sd-audit as Phase 3g.

## Why this exists

A UI can pass axe (zero WCAG violations), Nielsen (10/10 heuristics green),
Lighthouse (100 perf score) and still be visually horrible: card-stacked mobile
dashboards, microtext tables on phones, no visual hierarchy, shadcn defaults
slapped onto every surface with zero variant discipline, inline arbitrary
pixel values everywhere. This rubric codifies those **implicit** criteria.

Every category is scored **0–10** per page × viewport. Total score → a single
**design-intelligence score (DIS)** 0–100. Scores below 60 auto-flag MEDIUM
findings; below 40 auto-flag HIGH.

## Evidence requirement

Each category's score MUST cite ≥1 piece of evidence from the audit session:
- **SHOT** (screenshot path)
- **CSS** (computed style excerpt)
- **DOM** (snapshot quote)
- **CODE** (source file + line, via Grep, for vibecode detection)

A score without evidence is invalid. Auditor records `n/a` instead of guessing.

---

## Category 1 — Visual hierarchy (weight 1.0)

**Rationale:** Reber et al. processing fluency + Tractinsky aesthetic-usability — clean dominance hierarchies literally reduce cognitive load; beauty buys friction tolerance only after hierarchy is solved (artifact Parts 1–3).

**Question:** On this view, what is the single primary goal? Is it the most
dominant element visually?

| Score | Criteria |
|---|---|
| 10 | One dominant element ≥ 2× larger or distinctly heavier than rest. Supporting info subordinate. Example: Cash App balance. |
| 7  | Primary clear but competing CTAs present. |
| 4  | Multiple equal-weight elements; user has to hunt. |
| 0  | Flat wall of cards/tables, no signal of where to look. |

**Detect:** `browser_evaluate` → collect computed `fontSize`, `fontWeight`, `lineHeight`, `color` of h1–h6, buttons, key metrics. Compute size-dominance ratio. Ratio > 2 → 10. Ratio < 1.3 → ≤4.

**Example fail (beats-market):** admin dashboard mobile — 10 equal-weight metric cards, no hero. Score: 2.

---

## Category 2 — Density calibration per viewport (weight 1.2)

**Rationale:** Fitts's Law + thumbzone ergonomics — density must respect the physical reach envelope of the device; cramming desktop density onto mobile violates motor cost.

**Question:** Does information density match the device context?

| Viewport | Expected primary entities visible above fold |
|---|---|
| Mobile 375×812 | 6–8 compact rows OR 1 hero + 4–5 rows |
| Tablet 768×1024 | 8–12 rows or 4 cards in 2×2 |
| Desktop 1440×900 | 12–20+ rows or data-dense tables |

**Score:**
- 10 if density within ±20% of target
- 5 if half or double target
- 0 if <25% of target (wasteful) or >3× (cramped illegible)

**Detect:** Count `role=listitem | region | article` elements with `getBoundingClientRect` intersecting viewport. Compare to viewport target.

**Example fail (beats-market):** admin dashboard mobile — 3 cards above fold (target 6–8). Score: 3. Orders mobile = 20 rows visible but microtext = also fail (see Category 7).

---

## Category 3 — Consistency: spacing scale (weight 0.8)

**Rationale:** Gestalt proximity + rhythm — shared spacing units fuse related elements and separate distinct ones; arbitrary magic numbers break grouping perception.

**Question:** Do paddings, margins, gaps come from a scale (4/8px or 0.25rem) or are they arbitrary magic numbers?

**Detect:**
- `browser_evaluate` → collect computed `padding`, `margin`, `gap` from ≥50 elements.
- Grep codebase for `p-\[\d+px\]`, `m-\[\d+px\]`, `gap-\[\d+px\]` (Tailwind arbitrary values).
- Count: on-scale vs off-scale.

| Score | Criteria |
|---|---|
| 10 | 95%+ values on a 4/8 scale; no arbitrary pixel values in code |
| 7 | 80–95% on-scale; a few arbitrary values in leaf components |
| 4 | 50–80% on-scale; arbitrary values common |
| 0 | Random pixel values everywhere; no visible scale |

---

## Category 4 — Consistency: typography scale (weight 0.8)

**Rationale:** Processing fluency (Reber) — a discrete type scale accelerates recognition; a shapeless set of sizes forces re-parsing of hierarchy on every screen.

Same method for font-size, font-weight, line-height. Look for `text-\[\d+px\]` and arbitrary font-size. Expected: 6–10 sizes total in a designed system; 30+ sizes = vibecoded.

---

## Category 5 — Consistency: color palette (weight 0.8)

**Rationale:** Valdez & Mehrabian (1994) — saturation × value drive emotional response more than hue; a disciplined palette with controlled lightness/saturation ranges is the single highest-leverage decision for perceived quality (artifact line 43).

**Detect:**
- Collect computed `color`, `background-color`, `border-color` from ≥100 elements.
- Unique colors count. <15 = disciplined. 30+ = vibecoded.
- Grep for `#[0-9a-f]{6}`, `rgb\(`, Tailwind arbitrary colors.

| Score | Criteria |
|---|---|
| 10 | ≤12 distinct colors, all from tokens |
| 7 | 12–20 colors, mostly tokens |
| 4 | 20–30 colors |
| 0 | 30+ colors, raw hex/rgb inline |

---

## Category 6 — Whitespace & breathing room (weight 0.7)

**Rationale:** *Ma* (間) — negative space is substance, not absence; whitespace signals confidence and lets figure/ground perception resolve without strain.

**Question:** Does content have room to breathe, or is it crammed?

**Detect:** Compute average `padding-inline + margin-inline` per content block. Compare to container width. Measure content-to-chrome ratio.

| Score | Criteria |
|---|---|
| 10 | Content 60–75% of width, 25–40% whitespace |
| 7 | Content 75–85% |
| 4 | Content 85–95% OR <50% (too sparse) |
| 0 | Content touching edges, no breathing |

---

## Category 7 — Text legibility (weight 1.2)

**Rationale:** Miller 4±1 (Cowan 2001) + Postel's robustness — legible bodies keep working-memory cost low; dense microtext forces re-reading and exhausts the 4-chunk budget that forms and scannable text depend on.

**Detect:** `browser_evaluate` → collect `fontSize` computed px. Find minimum across visible text.

| Viewport | Min body | Min meta | Min input |
|---|---|---|---|
| Mobile | 16px | 13px | 16px (iOS zoom floor) |
| Desktop | 14px | 12px | 14px |

| Score | Criteria |
|---|---|
| 10 | All text meets mins |
| 5 | One or two elements below by ≤1px |
| 0 | Widespread microtext (tables, chips, meta) below min |

**Example fail (beats-market):** orders mobile — table cells computed at ~8px. Score: 0.

---

## Category 8 — CTA hierarchy (weight 1.0)

**Rationale:** Hick-Hyman Law — decision time grows with the log of equally-weighted options; multiple competing primaries flatten hierarchy into a choose-your-adventure and cost measurable conversion (Baymard PDP data).

**Question:** Is there ONE primary CTA per view?

**Detect:** Count buttons with `variant=default | primary | filled` OR bg-primary class. >1 above fold = competing.

| Score | Criteria |
|---|---|
| 10 | Single primary CTA, rest secondary/ghost |
| 7 | Single primary + 1 competing |
| 4 | 2–3 competing primaries |
| 0 | Every button styled primary |

Reference: Baymard PDP — 51% of e-commerce pages fail due to competing CTAs.

---

## Category 9 — State coverage (weight 1.1)

**Rationale:** Norman's "make system state visible" (Seven Stages of Action) + Nielsen H1 visibility-of-system-status — missing loading/empty/error states break the user's feedback loop and strand them in uncertainty.

Per page, does the UI handle: default / loading / empty / error / success?

**Detect per scenario:**
- Loading: Grep source for `isLoading`, `pending`, `Skeleton`, `aria-busy`.
- Empty: Grep for `isEmpty`, `EmptyState`, zero-result ternaries.
- Error: Grep for `role="alert"`, error boundaries, `onError`.

| Score | Criteria |
|---|---|
| 10 | 5/5 states rendered or demonstrably coded |
| 8 | 4/5 (usually missing success toast) |
| 5 | 3/5 (missing empty + error) |
| 0 | Only default; fetch returns broken UI on failure |

---

## Category 10 — Touch targets (mobile only, weight 1.0)

**Rationale:** Fitts's Law (MT = a + b·log₂(2D/W)) — acquisition time scales inversely with target width; sub-44px targets on fingers multiply error rate and exhaust motor patience.

**Detect:** `browser_evaluate` → get `getBoundingClientRect` of every
clickable (buttons, links, `[role=button|link|tab|checkbox|radio|switch]`,
`<input>`, `<select>`, `<summary>`, anchors with click handlers). Record
the smaller of `width × height` per target.

### Spec reconciliation

Three conflicting specs define "how big a touch target should be":

| Spec | Size | Nature | Citation |
|---|---|---|---|
| **WCAG 2.5.8 Target Size (Minimum) — AA** | **24 × 24 CSS px** | Baseline (legal/accessibility floor, with spacing exception) | https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum |
| **Apple Human Interface Guidelines** | **44 × 44 pt** | Platform-native target (iOS) | https://developer.apple.com/design/human-interface-guidelines/accessibility#Interactivity |
| **Material Design (Android)** | **48 × 48 dp** | Platform-native target (Android) | https://m3.material.io/foundations/accessible-design/accessibility-basics |
| **WCAG 2.5.5 Target Size (Enhanced) — AAA** | 44 × 44 CSS px | Advisory ceiling | https://www.w3.org/WAI/WCAG21/Understanding/target-size |

sd-audit reconciles as follows:
- **Baseline = 24 × 24 CSS px** — WCAG 2.5.8 AA pass; legally sufficient
  (with 24px center-to-center spacing exception).
- **Target = 44 × 44 CSS px** — HIG / Material / WCAG AAA; the single
  pragmatic "platform-native" size across iOS + Android + web (Android
  48 dp ≈ 44 CSS px at default DPI).
- Spacing exception keeps sub-44 icons compliant with WCAG AA but does NOT
  earn full design-intelligence points — they still feel cramped on a
  phone, which is what Fitts's Law above predicts.

### Scoring ladder

Per-target classification:
- **Full points** (≥ 44 × 44 CSS px) — platform-native, HIG/Material-clean.
- **Half points** (24 – 43 CSS px, min dimension) — WCAG AA pass but
  sub-optimal; counts as half a compliant target.
- **Zero points** (< 24 CSS px, min dimension) — WCAG AA FAIL; raises a
  separate `a11y-wcag22-2.5.8` finding in addition to pulling this score.

Let `N` = total targets, `n44` = count ≥ 44×44, `n24` = count in
[24, 44), `n0` = count < 24. Compute
`compliance = (n44 + 0.5 × n24) / N`.

| Score | Criteria |
|---|---|
| 10 | `compliance ≥ 0.95` AND `n0 == 0` — essentially all targets ≥ 44 |
| 7  | `0.80 ≤ compliance < 0.95` AND `n0 == 0` — some half-credit (24–43 px) targets, none under 24 |
| 4  | `0.50 ≤ compliance < 0.80` OR `0 < n0 ≤ 2` — common icon-only button fail; any WCAG breach |
| 0  | `compliance < 0.50` OR `n0 ≥ 3` — widespread <24 px targets, structural problem |

Any `n0 > 0` ALWAYS also raises a separate finding with prefix
`a11y-wcag22-2.5.8` (the rubric scores design intelligence; the finding
records the legal breach).

---

## Category 11 — Motion & feedback / perceived performance (weight 0.6)

**Rationale:** Doherty threshold (Doherty & Thadhani, IBM 1982) — system response <400 ms sustains flow; above that, perceived unresponsiveness begins. Paired with INP (Core Web Vitals) for the measurable proxy.

**Question:** Do interactions give feedback? Are animations tasteful and respect `prefers-reduced-motion`? Does every interaction land within the Doherty ceiling?

**Detect:**
- `browser_evaluate` with `matchMedia('(prefers-reduced-motion: reduce)')` + check for `transition` / `animation` on interactive elements.
- Missing hover/focus feedback on buttons = major fail.
- >3s animations = excessive.

**Perceived-performance sub-criterion (Doherty 400 ms ceiling, alongside INP).**
- Parse `session_dir/vitals/<page>.json` for INP (from `web-vitals@5` attribution build).
- For each primary interaction (Step 2.5 Phase A enumeration — clicks on CTA, form submit, nav link, combobox, modal trigger), compute **end-to-end response time** = click → visual feedback (spinner / state change / new pixels painted), not just INP.
- Fail rule: an interaction that **passes INP** (≤ 200 ms rating "good") but whose **user-perceivable response exceeds 400 ms** (e.g., INP fires at 150 ms but the resulting navigation/paint lands at 900 ms with no intermediate skeleton/optimistic UI) **penalizes C11**. Doherty is the ceiling; INP is the low-floor subset. Apply the Nielsen 0.1 s / 1 s / 10 s progress rule for anything over 400 ms (skeleton, optimistic UI, determinate bar + ETA + cancel for >10 s).

| Score | Criteria |
|---|---|
| 10 | Hover/focus/active feedback everywhere; animations ≤300 ms; reduced-motion respected; every interaction under Doherty 400 ms OR shows skeleton/optimistic state |
| 7 | Most interactions feedback; reduced-motion partial; occasional >400 ms interaction without feedback |
| 4 | Some interactions static; reduced-motion ignored; multiple interactions cross Doherty with no intermediate state |
| 0 | No hover/focus feedback at all OR autoplay video + parallax with no disable OR interactions routinely exceed 400 ms with blank waits |

---

## Category 12 — Nav pattern matches platform (weight 1.0)

**Rationale:** Fitts's Law + Hick-Hyman Law — nav patterns succeed when they minimize both motor cost (thumbzone/edge placement) and choice cost (limited top-level destinations, chunked per Miller 4±1).

| Viewport | Expected nav |
|---|---|
| Mobile (≤768) | Bottom tab bar (3–5), full-screen menus, gesture back |
| Tablet | Hybrid (collapsible sidebar or top tabs) |
| Desktop | Persistent sidebar or top navbar with search |

**Detect:** On mobile viewport, check for `<nav>` in fixed bottom position. On desktop, fixed left sidebar OR top header with nav.

| Score | Criteria |
|---|---|
| 10 | Nav matches platform convention |
| 5 | Hybrid but functional (e.g., bottom FAB + hamburger) |
| 0 | Hamburger-only on mobile OR bottom tabs on desktop |

---

## Category 13 — Table-on-mobile detection (weight 1.2, mobile only)

**Rationale:** Platform affordance + thumbzone — desktop tables violate mobile reading models (microtext, horizontal overflow, no visible sort); transformation to card/list is the minimum cost to preserve parse-ability.


**Detect:** At ≤768px, find `<table>` with >3 visible columns OR `display: table` containers with horizontal scroll AND text < 13px.

| Score | Criteria |
|---|---|
| 10 | No table or table transformed to card-per-row |
| 5 | Table present but scrolls clean with sticky first col |
| 0 | Squashed desktop table with microtext |

**Example fail (beats-market):** admin orders mobile — 8-col desktop table rendered at 375px with ~8px text. Score: 0.

---

## Category 14 — Modal/sheet appropriateness (weight 0.8)

**Rationale:** Fitts's Law + thumbzone — on mobile, close affordances belong where the thumb lives; centered dialogs with top-right dismiss violate reach on phones and strand users in forced-modal states.

| Viewport | Expected modal pattern |
|---|---|
| Mobile | Bottom sheet (slide-up) or full-screen with close top-left |
| Tablet | Centered dialog OR bottom sheet |
| Desktop | Centered dialog |

**Detect:** Open every `role=dialog` trigger. Measure position + dimensions. On mobile, centered dialog with close in top-right = fail.

| Score | Criteria |
|---|---|
| 10 | Correct per viewport |
| 5 | Centered on mobile but within reach |
| 0 | Unreachable thumb-zone close, wrong pattern for device |

---

## Category 15 — Color semantics (weight 0.6)

**Rationale:** Jakob's Law (users spend most time on other products) + learned convention — red/green/amber mappings are pre-installed in users' mental models; using them decoratively forces re-learning and breaks status recognition at a glance.

**Detect:** Collect colors used on: error messages, success states, warnings, info. Red = error? Green = success? Or decorative-only?

| Score | Criteria |
|---|---|
| 10 | Semantic colors distinct and consistent across app |
| 5 | Used but inconsistent (red elsewhere as brand) |
| 0 | No semantic color system |

---

## Category 16 — Design-system coherence (weight 1.1)

**Rationale:** Tesler's Law (conservation of complexity) + von Neumann consistency — complexity does not disappear, it moves; a disciplined system absorbs variation once inside tokens/variants/primitives so every downstream surface stays predictable. Incoherent systems push the same complexity onto users (re-learning each screen) and onto engineers (ad-hoc classes per component). This is why C16 carries one of the highest weights: coherence is not polish, it is the mechanism that conserves attention.

**The meta-category.** Does the app LOOK like it was designed by one team with one vision? Or does it look like a collection of shadcn defaults?

**Detect (aesthetic signal):**
- Does at least one of: custom color palette, custom font pairing, custom spacing rhythm, custom radius language, custom motion language, custom illustration/icon set EXIST?
- Grep package.json for ≥1 of: `typeui.sh`, `framer-motion`, custom fonts beyond system, Lottie, MagicUI, Aceternity, custom token file.

| Score | Criteria |
|---|---|
| 10 | Strong identity — you could recognize this app from a cropped screenshot |
| 7 | Some identity (brand color + maybe custom font) |
| 4 | shadcn defaults + 1 accent color |
| 0 | Pure shadcn defaults, zero customization, looks like `npx shadcn-ui@latest init` |

**When score ≤4:** recommend a typeui.sh aesthetic skill OR a frontend-design
session. See `design-skills-catalog.md`.

---

## Category 17 — Vibecode detection (weight 1.0)

**Rationale:** Norman's reflective layer (Emotional Design, 2004 — artifact line 547) — vibecoded surfaces pass the visceral/behavioral layers but fail reflective judgment; code that reads as "hand-assembled divs" telegraphs lack of intentional system, which is exactly what distinguishes "designed" from "vibecoded" output.

**Question:** Does the code follow patterns (components, variants, tokens)
or is it hand-assembled divs with inline styles?

**Detect (source grep):**
- Count `<div className="..."` without surrounding component → raw-div score
- Count inline `style={{` → inline-style count
- Count `@media` queries inline vs breakpoint tokens
- Count arbitrary Tailwind values (`\[\d+px\]`, `\[#[0-9a-f]+\]`)
- Check if shadcn components are wrapped into domain components (MetricRow, OrderCard) or used raw per page
- Check if types are co-located in `types/` vs inline `any`

| Score | Criteria |
|---|---|
| 10 | Domain components, design tokens, typed props, variants via CVA |
| 7 | Some composition, some raw shadcn usage |
| 4 | Mostly raw primitives, inconsistent composition |
| 0 | Flat page files with 500+ lines of inline JSX; zero reuse |

---

## Scoring formula

```
DIS = Σ(score_i × weight_i) / Σ(weight_i) × 10

weight_sum = 14.8
max_raw = 148.0 → normalized to 100

Example (beats-market admin dashboard mobile):
  C1 hierarchy: 2 × 1.0 = 2.0
  C2 density:   3 × 1.2 = 3.6
  C3 spacing:   7 × 0.8 = 5.6
  C4 type:      6 × 0.8 = 4.8
  C5 color:     7 × 0.8 = 5.6
  C6 whitespace:4 × 0.7 = 2.8
  C7 legibility:8 × 1.2 = 9.6
  C8 CTA:       6 × 1.0 = 6.0
  C9 states:    4 × 1.1 = 4.4
  C10 touch:    6 × 1.0 = 6.0
  C11 motion:   5 × 0.6 = 3.0
  C12 nav:      4 × 1.0 = 4.0
  C13 table:   10 × 1.2 = 12.0 (no table on dashboard)
  C14 modal:    6 × 0.8 = 4.8
  C15 color-sem:6 × 0.6 = 3.6
  C16 coherence:3 × 1.1 = 3.3
  C17 vibecode: 4 × 1.0 = 4.0
  raw = 85.1 → DIS = 57.5 → MEDIUM severity
```

## Output format

Write `.super-design/sessions/<id>/design-intelligence.json`:

```json
{
  "pages": [
    {
      "page_url": "/admin",
      "viewport": "375x812",
      "categories": {
        "visual_hierarchy": { "score": 2, "evidence": ["screens/admin_mobile.png", "styles/admin_mobile.json"], "notes": "10 equal-weight metric cards, no hero" },
        "density": { "score": 3, "evidence": ["screens/admin_mobile.png"], "notes": "Only 3 metrics above fold; target 6-8" }
      },
      "dis": 57.5,
      "severity": "MEDIUM",
      "top_findings": ["F-0042", "F-0043", "F-0049"]
    }
  ],
  "overall_dis": 54.2,
  "overall_severity": "MEDIUM",
  "weakest_categories": ["visual_hierarchy", "density", "design_system_coherence"]
}
```

Each category score ≤ 4 SHOULD spawn a finding with `template_id` from the M-family (M1–M15) in `fix-agent-playbook.md`.

## Cross-references

- Mobile-specific categories (C2, C7, C10, C12, C13, C14) reference
  `.claude/skills/mobile-app-patterns/SKILL.md` for fix patterns.
- Design-system coherence (C16) references `design-skills-catalog.md` for
  typeui.sh skill suggestions.
- Vibecode (C17) references `fix-agent-playbook.md` V-templates (spacing,
  type, color tokens).
