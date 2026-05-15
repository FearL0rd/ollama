# Claude Development System - Agent Context

This file provides detailed context for the development system installed by `start-vibing v4`.
For user-facing project rules, see `/CLAUDE.md`.

---

## What start-vibing v4 Installs

start-vibing is a CLI (`npx start-vibing`) that sets up Claude Code with a complete development system in ~30 seconds:

| Component | Count | Installation Method |
|-----------|-------|-------------------|
| **MCP Servers** | 8 | `claude mcp add` (parallel, ~20s) |
| **Plugins** | 9 | `claude plugin install` (parallel, auto-accept, ~3s) |
| **Community Skills** | 5 | Direct HTTPS download from GitHub (~0.3s) |
| **Template Files** | ~30 | File copy (agents, skills, config, CLAUDE.md) |

### Installation Architecture

```
npx start-vibing
├── Phase 1: Copy template files (agents, skills, config)
├── Phase 2: Verify/install Claude Code CLI
├── Phase 3: Install 8 MCP servers (parallel via Promise.all)
├── Phase 4: Install 9 plugins (parallel, stdin auto-accept 'y')
├── Phase 5: Download 5 community skills (parallel HTTPS from GitHub)
└── Phase 6: Launch Claude Code (resume last session or new)
```

All phases run best-effort. MCP and plugin failures are non-blocking — `settings.json` `enabledPlugins` is the fallback for plugins.

### CLI Options

| Flag | Effect |
|------|--------|
| `--force` | Overwrite all files (including custom ones) |
| `--new` | Start fresh Claude session (default: resume last) |
| `--no-claude` | Skip Claude Code installation and launch |
| `--no-mcp` | Skip MCP server installation |
| `--no-skills` | Skip community skills installation |
| `--no-update-check` | Skip version check |

---

## System Architecture

```
.claude/
├── agents/          # 5 active subagents (flat structure)
├── skills/          # Custom + 5 community skills (auto-injected by description match)
├── scripts/         # Utility scripts
├── config/          # Project-specific configuration (JSON files)
└── commands/        # Slash commands (feature, fix, research, validate)
```

---

## Agents (5 Active Subagents)

| Agent | Model | Purpose |
|-------|-------|---------|
| **research-web** | sonnet | Researches best practices (2025-2026) with ontology-based structuring, output to `/docs/research/` |
| **documenter** | sonnet | Analyzes sessions via git log/diff, writes changelog + technical docs + ADRs to `/docs/` |
| **commit-manager** | haiku | Manages git commits, conventional format, merge workflow |
| **claude-md-compactor** | sonnet | Compacts CLAUDE.md when it exceeds 40k chars |
| **tester-unit** | sonnet | Creates unit tests with Vitest for new functions and utilities |

### Agent Workflow Order

```
implement -> quality gates -> documenter -> commit-manager -> complete
```

Agents are dispatched via the `Agent` tool with `subagent_type` matching agent names. They run autonomously and return results to the orchestrator.

### Research Agent Details

The research-web agent outputs findings to `/docs/research/[topic].md` (NOT to `.claude/skills/research-cache/`).

**Research flow:**
1. Check `/docs/research/` for existing findings (reuse if fresh < 3 months)
2. Build ontology map (concepts → relationships → constraints)
3. Search with `[topic] [aspect] [2025-2026] [context]` queries
4. Triangulate (3+ sources for any claim)
5. Save structured output to `/docs/research/`

**For UI/UX tasks, the agent also runs:**
- Competitor analysis (3-5 competitors, heuristic evaluation)
- Design system pattern check (shadcn/ui, Radix, WCAG 2.1)
- User flow mapping (happy path + 2 error paths)
- Accessibility audit plan (axe, keyboard nav, screen reader)

### Documenter Agent Details

The documenter agent runs after implementation, analyzes the session, and writes structured docs to `/docs/`.

**Documentation flow:**
1. Run `git log` + `git diff` to analyze what changed
2. Classify changes: per-commit, per-feature, per-session
3. Mini-research for technologies used (check `/docs/research/` first, else 1-2 queries)
4. Write changelog (`/docs/changelog/`), technical docs (`/docs/technical/`), ADRs (`/docs/decisions/`)
5. Update all indexes (`/docs/index.md` + per-folder indexes)

