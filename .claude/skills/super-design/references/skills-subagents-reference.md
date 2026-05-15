# Claude Code Skills & Subagents: A Production Reference for Building `super-design`

This document is a dense, build-ready reference for authoring a production skill that lives at `.claude/skills/super-design/` and orchestrates multiple subagents under `.claude/agents/`. It consolidates the official Claude Code docs (`code.claude.com`), the Claude Developer Platform docs (`platform.claude.com`), the `anthropics/skills` and `anthropics/claude-code` repositories, and battle-tested community patterns current as of April 2026. Every non-obvious claim is cited inline.

**Naming warning up front.** An existing project named **SuperDesign** (https://github.com/superdesigndev/superdesign, VS Code extension + companion `superdesign-skill` CLI + `superdesign-mcp` server) already occupies the "design / generate UI mockups" trigger space. Keep your skill's `description` narrowly scoped to *orchestration of subagents*, or rename to something like `super-design-orchestrator` to avoid cross-triggering with its skill/MCP entries.

---

## 1. SKILL.md anatomy for Claude Code

### 1.1 Canonical frontmatter schema

All fields are optional. Only `description` is recommended so Claude knows when to invoke the skill ([code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)).

| Field | Required | Notes |
|---|---|---|
| `name` | No | Lowercase letters, digits, hyphens; **max 64 chars**; no reserved words `anthropic` / `claude`. Defaults to the directory name. |
| `description` | Recommended | **Hard limit 1,024 chars** (API validation). In the Claude Code slash-command listing, combined `description + when_to_use` is truncated at **1,536 chars** per entry. Primary triggering mechanism. |
| `when_to_use` | No | Additional trigger phrases / example requests. Appended to `description` in the listing. |
| `argument-hint` | No | Autocomplete hint, e.g. `[issue-number]` or `[filename] [format]`. |
| `disable-model-invocation` | No | `true` → only invocable via `/name`; Claude won't auto-load. Default `false`. |
| `user-invocable` | No | `false` → hidden from `/` menu (use for reference-only skills). Default `true`. |
| `allowed-tools` | No | Space-separated string or YAML list. Whitelist for no-ask permission while active; does **not** restrict (use `/permissions` deny-rules to restrict). |
| `model` | No | Override session model while skill is active. |
| `effort` | No | `low` \| `medium` \| `high` \| `xhigh` \| `max` — availability depends on model. |
| `context` | No | `fork` runs the skill body inside a forked subagent (see §3). |
| `agent` | No | Which subagent type to use when `context: fork` is set. `Explore` \| `Plan` \| `general-purpose` \| a custom agent name. Defaults to `general-purpose`. |
| `hooks` | No | Lifecycle hooks scoped to this skill only. |
| `paths` | No | Glob patterns; when set, skill auto-loads only on matching files. |
| `shell` | No | `bash` (default) or `powershell` (requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`). |

**Undocumented but accepted in the wild**: `license` (appears in Anthropic's `pdf/SKILL.md`, `canvas-design/SKILL.md` — metadata only, not parsed); `compatibility` (skill-creator, rarely needed); `version` (ignored by Claude Code); `memory`/`metadata` (not part of the documented Claude Code schema — any such field is silently ignored).

> The older Anthropic support article (support.claude.com/en/articles/12512198) claims a 200-char `description` limit. **This is outdated** — treat the platform best-practices page (1,024 chars) as authoritative.

### 1.2 How `description` drives automatic invocation — the "pushy" pattern

At startup, Claude Code scans skill directories and injects an `<available_skills>` block into the system prompt of the built-in **`Skill` tool**. Each entry exposes `name`, `description`, and `location` (`user` or `project`) — the SKILL.md body is **never** pre-loaded. Claude decides whether to call `Skill(command="super-design")` based on the description alone (reverse-engineered by Mikhail Shilkov, [mikhail.io/2025/10/claude-code-skills/](https://mikhail.io/2025/10/claude-code-skills/), consistent with the published docs).

The canonical "pushy" pattern from `skill-creator/SKILL.md` ([github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)) — quoted verbatim:

> "Claude has a tendency to 'undertrigger' skills — to not use them when they'd be useful. To combat this, please make the skill descriptions a little bit 'pushy'. So for instance, instead of *'How to build a simple fast dashboard to display internal Anthropic data.'* you might write *'How to build a simple fast dashboard to display internal Anthropic data. **Make sure to use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if they don't explicitly ask for a "dashboard."**'*"

Best-practices formula ([platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)):

- **Third person, always.** *"The description is injected into the system prompt, and inconsistent point-of-view can cause discovery problems."*
- Formula = **what it does + when to use it + key capabilities**.
- Good: `"Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."`
- Avoid: `"I can help you…"`, `"You can use this to…"`, broad catchalls like `"Assists with any development task"`.

**Under-triggering** remedies: include keywords users naturally say; front-load the use case; be pushy; add explicit trigger phrases in `when_to_use`. **Over-triggering** remedies: make description more specific or set `disable-model-invocation: true`. Recommended length: **100–200 words, comfortably under 1,024 chars** ([skill-creator scripts/improve_description.py guidance](https://github.com/anthropics/skills/blob/main/skills/skill-creator/scripts/improve_description.py)).

> "Claude only consults skills for tasks it can't easily handle on its own — simple, one-step queries like 'read this PDF' may not trigger a skill even if the description matches perfectly." — [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)

### 1.3 Progressive disclosure and the 500-line limit

Three loading levels ([platform.claude.com/docs/en/agents-and-tools/agent-skills/overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)):

| Level | Loaded when | Budget | Content |
|---|---|---|---|
| **L1 Metadata** | Always at startup | ~100 tokens / skill | `name` + `description` |
| **L2 Instructions** | When skill is triggered | target < 5k tokens | SKILL.md body |
| **L3+ Resources** | On demand via Read/Bash | effectively unlimited | Bundled files |

The 500-line rule appears in three canonical places:

> "Keep SKILL.md under 500 lines. Move detailed reference material to separate files." ([Claude Code docs](https://code.claude.com/docs/en/skills))

> "Keep SKILL.md under 500 lines; if you're approaching this limit, add an additional layer of hierarchy along with clear pointers about where the model using the skill should go next to follow up." (skill-creator)

**Anti-pattern**: nested references. *"Keep references one level deep from SKILL.md"* because Claude will `head -100` partial-read deeply nested files. Add a table of contents to any file > 100 lines.

**Session lifecycle quirk**: once invoked, the rendered SKILL.md enters the conversation as a **single message that persists for the session**; Claude Code does **not** re-read it on later turns. At auto-compaction, *"the most recent invocation of each skill is re-attached after the summary, keeping the first 5,000 tokens of each, with a combined budget of 25,000 tokens across all re-attached skills."*

### 1.4 Bundled-resources layout

The canonical hierarchy (skill-creator SKILL.md):

```
super-design/
├── SKILL.md              # required — YAML frontmatter + ≤500 lines markdown
├── scripts/              # executable code, run via Bash; output-only in context
│   ├── dispatch.py
│   └── package_artifacts.py
├── references/           # markdown docs loaded on demand
│   ├── agent-playbooks.md
│   ├── orchestration-patterns.md
│   └── troubleshooting.md
└── assets/               # templates/icons/fonts used in output
    └── design-spec-template.md
```

Conventions:

- **`scripts/`** — *"More reliable than generated code. Save tokens. Save time. Ensure consistency."* Describe scripts as **execute** (`Run \`dispatch.py\` to fan out subagents`) vs **read-as-reference** (`See \`dispatch.py\` for the algorithm`). Always forward slashes, even on Windows.
- **`references/`** — organize by variant: `references/component-design.md`, `references/systems-design.md`, etc., so Claude reads only the relevant file.
- **`assets/`** — templated output files. Use `__PLACEHOLDER__` tokens that Claude substitutes (pattern from `skill-creator/assets/eval_review.html`).

### 1.5 How agents read bundled files and the "Base Path"

When the `Skill` tool is invoked (`{"name":"Skill","input":{"command":"super-design"}}`), the tool result is a **plain-text injection** into the conversation whose first line is literally:

```
Base Path: /Users/<you>/.claude/skills/super-design/

# Super-Design Orchestrator
... body of SKILL.md (frontmatter stripped) ...
```

This is **not** an OS env var — it is prompt-injected ([mikhail.io/2025/10/claude-code-skills/](https://mikhail.io/2025/10/claude-code-skills/), consistent with docs). Claude then uses Read/Bash tools with that absolute path to reach `scripts/`, `references/`, `assets/`.

At authoring time, the portable template variable is **`${CLAUDE_SKILL_DIR}`**:

> "The directory containing the skill's SKILL.md file. For plugin skills, this is the skill's subdirectory within the plugin, not the plugin root. Use this in bash injection commands to reference scripts or files bundled with the skill, regardless of the current working directory." — [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills)

Other runtime substitutions: `$ARGUMENTS` (full raw arg string), `$ARGUMENTS[N]` / `$N` (shell-quoted positional args), `${CLAUDE_SESSION_ID}`. Inline shell injection: `` !`gh pr diff` `` (preprocessed before Claude sees the body; disable with `"disableSkillShellExecution": true`).

### 1.6 Install locations and precedence

From [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills):

| Location | Path | Scope |
|---|---|---|
| Enterprise | managed settings | org-wide |
| Personal | `~/.claude/skills/<name>/SKILL.md` | all projects |
| Project | `.claude/skills/<name>/SKILL.md` | this project |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | where plugin enabled |

Precedence: **enterprise > personal > project**; plugin skills are namespaced (`plugin:skill`) and cannot collide. If a skill and a command share a name, **the skill wins**. Edits to existing skills are hot-reloaded mid-session; adding a *new* top-level skills directory requires a restart. Monorepo auto-discovery: `packages/frontend/.claude/skills/` is auto-loaded when editing files under `packages/frontend/`. Directories added with `--add-dir` are the exception to the normal rule — their `.claude/skills/` **is** loaded. Custom skill paths outside these four locations are **not yet supported** as of Feb 2026 (open FR [anthropics/claude-code#22902](https://github.com/anthropics/claude-code/issues/22902)).

### 1.7 CLI commands (Claude Code terminal)

There is no dedicated `claude skill create`; you create skills by filesystem convention:

```bash
# Project skill (recommended for super-design)
mkdir -p .claude/skills/super-design/{scripts,references,assets}
$EDITOR .claude/skills/super-design/SKILL.md

# Or bootstrap from Anthropic's template (requires cloning anthropics/skills once)
python scripts/init_skill.py super-design --path .claude/skills
```

Invocation at runtime:

```
/super-design                         # invoke by name
/super-design "component auth" react  # with quoted args ($0="component auth", $1="react")
/plugin-name:super-design             # plugin-qualified
```

Discovery: type `/` in the prompt for autocomplete, or ask Claude `What skills are available?` (recommended in the official troubleshooting guide). Plugin manager: `/plugin`, `/plugin marketplace add <org>/<repo>`, `/plugin install <plugin>@<marketplace>`.

Useful env vars:

| Var | Effect |
|---|---|
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Raises per-session char budget for skill listings (default `max(8000, 1% of context)`). |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` | Enables `shell: powershell`. |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` | Disables background subagent execution. |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Forces all subagents to a specific model ID. |

Permission rules: `Skill` (deny-all), `Skill(super-design)` exact-match, `Skill(super-design *)` prefix-with-args.

---

## 2. Subagents in Claude Code (.claude/agents/)

### 2.1 Canonical definition

> "Subagents are specialized AI assistants that handle specific types of tasks. Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions. When Claude encounters a task that matches a subagent's description, it delegates to that subagent, which works independently and returns results." — [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents)

> "Subagents receive only this system prompt (plus basic environment details like working directory), not the full Claude Code system prompt."

Built-in subagents always available: **Explore** (Haiku, read-only, codebase discovery), **Plan** (read-only, for plan mode), **general-purpose** (all tools), plus `statusline-setup` and `Claude Code Guide`.

### 2.2 Frontmatter schema

Only `name` and `description` are required.

| Field | Notes |
|---|---|
| `name` | Lowercase + hyphens. Becomes `@agent-<name>` and the `subagent_type` parameter. |
| `description` | Drives automatic routing. Add **"use PROACTIVELY"** / **"Use immediately after…"** for auto-delegation. |
| `tools` | Comma-separated string **or** YAML array. **Omit → inherits every tool (including MCP)**. Allowlist. |
| `disallowedTools` | Denylist; resolved **before** `tools`. |
| `model` | `sonnet` \| `opus` \| `haiku` \| explicit model ID \| `inherit` (default). Resolution order: env `CLAUDE_CODE_SUBAGENT_MODEL` → per-invocation `model` param → frontmatter → main model. |
| `permissionMode` | `default` \| `acceptEdits` \| `auto` \| `dontAsk` \| `bypassPermissions` \| `plan`. Parent's `bypassPermissions`/`acceptEdits` wins. |
| `maxTurns` | Hard cap on agentic turns. |
| `skills` | List of skill names to inject into this subagent's startup context. **Full skill content is injected, not just made discoverable.** Subagents don't inherit parent skills. |
| `mcpServers` | Scope MCP servers to this subagent only; connected at start, disconnected at end. |
| `hooks` | Per-subagent lifecycle hooks. `Stop` → auto-converted to `SubagentStop`. |
| `memory` | `user` \| `project` \| `local`; auto-enables Read/Write/Edit and injects first 200 lines / 25 KB of `MEMORY.md`. |
| `background` | `true` → always background. |
| `effort` | Overrides session effort. |
| `isolation` | `worktree` → runs in a temporary git worktree (auto-cleaned if no changes). |
| `color` | `red`\|`blue`\|`green`\|`yellow`\|`purple`\|`orange`\|`pink`\|`cyan` (display only). |
| `initialPrompt` | Auto-submitted first turn when agent runs as main session via `--agent`. |

**Plugin-sourced subagents cannot use `hooks`, `mcpServers`, or `permissionMode` for security reasons** — copy into `.claude/agents/` if you need those.

### 2.3 Routing mechanics

Three invocation pathways:

1. **Automatic** — Claude reads the `description` field and calls the `Agent` tool (formerly `Task`, renamed in Claude Code **v2.1.63** — old `Task(...)` still works as alias). Automatic routing is **unreliable in practice** — community consensus is to use explicit invocation for production skills.
2. **Explicit `@-mention`** — `@agent-code-reviewer look at the auth changes` guarantees the subagent runs once.
3. **Whole-session**: `claude --agent <name>` replaces the default system prompt entirely.

Inside a SKILL.md body, natural language reliably triggers the Agent tool call:

```markdown
Use the Task tool (now called Agent) to launch the code-explorer subagent.
Each instance should:
  - Target a different aspect of the codebase
  - Return a self-contained summary

Spawn 3 instances **in parallel** (all in a single message).
```

### 2.4 Context isolation (exact semantics)

From [platform.claude.com/docs/en/agent-sdk/subagents](https://platform.claude.com/docs/en/agent-sdk/subagents):

> "A subagent's context window starts fresh (no parent conversation) but isn't empty. The only channel from parent to subagent is the Agent tool's prompt string, so include any file paths, error messages, or decisions the subagent needs directly in that prompt."

| Subagent receives | Subagent does NOT receive |
|---|---|
| Its own system prompt (markdown body) | Parent conversation history or tool results |
| The Agent tool's `prompt` argument | Skills (unless in `skills:` frontmatter) |
| Project `CLAUDE.md` (if `settingSources` permits) | Parent's system prompt |
| Tool definitions (inherited or subset) | The standard Claude Code system prompt |
| Working directory | |

Back to parent:

> "The parent receives the subagent's final message verbatim as the Agent tool result, but may summarize it in its own response. To preserve subagent output verbatim in the user-facing response, include an instruction to do so in the prompt you pass to the main `query()` call."

Transcript: persisted at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`, unaffected by parent compaction, subagent-level auto-compaction at ~95% (tunable with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`).

### 2.5 Hard limits

- **No nesting.** *"Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."* Max depth = 1.
- **Concurrency ceiling (community-measured, not Anthropic-published): ~10 concurrent tasks**, then batched — "Claude doesn't dynamically pull from the queue as Tasks complete. It waits for the entire batch to finish before starting the next one" ([amitkoth.com/claude-code-task-tool-vs-subagents](https://amitkoth.com/claude-code-task-tool-vs-subagents/)). Anthropic's research system scales to **10+ subagents** for complex research.
- **Token cost: agents ≈ 4× chat, multi-agent ≈ 15× chat** ([anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system)).
- **Subagents cannot invoke the `Skill` tool** ([issue #38719](https://github.com/anthropics/claude-code/issues/38719)) — skills must be pre-loaded via `skills:` frontmatter or the main session must orchestrate.

### 2.6 Skills inside subagents — two inverse patterns

**Pattern A — `skills:` field in subagent frontmatter** (subagent USES skills):
```yaml
---
name: api-developer
description: Implement API endpoints following team conventions
skills:
  - api-conventions
  - error-handling-patterns
---
```
> "The full content of each skill is injected into the subagent's context, not just made available for invocation. Subagents don't inherit skills from the parent conversation; you must list them explicitly." — [code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents)

**Pattern B — `context: fork` in SKILL.md** (skill RUNS in a subagent):
```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
agent: Explore
allowed-tools: Bash(gh *)
---
```
Known bug: the Skill tool may currently ignore `context: fork` / `agent:` and run inline ([issue #17283](https://github.com/anthropics/claude-code/issues/17283)).

### 2.7 CLI and install locations

```bash
/agents                             # interactive manager: list, create, edit, delete
claude agents                       # non-interactive list
claude --agent code-reviewer        # whole session as that agent
claude --agents '{ "scout": {...} }'  # ephemeral session-scoped
claude --disallowedTools "Agent(Explore)"   # block a specific subagent type
```

Precedence (highest first): managed org settings → `--agents` CLI flag → project `.claude/agents/` → `~/.claude/agents/` → plugin `agents/`. Manually adding a file usually requires restart; `/agents` edits hot-reload.

### 2.8 Canonical real examples

**Code reviewer** ([docs verbatim](https://code.claude.com/docs/en/sub-agents)):
```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- Functions and variables are well-named
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)
```

**DB reader with per-agent hook**:
```markdown
---
name: db-reader
description: Execute read-only database queries. Use when analyzing data or generating reports.
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

You are a database analyst with read-only access. If asked to modify data, explain that you only have read access.
```

**Repo explorer with memory** (community pattern matching docs):
```markdown
---
name: repo-explorer
description: Search unfamiliar codebases, map entry points, and summarize the architecture. Do not edit files.
tools: [Read, Grep, Glob]
disallowedTools: [Edit, Write, Bash]
model: haiku
permissionMode: plan
memory: project
---
Find main entry points, core data flow, likely risk areas. Return a short summary with file paths, key abstractions, and open questions. Update MEMORY.md with discoveries.
```

---

## 3. Orchestration patterns

### 3.1 The Agent (Task) tool — parameters and return

| Param | Type | Example |
|---|---|---|
| `subagent_type` | string | `"Explore"`, `"code-reviewer"`, `"general-purpose"` |
| `description` | string | `"Find auth files"` |
| `prompt` | string | Full self-contained task (subagent sees ONLY this) |
| `model` | string (optional) | `"sonnet"`, `"haiku"` |
| `run_in_background` | bool (optional) | `true` for concurrent fire-and-continue |

Pseudo-XML the model actually emits:
```
<invoke name="Agent">
  <parameter name="subagent_type">code-explorer</parameter>
  <parameter name="description">Trace auth flow</parameter>
  <parameter name="prompt">Full self-contained task with all paths and context...</parameter>
</invoke>
```

Return: only the subagent's **final assistant message** is injected into parent context. Full transcript stays on disk. Parent may summarize further unless you instruct verbatim pass-through.

### 3.2 Forcing parallel dispatch

Parallel execution happens when **all `Agent()` calls are emitted in a single assistant message**. Across separate messages → sequential.

The canonical prompt block, used in Anthropic's own research system ([simonwillison.net/2025/Jun/14/multi-agent-research-system/](https://simonwillison.net/2025/Jun/14/multi-agent-research-system/)):

```
<use_parallel_tool_calls>
For maximum efficiency, whenever you need to perform multiple
independent operations, invoke all relevant tools simultaneously
rather than sequentially. Call tools in parallel to run subagents
at the same time. You MUST use parallel tool calls for creating
multiple subagents (typically running 3 subagents at the same time)
at the start of the research, unless it is a straightforward query.
</use_parallel_tool_calls>
```

User-facing phrasings that reliably parallelize:
- *"Explore the codebase using 4 tasks in parallel. Each agent should explore different directories."*
- *"Launch 3 code-reviewer agents in parallel with different focuses: simplicity/DRY, bugs/correctness, conventions."*

Effort-scaling heuristics Anthropic embeds in prompts: simple fact-finding → **1 agent, 3–10 tool calls**; comparisons → **2–4 subagents, 10–15 calls each**; complex research → **10+ subagents**. Anthropic's research system reports the multi-agent configuration (Opus lead + Sonnet workers) outperformed single-agent Opus by **90.2%** on internal research evals.

### 3.3 Sequential vs parallel routing rules (community pattern)

From [claudefa.st/blog/guide/agents/sub-agent-best-practices](https://claudefa.st/blog/guide/agents/sub-agent-best-practices) — paste this into your orchestrator skill body or `CLAUDE.md`:

```markdown
## Sub-Agent Routing Rules
**Parallel dispatch** (ALL conditions must be met):
- 3+ unrelated tasks or independent domains
- No shared state between tasks
- Clear file boundaries with no overlap

**Sequential dispatch** (ANY condition triggers):
- Tasks have dependencies (B needs output from A)
- Shared files or state (merge conflict risk)
- Unclear scope (need to understand before proceeding)

**Background dispatch**:
- Research or analysis tasks (not file modifications)
- Results aren't blocking your current work
```

### 3.4 Hooks for chaining (SubagentStop, Stop, PreToolUse/PostToolUse)

Hook config lives in `.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`, or plugin `hooks/hooks.json`. Three-level nesting: **event → matcher group → hook handler**. Four handler types: `command` (default timeout **600s**), `http` (POST), `prompt` (LLM eval, 30s), `agent` (spawns inspection subagent, 60s). Context injection from hooks is capped at **10,000 characters**; larger content is saved to a file and replaced with a path preview.

Events relevant to orchestration:

| Event | Matcher | Can block? |
|---|---|---|
| `SubagentStart` | agent type | No (can inject context) |
| `SubagentStop` | agent type | **Yes** (exit 2 or `{"decision":"block","reason":"..."}`) |
| `PreToolUse` | `Agent` | Yes — allow/deny/ask/defer + `updatedInput` |
| `PostToolUse` | `Agent` | No (feedback only) |
| `Stop` | — | Yes |

`SubagentStop` input (verbatim from docs):
```json
{
  "session_id": "abc123",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../abc123/subagents/agent-def456.jsonl",
  "last_assistant_message": "Analysis complete. Found 3 potential issues..."
}
```

Always check `stop_hook_active` to avoid infinite loops — it's `true` when Claude is already continuing from a prior blocked stop.

**Example: project `.claude/settings.json` dispatcher**:

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "sd-research",
        "hooks": [
          { "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/next-step.sh",
            "timeout": 30 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/safety-net.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          { "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/gate-subagent.sh" }
        ]
      }
    ]
  }
}
```

**Example: `.claude/hooks/next-step.sh`** — a queue-popping hook that forces Claude to dispatch the next subagent:

```bash
#!/bin/bash
INPUT=$(cat)
QUEUE=".claude/queue.jsonl"
NEXT=$(head -n 1 "$QUEUE")
[ -z "$NEXT" ] && exit 0                # queue empty → allow stop
tail -n +2 "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"

NEXT_AGENT=$(echo "$NEXT"  | jq -r '.agent')
NEXT_PROMPT=$(echo "$NEXT" | jq -r '.prompt')

jq -n --arg a "$NEXT_AGENT" --arg p "$NEXT_PROMPT" '{
  decision: "block",
  reason: ("Previous subagent finished. Next: invoke the " + $a +
           " subagent with prompt: " + $p)
}'
```

A `SubagentStop` output of `{"decision":"block","reason":"..."}` forces Claude to continue; the `reason` arrives as a system reminder that it obeys. Common failure mode (PubNub): output must go to **STDOUT, not `/dev/tty`**.

**`async: true`** (January 2026+) lets command hooks run non-blockingly; `asyncRewake: true` wakes Claude on exit code 2 by feeding stderr as a system reminder.

### 3.5 Handoff mechanisms — files vs prompts

| Mechanism | Pros | Cons |
|---|---|---|
| **Return value (prompt string)** | Zero coord, automatic summarization | Non-deterministic, parent-context bloat, reports of 160k-token runs for 3k-token work |
| **Files on disk** | Deterministic, debuggable, tiny parent context | Requires explicit write protocol |
| **Agent memory (`memory:` field)** | Persists across sessions | Shared-write contention |
| **`isolation: worktree`** | Per-subagent repo checkout | Auto-cleaned only if no changes |
| **`SendMessage` / agent teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | Background resume without new `Agent` call | Experimental |

The **file-based pattern is what Anthropic itself uses** for long-running research:

> "We implemented patterns where agents summarize completed work phases and store essential information in external memory before proceeding to new tasks. When context limits approach, agents can spawn fresh subagents with clean contexts while maintaining continuity through careful handoffs." — [anthropic.com/engineering/multi-agent-research-system](https://www.anthropic.com/engineering/multi-agent-research-system)

Canonical workspace layout (from `altmbr/claude-research-skill`, mirrored by skill-creator):

```
super-design-workspace/
└── <session-id>/
    ├── brief.md              # orchestrator writes; workers read
    ├── agent-1-research.md   # worker 1 output
    ├── agent-2-design.md     # worker 2 output
    ├── agent-3-critique.md   # worker 3 output
    └── synthesis.md          # final synthesis-agent output
```

Enforce a **write-after-every-search** protocol in your worker prompts: "search → write → search → write" (agents that research without writing get stuck in loops — per the research-skill repo).

### 3.6 Queue pattern with a hook watcher

```
.claude/
├── settings.json                 # registers SubagentStop + Stop hooks
├── queue.jsonl                   # one JSON task per line
├── skills/super-design/SKILL.md  # orchestrator
├── agents/                       # workers
│   ├── sd-research.md
│   ├── sd-design.md
│   └── sd-critique.md
└── hooks/
    ├── next-step.sh              # pops queue, blocks stop
    └── safety-net.sh             # Stop fallback
```

`queue.jsonl`:
```jsonl
{"id":"t1","agent":"sd-research","prompt":"Gather design constraints for $TARGET","status":"pending"}
{"id":"t2","agent":"sd-design","prompt":"Produce 3 design candidates using research/t1.md","depends_on":"t1"}
{"id":"t3","agent":"sd-critique","prompt":"Critique candidates; recommend 1","depends_on":"t2"}
```

### 3.7 Reference orchestrators in the wild

| Repo | Pattern |
|---|---|
| [wshobson/agents](https://github.com/wshobson/agents) | 182 agents + 16 workflow orchestrators; chains like `backend-architect → database-architect → frontend → test-automator → security-auditor` |
| [vanzan01/claude-code-sub-agent-collective](https://github.com/vanzan01/claude-code-sub-agent-collective) | Hub-and-spoke `@task-orchestrator` + `test-driven-handoff.sh` hook |
| [altmbr/claude-research-skill](https://github.com/altmbr/claude-research-skill) | Decompose → parallel workstreams via Task → kill-and-relaunch if stuck → synthesis |
| [obra/superpowers](https://github.com/obra/superpowers) | 20+ skills; TDD/debugging orchestrators dispatch to `.claude/agents/` specialists |
| [glebis/claude-skills](https://github.com/glebis/claude-skills) | TDD orchestrator with strict per-slice context filtering (test-writer sees spec only, implementer sees failing test only) |
| [kieranklaassen/orchestrating-swarms gist](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea) | TeammateTool + TaskCreate/TaskUpdate + per-agent JSON inboxes |
| [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) | Plan-mode phase decomposition; picks team vs subagent based on `TeamCreate` availability |
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | Builder/Validator agent pattern, per-hook UV scripts |
| [turtir-ai/nexus-v3-5](https://github.com/turtir-ai/nexus-v3-5) | `nexus_agent_dispatcher.py` routes by `task.type`; quality-gate → self-heal → auto-learn |

---

## 4. skill-creator and the Anthropic skills repo

### 4.1 Skills in `anthropics/skills`

Top-level skills at [github.com/anthropics/skills/tree/main/skills](https://github.com/anthropics/skills/tree/main/skills):

| Skill | Purpose |
|---|---|
| algorithmic-art | Generative visual art |
| brand-guidelines | Apply brand color/typography (defaults to Anthropic brand) |
| canvas-design | Visual design on a canvas surface |
| claude-api | Build LLM apps with decision tree (single call → workflow → agent) |
| doc-coauthoring | Multi-phase document collaboration (gather → refine → reader-test) |
| docx | Word creation/editing/tracked-changes (powers Claude.ai docs) |
| frontend-design | Production-grade frontend avoiding "AI slop" |
| internal-comms | 3P updates, all-hands emails, incident reports |
| mcp-builder | Guide for building MCP servers |
| pdf | PDF extraction, merge/split, form handling |
| pptx | PowerPoint creation with layouts, charts, visual QA |
| **skill-creator** | Meta-skill: create, iterate, evaluate, optimize skills |
| slack-gif-creator | Animated GIFs |
| theme-factory | Theme/style system generation |
| web-artifacts-builder | Multi-component React+shadcn artifacts |
| webapp-testing | Playwright reconnaissance-then-action |
| xlsx | Excel workbooks with formulas, charts |

Plus `spec/` (Agent Skills spec) and `template/` (starter).

### 4.2 skill-creator — authoring rules worth copying

Frontmatter (verbatim):
> `description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.`

Core writing style (verbatim):

> "Try to explain to the model why things are important in lieu of heavy-handed musty MUSTs. Use theory of mind and try to make the skill general and not super-narrow to specific examples. … If you find yourself writing ALWAYS or NEVER in all caps, or using super rigid structures, that's a yellow flag — if possible, reframe and explain the reasoning so that the model understands *why* the thing you're asking for is important."

Improvement heuristics:
1. **Generalize from feedback** — try different metaphors for stubborn issues.
2. **Keep the prompt lean** — remove what doesn't pull weight; read transcripts, not just outputs.
3. **Explain the why** — Claude has theory of mind; imperative MUSTs are a code smell.
4. **Look for repeated work across test cases** — if all 3 tests resulted in Claude writing a `build_chart.py`, bundle that script.

### 4.3 `init_skill.py` and `package_skill.py`

**`init_skill.py`** scaffolds a skill folder with `SKILL.md` (TODO frontmatter), `scripts/example.py`, `references/api_reference.md`, `assets/example_asset.txt`.
```bash
python scripts/init_skill.py super-design --path .claude/skills
```
Enforces kebab-case on `<skill-name>`. Mandate from skill-creator: *"When creating a new skill from scratch, always run the `init_skill.py` script."*

**`package_skill.py`** validates then zips a skill into a distributable `.skill` file (ZIP format).
```bash
python -m scripts.package_skill .claude/skills/super-design ./dist
```
Exclusions (verbatim):
```python
EXCLUDE_DIRS      = {"__pycache__", "node_modules"}
EXCLUDE_GLOBS     = {"*.pyc"}
EXCLUDE_FILES     = {".DS_Store"}
ROOT_EXCLUDE_DIRS = {"evals"}   # evals/ excluded only at skill root
```

Other scripts in `skills/skill-creator/scripts/`: `aggregate_benchmark.py`, `generate_report.py`, `improve_description.py`, `quick_validate.py`, `run_eval.py`, `run_loop.py`, `utils.py`.

### 4.4 Evaluation patterns

Parallel **with-skill vs without-skill** runs in the same turn (never sequentially), workspace laid out as:
```
<skill-name>-workspace/iteration-<N>/eval-<ID>/{with_skill,without_skill}/outputs/
```
Each eval has `eval_metadata.json` (`eval_id`, `eval_name`, `prompt`, `assertions`) and `timing.json` (`total_tokens`, `duration_ms`). Grade with `agents/grader.md` → `grading.json` with `text`/`passed`/`evidence` fields. Aggregate:
```bash
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name super-design
```

**Description-optimization loop** (`run_loop.py`):
```bash
python -m scripts.run_loop \
  --eval-set <trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```
Mechanics (verbatim): *"It splits the eval set into 60% train and 40% held-out test, evaluates the current description (running each query 3 times to get a reliable trigger rate), then calls Claude to propose improvements based on what failed. … It returns JSON with `best_description` — selected by test score rather than train score to avoid overfitting."* Eval set should be 20 queries total, ~50/50 should-trigger vs should-not-trigger.

### 4.5 Description-writing pitfalls (verbatim)

- "Your description should not be more than about 100-200 words, even if that comes at the cost of accuracy. **There is a hard limit of 1024 characters** — descriptions over that will be truncated."
- "Avoid lists of specific queries; instead, **generalize to categories of intent**."
- "Should use **'Use this skill for...'** rather than 'This skill does...'."
- "Focus on **user goals rather than implementation details**."
- "Don't make should-not-trigger queries obviously irrelevant. 'Write a fibonacci function' as a negative test for a PDF skill is too easy."
- "Subjective skills (writing style, design quality) are better evaluated qualitatively — don't force assertions onto things that need human judgment."
- **Overtriggering on Opus 4.5**: "Prompts designed to reduce undertriggering on previous models may cause Opus 4.5 to overtrigger." Remedy: remove "CRITICAL: You MUST…" and similar capitalized imperatives (from `claude-opus-4-5-migration/prompt-snippets.md`).

### 4.6 anthropics/claude-code plugins relevant to super-design

- **plugin-dev** — comprehensive plugin-development toolkit; 7 skills (`hook-development`, `mcp-integration`, `plugin-structure`, `plugin-settings`, `commands`, `agents`, `skill-development`); agents `agent-creator`, `plugin-validator`, `skill-reviewer`; `/plugin-dev:create-plugin` (8-phase workflow).
- **feature-dev** — "Comprehensive feature development workflow with specialized agents for codebase exploration, architecture design, and quality review." 7 phases. Its commands demonstrate the **parallel research-agent fan-out** pattern verbatim:
  > "Step 1: Launch Parallel Research Agents. Use the Task tool to spawn these subagents in parallel (all in a single message): 1. Web Documentation Agent (general-purpose) … 2. Stack Overflow Agent (general-purpose) … 3. Codebase Explorer Agent (Explore)."
- **pr-review-toolkit** — `/pr-review-toolkit:review-pr [comments|tests|errors|types|code|simplify|all]`; agents `comment-analyzer`, `pr-test-analyzer`, `silent-failure-hunter`, `type-design-analyzer`, `code-reviewer`, `code-simplifier`.
- **ralph-wiggum** — self-referential loops; Stop hook intercepts exit to continue iteration; state file `ralph-loop.local.md`.
- **hookify** — generates hooks from markdown rules without editing `hooks.json`.
- **code-review** — launches 4 review agents in parallel, filters by ≥80 confidence threshold.
- **claude-opus-4-5-migration** — anti-pattern → pattern replacement table for overtriggering.

---

## 5. A reference skeleton for `super-design`

### 5.1 Recommended directory layout

```
.claude/
├── settings.json                             # hooks config
├── skills/
│   └── super-design/
│       ├── SKILL.md                          # ≤500 lines, orchestrator
│       ├── scripts/
│       │   ├── dispatch.py                   # optional parallel dispatcher
│       │   └── synthesize.py
│       ├── references/
│       │   ├── routing-rules.md              # parallel vs sequential rules
│       │   ├── agent-playbooks.md            # what each subagent does
│       │   └── handoff-protocol.md
│       └── assets/
│           └── brief-template.md
├── agents/
│   ├── sd-research.md                        # Haiku, read-only
│   ├── sd-design.md                          # Sonnet, Write
│   ├── sd-critique.md                        # Sonnet, Read + Grep
│   └── sd-synthesis.md                       # Opus, Read + Write
└── hooks/
    ├── next-step.sh                          # queue dispatcher
    ├── safety-net.sh                         # Stop fallback
    └── gate-subagent.sh                      # PreToolUse(Agent) gate
```

### 5.2 Minimal SKILL.md starter

```yaml
---
name: super-design
description: Orchestrate multi-agent product design workflows. Use this skill whenever the user wants to produce, iterate on, or critique a non-trivial design artifact (component, page, system, or flow) that benefits from parallel research, multiple design candidates, and structured critique. Coordinates sd-research, sd-design, sd-critique, and sd-synthesis subagents with file-based handoff under super-design-workspace/. Use this skill even if the user does not explicitly ask for "orchestration" — anytime the task is large enough to need more than one perspective.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

# Super-Design Orchestrator

You coordinate a team of specialist subagents to produce high-quality design artifacts.

## Workspace

All intermediate artifacts live under `super-design-workspace/${CLAUDE_SESSION_ID}/`:
- `brief.md`     — you write this first
- `agent-*.md`   — each worker writes here
- `synthesis.md` — final synthesizer output

## Routing rules

**Parallel** when: ≥3 independent research/design threads, no shared files.
**Sequential** when: later step depends on earlier artifact or modifies shared files.

## Procedure

1. Read the user request. Write `brief.md` capturing goal, constraints, success criteria.
2. Use the Agent tool to launch in a single message (parallel):
     - sd-research (prompt: "Research constraints → write agent-research.md")
     - sd-design   (prompt: "Produce 3 candidates → write agent-design.md")
3. When both return, launch sd-critique on their outputs.
4. Launch sd-synthesis to pick one candidate and produce final deliverables.
5. Summarize path to `synthesis.md` for the user.

Every Agent call's `prompt` must be self-contained — include the brief path, artifact
paths to read, and the exact file the subagent must write. Subagents cannot see this
conversation.
```

### 5.3 A worker example (`sd-research.md`)

```yaml
---
name: sd-research
description: Gather design constraints, prior art, and reference patterns for a super-design workflow. Use when the super-design orchestrator requests research. Writes findings to the workspace file specified in the invocation prompt.
tools: Read, Grep, Glob, WebSearch, WebFetch, Write
model: haiku
memory: project
permissionMode: plan
---

You are a design researcher. Given a brief.md path and an output path:
1. Read brief.md.
2. Gather constraints, prior art, accessibility considerations, 3-5 reference links.
3. Write a concise markdown report to the output path with sections:
   Constraints / Prior art / Reference patterns / Open questions.
4. Return a 3-sentence summary of where you wrote and what you found.

Never modify code. Never read outside brief.md and the repository.
```

---

## Key takeaways

**Architecturally, a production orchestrator skill in Claude Code is three primitives glued together**: a single SKILL.md that lives in context for the whole session and contains a self-describing, "pushy" description under 1,024 characters; a roster of narrowly-scoped subagent markdown files under `.claude/agents/` invoked through the Agent tool (formerly Task, renamed v2.1.63); and a file-system workspace used as the canonical handoff medium because the parent never sees what subagents did internally — only their final message. Parallelism is a property of **one assistant message containing multiple Agent calls**, with a community-observed soft ceiling near 10 concurrent subagents and a real token-cost multiplier of ~15× over plain chat.

**The three biggest traps** for a skill like super-design: (1) naming collision with the existing SuperDesign VS Code extension — mitigate via tightly-scoped description wording or rename; (2) **subagents cannot spawn subagents and cannot invoke the Skill tool**, so any nested work must be orchestrated from the main session or pre-injected via `skills:` frontmatter; (3) `description` quality dominates triggering behavior — treat it as code, iterate it with `skill-creator`'s `run_loop.py` against a 20-query train/test split, and watch for the undertrigger-vs-overtrigger inversion that appeared with Opus 4.5.

**The proven production pattern** (Anthropic's own research system, mirrored across wshobson/agents, altmbr/claude-research-skill, vanzan01's collective, and obra/superpowers): Opus-class orchestrator plans → writes brief to disk → fans out 3–5 Sonnet/Haiku workers in parallel with self-contained prompts → workers write artifacts to a shared workspace → orchestrator reads the artifacts (not the worker return values) → a separate synthesis agent produces the final deliverable → optional SubagentStop hook chains the next phase by returning `{"decision":"block","reason":"..."}`. Everything that follows in your super-design build is elaboration on this skeleton.