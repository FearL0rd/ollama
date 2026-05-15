# Claude System

## Last Update

- **Date:** 2026-02-28
- **Commit:** pending
- **Session:** Removed hooks (stop-validator, user-prompt-submit), removed 3 skills (hook-development, mongoose-patterns, playwright-automation), updated architecture to 6 agents + 20 skills + 5 plugins

## Files

### Agents (4 active)

- `.claude/agents/research-web.md` - Researches best practices (2024-2026) before implementation
- `.claude/agents/commit-manager.md` - Manages git commits and workflow
- `.claude/agents/claude-md-compactor.md` - Compacts CLAUDE.md when > 40k chars
- `.claude/agents/tester-unit.md` - Creates unit tests with Vitest

### Archived Agents

- `.claude/agents/_archive/` - 82+ archived agents (unused, kept for reference)

### Skills (20 active)

- `.claude/skills/bun-runtime/` - Bun runtime patterns
- `.claude/skills/codebase-knowledge/` - Domain mapping system
- `.claude/skills/debugging-patterns/` - Error resolution patterns
- `.claude/skills/docker-patterns/` - Docker multi-stage and security
- `.claude/skills/docs-tracker/` - Documentation tracking
- `.claude/skills/final-check/` - Final validation rules
- `.claude/skills/git-workflow/` - Git workflow rules
- `.claude/skills/nextjs-app-router/` - Next.js App Router patterns
- `.claude/skills/performance-patterns/` - Performance profiling
- `.claude/skills/quality-gate/` - Quality gate definitions
- `.claude/skills/react-patterns/` - React 19 patterns
- `.claude/skills/research-cache/` - Best practices research cache
- `.claude/skills/security-scan/` - Security audit rules (OWASP)
- `.claude/skills/shadcn-ui/` - shadcn/ui theming and accessibility
- `.claude/skills/tailwind-patterns/` - Tailwind CSS patterns
- `.claude/skills/test-coverage/` - Test coverage tracking
- `.claude/skills/trpc-api/` - tRPC type-safe API patterns
- `.claude/skills/typescript-strict/` - TypeScript strict mode
- `.claude/skills/ui-ux-audit/` - UI/UX audit rules
- `.claude/skills/zod-validation/` - Zod validation schemas

### Plugins (5 via enabledPlugins)

- `typescript-lsp` - Type diagnostics, go-to-def (LSP server, auto)
- `code-review` - Code quality, PR analysis (/code-review cmd)
- `security-guidance` - OWASP, vulnerability scan (PreToolUse hook, auto)
- `commit-commands` - Git commit, push, PR flows (/commit cmd)
- `frontend-design` - Production-grade UI design (/frontend-design cmd)

### Configuration

- `.claude/settings.json` - Agent registration, flows, rules, plugins
- `.claude/CLAUDE.md` - System documentation (agents, skills, architecture)
- `.claude/config/project-config.json` - Stack, structure, commands
- `.claude/config/quality-gates.json` - Quality check commands
- `.claude/config/testing-config.json` - Test framework config
- `.claude/config/security-rules.json` - Security audit rules

### Scripts

- `.claude/scripts/validate-skills.sh` - Skills activation check
- `.claude/scripts/mcp-quick-install.ts` - MCP server installer
- `.claude/scripts/setup-mcps.ts` - MCP setup automation

### Root Files

- `CLAUDE.md` - Project rules and conventions
- `.claude/CLAUDE.md` - Detailed system architecture

## Connections

- **All domains:** Documentation created on request only (not auto-generated)
- **Skills:** Auto-injected into context when task matches description

## Recent Commits

| Hash    | Date       | Description                                                           |
| ------- | ---------- | --------------------------------------------------------------------- |
| pending | 2026-02-28 | refactor: remove hooks, update architecture to 6 agents + 20 skills   |
| 6f3d9ff | 2026-02-24 | docs(skills): add skills activation research plan                     |
| efa7c4f | 2026-02-24 | refactor(skills): rewrite all 23 descriptions to imperative pattern   |

## Attention Points

- [2026-02-28] **No hooks** - Hooks (stop-validator, user-prompt-submit) were removed. No automated enforcement.
- [2026-02-28] **20 skills** - Down from 23. Removed: hook-development, mongoose-patterns, playwright-automation
- [2026-02-24] **Imperative descriptions** - All skill descriptions use "ALWAYS invoke when... Do NOT..." pattern for 95%+ auto-invocation
- [2026-02-19] **6 agents + 5 plugins** - Agents are subagents. Plugins auto-install via enabledPlugins in settings.json
- [2024-12-19] **Config files for project specifics** - Agents read from `.claude/config/*.json` instead of hardcoding
- [2024-12-19] **SKILL.md YAML frontmatter** - All skills MUST have `---` frontmatter with name, description