**Output structure:**
```
/docs/
├── index.md              # Root index
├── changelog/            # Per-session changelogs
│   ├── index.md
│   └── YYYY-MM-DD-summary.md
├── technical/            # Deep feature/architecture docs
│   ├── index.md
│   └── feature-name.md
├── decisions/            # Architecture Decision Records
│   ├── index.md
│   └── NNNN-decision.md
└── research/             # Managed by research-web
    ├── index.md
    └── topic.md
```

**Writing rules:**
- Self-contained sections (AI RAG chunk retrieval)
- What→Why→How progression (humans first)
- Before→After pattern for all changes (mandatory)
- Consistent terminology (one name per concept)
- Official docs URLs for all technologies cited
- Every doc linked from its folder index AND root index

---

## Plugins (9 via enabledPlugins)

Plugins are the primary extension mechanism. All 9 are installed in parallel with auto-accept (`stdin.write('y\n')` x3). If CLI install fails, `settings.json` `enabledPlugins` ensures they activate on next Claude session.

### Core Workflow Plugins

| Plugin | Mechanism | Purpose |
|--------|-----------|---------|
| **superpowers** | Skills + commands | TDD, brainstorming, debugging, planning, code review, git worktrees |
| **ralph-loop** | Stop hook + command | Iterative autonomous development loop with checkpoints |
| **context7** | Skill + agent + MCP | Auto library docs — replaces manual context7 MCP server |
| **code-simplifier** | Skill + command | Refine code for clarity, reduce nesting, improve naming |

### Development Plugins

| Plugin | Mechanism | Purpose |
|--------|-----------|---------|
| **typescript-lsp** | LSP server (auto) | Type diagnostics, go-to-definition, hover info |
| **security-guidance** | PreToolUse hook (auto) | OWASP Top 10, vulnerability scan, blocks unsafe patterns |
| **code-review** | `/code-review` command | Code quality analysis, PR review |
| **commit-commands** | `/commit` command | Git commit, push, PR flows with conventional format |
| **frontend-design** | `/frontend-design` command | Production-grade UI design with competitor research |

### Plugin Installation Details

```typescript
// How plugins are installed (src/plugins.ts):
// 1. Check if already installed via `claude plugin list`
// 2. Spawn `claude plugin install <name>@claude-plugins-official --scope user`
// 3. Auto-accept all prompts via stdin: proc.stdin.write('y\n') x3
// 4. All 9 run in parallel via Promise.all (completes in ~3s)
// 5. Fallback: settings.json enabledPlugins activates them even if CLI install fails
```

### Using Superpowers (RECOMMENDED)

Superpowers provides structured workflows for feature development:

```
/brainstorming                   → Before designing features (ALWAYS for creative work)
/write-plan                      → Plan multi-step implementations into executable specs
/execute-plan                    → Execute plans with TDD (red-green-refactor cycle)
/systematic-debugging            → Debug with root-cause analysis (not guessing)
/verification-before-completion  → Verify before claiming work is done
/requesting-code-review          → Get review after major features
/dispatching-parallel-agents     → Run 2+ independent tasks in parallel via subagents
/using-git-worktrees             → Isolate feature work from current branch
```

### Using Ralph Loop (FOR BIG TASKS)

Ralph Loop runs Claude autonomously in a continuous implementation loop:

```
/ralph-loop "implement full CRUD for users" --max-iterations 10
/cancel-ralph   → Abort if needed
```

All file changes and git history persist between iterations. Best for multi-file features, complex refactors, or sustained autonomous work.

### Using Code Simplifier (POST-IMPLEMENTATION)

After implementing, run `/simplify` to:
- Reduce nesting and redundancy
- Improve naming and readability
- Replace nested ternaries with early returns
- Simplify without changing behavior

---

## MCP Servers (8 Installed)

All 8 MCPs are installed in parallel via `claude mcp add -s user` (~20s total). Each runs as a subprocess spawned by Claude Code on demand.

### Required MCPs (ALWAYS use these)

