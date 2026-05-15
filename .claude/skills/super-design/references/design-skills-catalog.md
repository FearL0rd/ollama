# Design Skills Catalog

> Map of installed design skills and when to recommend each. Used by
> sd-audit (Category 16 design-system-coherence findings) and sd-fix
> (when proposing aesthetic realignment above template scope).

## Installed typeui-* skills

All from https://www.typeui.sh/design-skills — already present in
`.claude/skills/`. Claude auto-invokes them when their description matches
the task. sd-audit MUST reference them by name in findings; sd-fix MUST
mention them as optional realignment paths when design-system-coherence
score ≤ 4.

| Skill | Best for | Visual signature | When to recommend |
|---|---|---|---|
| **typeui-dashboard** | Admin panels, data apps, SaaS | Dark theme, cloud-platform density (AWS/GCP feel), data-first | DIS C16 fail on admin/dashboard routes |
| **typeui-application** | Developer tools, productivity | Vercel/GitHub-inspired, clean neutrals, high information density | SaaS products without strong identity |
| **typeui-enterprise** | B2B workflows, compliance, finance | Clean, high-contrast, conservative | Procurement-facing, corporate |
| **typeui-ant** | Form-heavy enterprise | Structured, predictable, Ant Design-adjacent | CRM, admin with many forms |
| **typeui-clean** | Marketing sites, simple products | Minimalist, generous whitespace | Pre-launch landing pages |
| **typeui-bento** | Feature grids, portfolios | Modular grid blocks | Homepage feature sections |
| **typeui-bold** | Consumer brands, challenger products | Strong typography, vivid color, confidence | Startups differentiating vs incumbents |
| **typeui-artistic** | Creative tools, design products | Expressive type, unusual layouts | Non-enterprise, vibe-forward |
| **typeui-dramatic** | Portfolios, agencies, brand sites | High-contrast, theatrical | Hero-heavy marketing |
| **typeui-neobrutalism** | Gen-Z, indie brands | Raw borders, hard shadows, bold | Statement brands |
| **typeui-paper** | Content, editorial, reading | Paper-textured, print-like | Blogs, publications |
| **typeui-doodle** | Learning, kids, playful | Hand-drawn, sketch feel | Education, creative tools |

## How each skill gets applied

Each typeui-* skill contains:
- **Design tokens** (colors, spacing, radius, shadows) as CSS variables
- **Component variants** adapted to shadcn/ui structure
- **Layout patterns** demonstrated
- **Do/Don't examples**

When Claude invokes a skill (via matching description or explicit mention),
it follows the skill's specific tokens + patterns instead of defaults.

## Other design-related skills installed

| Skill | Purpose | Cross-ref |
|---|---|---|
| **mobile-app-patterns** | Duolingo/Linear/Arc mobile patterns | Mandatory for mobile DIS scoring |
| **web-design-guidelines** | 100+ WCAG + UX rules (Vercel Labs) | Feeds Nielsen + WCAG manual pass |
| **composition-patterns** | React compound/composition patterns | C17 vibecode detection |
| **react-best-practices** | Vercel-Labs performance patterns | P-templates |
| **shadcn-ui** | shadcn component usage | V-templates (variants) |
| **tailwind-patterns** | Tailwind scale adherence | C3/C4/C5 consistency checks |
| **frontend-design** (plugin) | Full UI design loop with competitor research | Deep aesthetic reset |

## Selection matrix (used by sd-fix / sd-audit recommendations)

| Current state | Target vibe | Recommend |
|---|---|---|
| Vibecoded admin with shadcn defaults | Professional dashboard | `typeui-dashboard` or `typeui-application` |
| Admin with too many forms | Structured enterprise | `typeui-ant` or `typeui-enterprise` |
| Landing with no identity | Consumer bold | `typeui-bold` or `typeui-dramatic` |
| Creative-app landing | Expressive | `typeui-artistic` or `typeui-doodle` |
| B2B-serious | Conservative | `typeui-enterprise` |
| Editorial / blog | Readable long-form | `typeui-paper` |
| Feature-grid homepage | Modular showcase | `typeui-bento` |

### Vibe → typeui skill (primary → fallback)

