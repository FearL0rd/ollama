# super-design

End-to-end design audit skill for Claude Code. Produces market analysis,
live-site UX/WCAG/CWV audit, and optional safe remediation — all with
evidence trails and per-finding severity.

## Install

1. Copy this plugin to `~/.claude/plugins/super-design/` OR install via
   `/plugin install super-design@<marketplace>`.
2. Verify MCP: `claude mcp list` — Playwright should connect.
3. Install browsers if missing: `npx playwright install chromium`.
4. Invoke: "run super-design" or "audit my site with super-design".

## Outputs

- `docs/super-design/overview.md` — executive report (committed)
- `docs/super-design/.audit-state.json` — re-audit state (committed)
- `docs/super-design/findings/F-NNNN.md` — per-finding records (committed)
- `docs/super-design/audit-history.md` — append-only log (committed)
- `docs/super-design/baseline-screenshots/` — visual regression baselines (Git LFS)
- `docs/super-design/.cache/` — ephemeral session artifacts (gitignored)

## Commands

`/super-design` — slash command. Flags: `--force-full`, `--refresh-research`,
`--only <cat>`, `--scope <url>`, `--fix`, `--dry-run`, `--ci`.

## Requirements

- Node ≥18, git ≥2.30, Python ≥3.9, Claude Code ≥2.1.
- `@playwright/mcp@0.0.70` (pinned).
- Optional: `gh` CLI, Git LFS.

## License

See LICENSE (Elastic License 2.0) and EULA.md.