| Server | Package | Purpose |
|--------|---------|---------|
| `sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | Structured reasoning for multi-step tasks, architecture decisions, debugging |
| `playwright` | `@playwright/mcp@latest` | Browser automation for UI verification, E2E tests, visual validation |

> These 2 are **non-negotiable**. Skipping them leads to poor planning and untested UIs.

> **Note**: `context7` is now a **plugin** with auto-invocation skill (not an MCP). Library docs are fetched automatically when you use any library.

### Standard MCPs

| Server | Package | Transport | Purpose |
|--------|---------|-----------|---------|
| `memory` | `@modelcontextprotocol/server-memory` | stdio (npx) | Persistent knowledge graph across sessions |
| `nextjs-devtools` | `next-devtools-mcp@latest` | stdio (npx) | Next.js runtime errors, routes, cache inspection |
| `mongodb` | `@mongodb-js/mongodb-mcp-server` | stdio (npx) | MongoDB queries, schema inspection, aggregation |
| `jira` | `@aashari/mcp-server-atlassian-jira` | stdio (npx) | Issue tracking, task management |
| `git` | `mcp-server-git` | stdio (uvx) | Git operations, repo search, history, diffs |
| `fetch` | `mcp-server-fetch` | stdio (uvx) | Fetch web pages as markdown |

### Optional MCPs (install manually)

These are shown to the user after setup but not auto-installed:

| Server | Install Command |
|--------|----------------|
| `github` | `claude mcp add --transport http -s user github https://api.githubcopilot.com/mcp/` |
| `sentry` | `claude mcp add --transport http -s user sentry https://mcp.sentry.dev/mcp` |
| `figma` | `claude mcp add --transport http -s user figma https://mcp.figma.com/mcp` |
| `linear` | `claude mcp add --transport http -s user linear https://mcp.linear.app/sse` |
| `stripe` | `claude mcp add --transport http -s user stripe https://mcp.stripe.com` |
| `vercel` | `claude mcp add --transport http -s user vercel https://mcp.vercel.com` |

---

## Community Skills (5 from GitHub)

Skills are SKILL.md files placed in `.claude/skills/<name>/SKILL.md`. They are auto-injected into Claude's context when the task matches their frontmatter `description`.

### Installation Method

Community skills are downloaded directly from GitHub raw URLs (the `skillsadd` npm package is deprecated — its backend `skills.ws` is down). Each skill is a single SKILL.md file.

```typescript
// How skills are installed (src/skills.ts):
// 1. Check if .claude/skills/<name>/SKILL.md already exists (skip if so)
// 2. HTTPS GET from raw.githubusercontent.com/<owner>/<repo>/main/skills/<name>/SKILL.md
// 3. Write to .claude/skills/<name>/SKILL.md
// 4. All 5 run in parallel via Promise.all (completes in ~0.3s)
// 5. No external CLI dependency — just Node.js https module
```

### Installed Skills

| Skill | Source Repo | Purpose |
|-------|------------|---------|
| **react-best-practices** | `vercel-labs/agent-skills` | React/Next.js performance optimization rules |
| **web-design-guidelines** | `vercel-labs/agent-skills` | 100+ WCAG accessibility + UX audit rules |
| **composition-patterns** | `vercel-labs/agent-skills` | Compound component and composition patterns |
| **webapp-testing** | `anthropics/skills` | Real browser test execution with Playwright |
| **mcp-builder** | `anthropics/skills` | Guide for building MCP servers |

### Adding More Skills

