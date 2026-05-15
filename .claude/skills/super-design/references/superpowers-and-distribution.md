# Superpowers framework + private distribution reference — PLACEHOLDER

> **This file is a placeholder.** The complete content was delivered as the
> "Superpowers and Private Claude Skill Distribution: 2026 Playbook" artifact
> in the conversation history. Paste it here (~25KB).

## What the content covers

### Part 1 — Jesse Vincent's Superpowers framework
- What Superpowers actually is (Claude Code plugin, ~14 skills + session-start hook)
- Distribution via github.com/obra/superpowers + Anthropic marketplace
- Four stated principles: TDD, systematic over ad-hoc, complexity reduction,
  evidence over claims
- The pipeline: brainstorming → writing-plans → subagent-driven-development →
  two-stage review → verification-before-completion → finishing-a-development-branch
- Jesse Vincent's background (Request Tracker, Perl pumpking, K-9 Mail,
  Keyboardio, VaccinateCA, Prime Radiant)
- Release cadence: v5.0.7 (Mar 31, 2026), last commit Apr 16, 2026
- Install: `/plugin install superpowers@claude-plugins-official`
- 355,657 installs shown on claude.com/plugins/superpowers
- Cross-platform: Cursor, Codex, OpenCode, Gemini CLI, GitHub Copilot CLI
- Reception: Simon Willison endorsement, benchmark skepticism, 94% PR rejection rate
- Relationship to Anthropic Agent Skills (complementary, not competing)

### Part 2 — Publishing Claude skills privately in 2026

#### Anthropic's official distribution layer
- Skills Directory (Dec 18, 2025) at claude.com/connectors
- Only partner-gated, no open submission
- Claude Code plugin marketplace anthropics/claude-plugins-official
- Reserved marketplace names list
- Mahesh Murag (PM) quote: "no revenue-sharing arrangements at this time"
- 3,000+ community upvotes requesting monetization, zero response from Anthropic
- Claude Marketplace at claude.com/platform/marketplace is procurement, NOT a skill store

#### Private marketplace mechanism (code.claude.com/docs/en/plugin-marketplaces)
Six channels that work today:
1. Private GitHub repo (GITHUB_TOKEN env)
2. Private GitLab/Bitbucket/self-hosted git (SSH key pre-loaded)
3. Self-hosted HTTP JSON (LiteLLM Enterprise reference)
4. Private npm registry (.npmrc auth)
5. Container seed (CLAUDE_CODE_PLUGIN_SEED_DIR env)
6. Managed settings allowlist (strictKnownMarketplaces)

Example marketplace.json:
```json
{
  "name": "super-design-private",
  "owner": { "name": "Your Agency", "email": "dev@agency.com" },
  "plugins": [
    { "source": "github", "repo": "your-org/super-design-skill", "ref": "v1.0.0" }
  ]
}
```

Install flow:
```
/plugin marketplace add your-org/super-design-marketplace
/plugin install super-design@super-design-marketplace
```

#### Team/Enterprise org-wide skill sharing (Dec 18, 2025)
- Admin-provisioned org-wide (default-on)
- Peer-to-peer sharing (off by default)
- Peer-to-org sharing (off by default)
- Skills don't sync across surfaces (Claude.ai / API / Claude Code separate)
- Collision order: enterprise > personal > project > plugin

#### Monetization platform comparison

| Platform | Fee | Strengths | Weaknesses |
|---|---|---|---|
| **Polar.sh** | 4% + $0.40 | MoR; license keys + GitHub benefits auto; best for super-design | Newer platform |
| **Lemon Squeezy** | 5% + $0.50 | Strong license API | Higher fees; onboarding rejections |
| **Gumroad** | 10% + $0.50 | Dominant for existing paid skills | 10% painful at scale |
| **Stripe** | 2.9% + $0.30 | Lowest fees | NOT merchant-of-record; build your own license server |
| **Paddle** | varies | MoR | Avoid post-2025 FTC settlement friction |
| **GitHub Sponsors** | 0% | Auto-invite sponsors to private repo | Monthly tiers only, not one-time |

#### License-key mechanics in Claude Code
- Phone-home validation (24h cached)
- Ed25519-signed offline files (~50 lines using cryptography.hazmat)
- Encrypted assets (AES-256-GCM)
- Watermarking via invisible unicode
- Telemetry keyed on sha256(license_key)

#### Existing paid Claude skills (all Gumroad, zero enforcement)
- Brian Wagner: $9-$49 bundles
- Aakash Gupta Job Search OS: $49 one-time / $250/year
- Usama Akram: 300+ skill bundle
- RAXXO Studios: €5 single, 8-skill bundle
- Alex McFarland: Plugin Marketplace Builder (Substack)
- Sahil Lavingia (Gumroad founder): free as visibility play

Price anchors: $9-$19 single, $29-$49 bundles, $49-$99 15+ skill systems, $250+/year subscription.

#### Legal: license choices for paid distribution
- **Elastic License 2.0 (RECOMMENDED for super-design)**: 3 short restrictions —
  no hosted reselling, no circumventing license-key, no removing copyright
- **PolyForm Shield 1.0.0**: source-available on GitHub, no competitor use
- **PolyForm Internal Use 1.0.0**: read-only eval version
- **Custom proprietary EULA**: per-organization seat license, no ML training clause

Trademark: CLAUDE registered USPTO, use nominative fair-use, include
"not affiliated with Anthropic" disclaimer.

#### Recommended stack for super-design
Phase 1 (internal-only): private GitHub repo + PolyForm Internal Use +
`/plugin marketplace add` with GITHUB_TOKEN.

Phase 2 (selling to agencies): Polar.sh as merchant-of-record. Product with:
- License Keys benefit (3-activation limit)
- GitHub Repository benefit pointing at private repo
- Optional file-download of super-design.skill ZIP

Pricing: $149 one-time per seat OR $29/month.

scripts/verify_license.py: 24-hour cached Polar validation pattern (~40 lines Python).

Files: LICENSE (Elastic 2.0 verbatim), EULA.md (plain-English addendum),
README.md with buy → GitHub invite → export SUPER_DESIGN_LICENSE_KEY → use.

Telemetry abuse detection via sha256(license_key) pings.

#### Deeper moat (if super-design becomes real business)
Hosted execution: Stripe-billed service running audits on your infrastructure.
Heuristics and prompts never touch customer's machine. Tabnine/Wallaby
precedent. Agent37.com positioning as "Gumroad for Claude skills" with
hosted-runtime + Stripe billing is worth evaluating.

## Where super-design uses this

- **LICENSE** (Elastic 2.0 verbatim) — see top-level file
- **EULA.md** (per-organization seat license) — see top-level file
- **README.md** install instructions use the private-marketplace pattern
- **Future scripts/verify_license.py** would follow Polar.sh 24h-cache pattern