Covers every vibe enumerated in the artifact Part 4 (12-vibe vocabulary). The
primary skill carries the aesthetic; the fallback handles adjacent contexts or
fills gaps when the primary would over-commit. When a project vibe has no
single-perfect skill (e.g. Premium/luxury, Warm/organic), the fallback plus
`/frontend-design` is the intended path.

| Part-4 vibe | Primary skill | Fallback | Notes |
|---|---|---|---|
| Minimal / clean | `typeui-clean` | `typeui-application` | Default pick for pre-launch marketing and "honest SaaS". |
| Bold / confident | `typeui-bold` | `typeui-dramatic` | Challenger brands, consumer launches. |
| Playful / friendly | `typeui-doodle` | `typeui-artistic` | Education, kids, creative tools. |
| Serious / professional (B2B) | `typeui-enterprise` | `typeui-ant` | Procurement-facing, compliance. |
| Technical / data-dense (SaaS admin) | `typeui-dashboard` | `typeui-application` | Dark-theme analytics, operator consoles. |
| Editorial / reading | `typeui-paper` | `typeui-clean` | Long-form content, publications. |
| Modular / showcase | `typeui-bento` | `typeui-application` | Feature grids, portfolios. |
| Expressive / artistic | `typeui-artistic` | `typeui-dramatic` | Design tools, non-enterprise vibe-forward. |
| Raw / statement (neobrutalism) | `typeui-neobrutalism` | `typeui-bold` | Gen-Z, indie, deliberate rule-breaking. |
| Premium / luxury | `typeui-dramatic` | `typeui-paper` | No dedicated luxury skill — combine dramatic hero with paper's typographic restraint, then commission custom tokens via `/frontend-design`. |
| Tech / cyberpunk | `typeui-dashboard` | `typeui-bold` | Dashboard dark base + bold accent/glow; extend via `/frontend-design` for neon/chromatic detail. |
| Warm / organic | `typeui-paper` | `typeui-doodle` | Paper carries the warmth via texture + typographic rhythm; doodle adds hand-made detail for craft brands. |
| Retro / nostalgic | `typeui-paper` | `typeui-doodle` | Paper's print-era cues fit mid-century/editorial retro; doodle for 90s/zine nostalgia. `/frontend-design` required for period-specific palettes. |
| Dark / cinematic | `typeui-dramatic` | `typeui-dashboard` | Dramatic for narrative hero surfaces; dashboard for operator/app surfaces that must stay dark through the product. |

Read this table as: "if the positioning brief (sd-research §4) lands on vibe X,
sd-audit/sd-fix should recommend the **primary** skill first; if the project
has constraints that rule it out (e.g. already on a light palette), fall back
to the secondary; if both are partial, log a non-blocking advisory that
`/frontend-design` is required to finish the aesthetic."

## Recommending a skill in a finding

When `design-intelligence.categories.design_system_coherence.score ≤ 4`,
sd-audit MUST add a non-blocking advisory finding:

```json
{
  "id": "F-NNNN",
  "rule": "design-system-coherence",
  "severity": 2,
  "risk_for_fix": "HIGH",
  "finding": "UI uses pure shadcn defaults with no identity. Recommend applying a design skill to establish visual language.",
  "template_id": "DSC-1",
  "advisory_only": true,
  "recommended_skills": ["typeui-dashboard", "typeui-application"],
  "why": "Admin/dashboard context; dark theme already present; data density matches cloud-platform skills.",
  "application": "User runs /simplify or a frontend-design session with the chosen skill active — this is not auto-fixable, needs human design decision."
}
```

Do NOT auto-apply design skills via sd-fix — aesthetic changes are always
HIGH risk and require human sign-off. The finding is informational:
sd-fix emits it into fix-report.md as "Proposed aesthetic direction" with
a preview capability (sd-research already has screenshots of competitors
in similar aesthetics to show reference).

## Integration with frontend-design plugin

If the user runs `/frontend-design` after super-design, the plugin can
read `design-intelligence.json` and pre-load the `recommended_skills`
automatically as seed context.

## References

- typeui.sh catalog — https://www.typeui.sh/design-skills
- shadcn/ui — https://ui.shadcn.com
- Karri Saarinen, Quality — https://linear.app/now/why-is-quality-so-rare
- Vercel Design Engineering — https://vercel.com/blog/design-engineering-at-vercel