To install additional skills from [skills.sh](https://skills.sh), use the working CLI:

```bash
# List available skills in a repo
npx skills add vercel-labs/agent-skills --list

# Install a specific skill
npx skills add vercel-labs/agent-skills --skill <name> --yes

# Install from anthropics
npx skills add anthropics/skills --skill <name> --yes

# Manual fallback (if CLI fails)
mkdir -p .claude/skills/<name>
curl -o .claude/skills/<name>/SKILL.md \
  https://raw.githubusercontent.com/<owner>/<repo>/main/skills/<name>/SKILL.md
```

---

## Configuration Files

Project-specific settings in `.claude/config/`:

| File | Purpose |
|------|---------|
| `project-config.json` | Stack, structure, commands |
| `quality-gates.json` | Quality check commands |
| `testing-config.json` | Test framework and conventions |
| `security-rules.json` | Security audit rules |

Agents read config files before acting. Do NOT hardcode project specifics — update the JSON files instead.

---

## settings.json (enabledPlugins)

The `.claude/settings.json` file contains `enabledPlugins` which is the fallback mechanism for plugin activation. Even if `claude plugin install` fails, having the plugin listed in `enabledPlugins` ensures Claude prompts to install it on first use.

```json
{
  "enabledPlugins": {
    "typescript-lsp@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "ralph-loop@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true
  }
}
```

---

## Execution Protocol

### Before Implementation

1. Use `/brainstorming` for creative work or feature design
2. Use `/write-plan` for multi-step tasks
3. Use `context7` (auto via plugin) for library docs
4. Research if needed (research-web agent → saves to `/docs/research/`)

### During Implementation

1. Use superpowers TDD (red-green-refactor)
2. Use `/ralph-loop` for autonomous big tasks
3. Run quality gates as you go

### After Implementation

1. Run `/simplify` (code-simplifier) on changed files
2. Run quality gates (`bun run typecheck && lint && test`)
3. Run documenter agent (changelog + technical docs + ADRs to `/docs/`)
4. Update CLAUDE.md with architecture changes
5. Commit via commit-manager agent (FINAL step)

---

## Documentation Policy

> Documentation is automatic via the **documenter agent**. It lives in `/docs/`.

### After Completing Work

The documenter agent runs automatically after implementation:
1. Analyzes git log/diff for the session
2. Writes changelog + technical docs + ADRs as needed
3. Updates all indexes
4. Docs are ready for commit

### Research Output

Research findings go to `/docs/research/[topic].md` — NOT to `.claude/skills/research-cache/`.

- Ontology-based structure: concepts → relationships → constraints → implementation path
- Freshness tracked per file (< 3 months fresh, 3-6 aging, 6-12 stale, > 12 outdated)
- Always check existing research before running new searches

### What NOT to Do

- Do NOT maintain `.claude/skills/codebase-knowledge/domains/` (legacy)
- Do NOT save research to `.claude/skills/research-cache/` — use `/docs/research/` instead
- Do NOT mix doc types in one file (changelog ≠ technical ≠ decision)
- Do NOT leave docs unlinked from indexes
- Do NOT skip Before→After pattern in changelogs

---

## Quality Requirements

All implementations MUST:

- [ ] Pass typecheck (`bun run typecheck`)
- [ ] Pass lint (`bun run lint`)
- [ ] Pass unit tests (`bun run test`)
- [ ] Be documented by documenter agent (changelog + technical/ADR if applicable)
- [ ] Be committed with conventional commits
- [ ] Have CLAUDE.md updated with architecture/rule changes

---

## FORBIDDEN Actions

| Action                         | Reason                       |
| ------------------------------ | ---------------------------- |
| Write in non-English           | ALL code/docs MUST be in EN  |
| Skip typecheck                 | Catches runtime errors       |
| Use `any` type                 | Defeats strict mode          |
| Define types in `src/`         | Must be in `types/`          |
| Commit directly to main        | Create feature/fix branches  |
| Skip documenter after implementation | Changelog + docs are mandatory |
| Mix doc types in one file      | Changelog ≠ technical ≠ decision |
| Leave docs unlinked from index | Undiscoverable docs are useless |
| Skip superpowers for features  | Use brainstorming + TDD      |
| Skip code-simplifier           | Run /simplify post-implementation |
| Use MUI/Chakra                 | Use shadcn/ui + Radix        |
| Files > 400 lines              | MUST split into smaller      |
| 'use client' at top level      | Push to leaf components only |
| Waterfall data fetching        | Use Promise.all() for parallel |
| Skip CLAUDE.md update          | MUST update after implementations |

---

## Updating start-vibing

```bash
# Update to latest version
npx start-vibing@latest

# Force overwrite all template files (preserves custom skills)
npx start-vibing --force

# Check current version
npx start-vibing --version
```

Template files use smart copy: `.claude/settings.json`, `CLAUDE.md`, and custom skills in `.claude/skills/` are preserved by default. Use `--force` to overwrite everything.
