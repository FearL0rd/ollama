# Project Rules

> **CHARACTER LIMIT**: Max 40,000 chars. Validate with `wc -m CLAUDE.md` before commit.

---

## Last Change

**Branch:** main
**Date:** YYYY-MM-DD
**Summary:** Initial setup with start-vibing v4.

---

## 30 Seconds Overview

UPDATE THIS WITH YOUR PROJECT DESCRIPTION

---

## Stack

| Component  | Technology                 |
| ---------- | -------------------------- |
| Runtime    | Bun / Node.js              |
| Language   | TypeScript **strict mode** |
| Validation | Zod                        |
| Database   | MongoDB + Mongoose         |
| Testing    | Vitest + Playwright        |
| UI         | React + Tailwind + shadcn  |
| Data       | TanStack Query + Sonner    |
| Forms      | react-hook-form + Zod      |

---

## Architecture

```
project-root/
├── CLAUDE.md              # THIS FILE - project rules (40k char max)
├── .claude/
│   ├── agents/            # 4 active subagents
│   ├── skills/            # Custom skills (auto-injected by Claude)
│   ├── scripts/           # Utility scripts
│   ├── config/            # Project configuration
│   └── commands/          # Slash commands
├── src/
│   ├── app/               # Next.js app router
│   │   ├── (marketing)/   # Route group - public pages
│   │   ├── (app)/         # Route group - authenticated
│   │   │   └── dashboard/
│   │   │       ├── page.tsx
│   │   │       └── _components/  # Page-specific components
│   │   ├── layout.tsx     # Root layout with providers
│   │   └── loading.tsx    # Global loading skeleton
│   ├── components/
│   │   ├── ui/            # shadcn primitives
│   │   ├── layout/        # Header, Sidebar, Footer
│   │   ├── shared/        # Cross-feature components
│   │   └── providers.tsx  # Context providers (client)
│   └── lib/
│       ├── utils.ts       # cn utility (MANDATORY)
│       └── api/           # axios instances
├── types/                 # ALL TypeScript interfaces (MANDATORY)
├── tests/                 # Test files
└── docs/                  # Documentation (when user requests it)
```

---

## Workflow

```
0. TODO LIST      →  Create detailed todo list from prompt
1. BRANCH         →  Create feature/ | fix/ | refactor/ | test/
2. RESEARCH       →  Use context7 plugin + web search for NEW features
3. PLAN           →  Use superpowers brainstorming + EnterPlanMode
4. IMPLEMENT      →  Use superpowers TDD + ralph-loop for iteration
5. TEST           →  Run tester-unit agent OR Playwright MCP
6. QUALITY        →  bun run typecheck && lint && test
7. SIMPLIFY       →  Run /simplify (code-simplifier) on changed files
8. ASK USER       →  "Done! Want me to document this in /docs?"
9. COMMIT         →  Conventional commits, merge to main
```

---

## Key Plugins (9 installed)

| Plugin | Purpose | Invocation |
|--------|---------|------------|
| **superpowers** | TDD, debugging, brainstorming, planning | Auto + `/brainstorming`, `/execute-plan` |
| **ralph-loop** | Iterative autonomous dev loop | `/ralph-loop "task" --max-iterations 10` |
| **context7** | Auto library docs (replaces MCP) | Auto-invokes on library mentions |
| **code-simplifier** | Refine code quality post-implementation | `/simplify` or ask Claude |
| **typescript-lsp** | Type diagnostics, go-to-def | Auto (LSP server) |
| **security-guidance** | OWASP vulnerability scan | Auto (PreToolUse hook) |
| **code-review** | PR analysis | `/code-review` |
| **commit-commands** | Git commit, push, PR | `/commit` |
| **frontend-design** | Production-grade UI design | `/frontend-design` |

### Superpowers Workflow (USE THIS)

```
1. /brainstorming        →  Before any creative work or feature design
2. /write-plan           →  Design implementation plan
3. /execute-plan         →  Execute with TDD (red-green-refactor)
4. /systematic-debugging →  When bugs appear (root cause first)
5. /verification-before-completion →  Before claiming done
```

### Ralph Loop (USE FOR BIG TASKS)

```bash
/ralph-loop "implement the full auth system with login, register, forgot password" --max-iterations 15
```

Claude works autonomously until the task is complete or hits the iteration limit.

---

## Agent System (4 Subagents)

| Agent | Purpose |
|-------|---------|
| **research-web** | Researches best practices before new features |
| **commit-manager** | Manages git commits, conventional format |
| **claude-md-compactor** | Compacts CLAUDE.md when > 40k chars |
| **tester-unit** | Creates unit tests with Vitest |

---

## Documentation Policy

> Documentation lives in `/docs` and is created **only when the user asks**.

After completing any task, Claude should ask:
```
Done! Finished [task description]. Want me to:
1. Document this in /docs?
2. Move on to the next task?
```

Do NOT auto-document. Do NOT maintain domain docs. Keep it simple.

---

## CLAUDE.md Update Rule (POST-IMPLEMENTATION)

> After ANY implementation, update this file to reflect the current state.

| Change Type | Sections to Update |
|-------------|-------------------|
| Any file change | Last Change (branch, date, summary) |
| New feature | 30s Overview, Architecture |
| New dependency | Stack |
| Workflow change | Workflow section |

Keep only the LATEST Last Change entry (no stacking).

---

## Critical Rules

### HTTP Requests (MANDATORY)

| Rule | Implementation |
|------|----------------|
| Use axios ONLY | Never `fetch()` or raw `axios` |
| `withCredentials: true` | ALWAYS for cookies/sessions |
| Extend base instance | Create `lib/api/axios.ts` |
| Type responses | `api.get<User>('/users')` |
| Centralize errors | Use interceptors |

### Path Aliases (MANDATORY)

| Alias      | Maps To             | Use For       |
| ---------- | ------------------- | ------------- |
| `$types/*` | `./types/*`         | Type defs     |
| `@common`  | `./common/index.ts` | Logger, utils |
| `@db`      | `./common/db/`      | DB connection |

### TypeScript Strict

```typescript
process.env['VARIABLE']; // CORRECT (bracket notation)
source: 'listed' as const; // CORRECT (literal type)
```

---

## Quality Gates

```bash
bun run typecheck     # MUST pass
bun run lint          # MUST pass
bun run test          # MUST pass
```

---

## Commit Format

```
[type]: [description]

- Detail 1
- Detail 2

Generated with Claude Code
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`

---

## FORBIDDEN Actions

| Action                         | Reason                       |
| ------------------------------ | ---------------------------- |
| Write in non-English           | ALL code/docs MUST be in EN  |
| Skip typecheck                 | Catches runtime errors       |
| Use `any` type                 | Defeats strict mode          |
| Define types in `src/`         | Must be in `types/`          |
| Commit directly to main        | Create feature/fix branches  |
| Use MUI/Chakra                 | Use shadcn/ui + Radix        |
| Wildcard icon imports          | Use named imports            |
| Files > 400 lines              | MUST split into smaller      |
| 'use client' at top level      | Push to leaf components only |
| Waterfall data fetching        | Use Promise.all() for parallel |
| Auto-document without asking   | Ask user first               |
| Skip superpowers for features  | Use brainstorming + TDD      |

---

## UI Architecture (MANDATORY)

> Web apps MUST have **separate UIs** for each platform.

| Platform          | Layout                                      |
| ----------------- | ------------------------------------------- |
| Mobile (375px)    | Full-screen modals, bottom nav, touch-first |
| Tablet (768px)    | Condensed dropdowns, hybrid nav             |
| Desktop (1280px+) | Sidebar left, top navbar with search        |

---

## MCP Servers

| Server                | Purpose                 | When to Use                          |
| --------------------- | ----------------------- | ------------------------------------ |
| `sequential-thinking` | Complex problem-solving | Multi-step tasks, planning           |
| `memory`              | Persistent knowledge    | Store/recall project patterns        |
| `playwright`          | Browser automation      | UI testing, page verification        |
| `nextjs-devtools`     | Next.js dev tools       | Next.js projects only                |
| `mongodb`             | Database operations     | DB queries, schema inspection        |

> Note: `context7` is now a **plugin** (auto-invokes on library mentions).

---

## Community Skills (from GitHub)

| Skill | Source | Purpose |
|-------|--------|---------|
| **react-best-practices** | vercel-labs | React/Next.js perf optimization rules |
| **web-design-guidelines** | vercel-labs | 100+ WCAG + UX audit rules |
| **composition-patterns** | vercel-labs | Compound component patterns |
| **webapp-testing** | anthropics | Real browser test execution |
| **mcp-builder** | anthropics | MCP server development guide |

---

## Configuration

Edit these files in `.claude/config/` for your project:

| File                  | Purpose                    |
| --------------------- | -------------------------- |
| `project-config.json` | Stack, structure, commands |
| `quality-gates.json`  | Quality check commands     |
| `testing-config.json` | Test framework config      |
| `security-rules.json` | Security audit rules       |

---

## Setup by start-vibing

This project was set up with `npx start-vibing`.
For updates: `npx start-vibing --force`
