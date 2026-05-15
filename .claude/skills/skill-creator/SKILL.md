---
name: skill-creator
description: "ALWAYS invoke when creating, editing, or optimizing Claude Code skills. Do NOT create skills without following the interview, draft, test, iterate loop first."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Skill Creator

Meta-skill for creating new skills and iteratively improving them.

> Source: `anthropics/skills` (adapted for project conventions)

## Creation Loop

1. **Capture Intent** — What should this skill do? When should it trigger? What's the output format?
2. **Interview & Research** — Ask about edge cases, input/output formats, dependencies
3. **Write the SKILL.md** — See anatomy below
4. **Test** — Create 2-3 realistic test prompts, run with/without skill
5. **Evaluate** — Review outputs qualitatively and quantitatively
6. **Iterate** — Improve based on feedback, repeat until satisfied
7. **Optimize Description** — Generate trigger eval queries for better activation

## Skill Anatomy

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description, allowed-tools)
│   └── Markdown instructions
└── Optional resources
    ├── scripts/     — Executable code
    ├── references/  — Docs loaded on demand
    └── assets/      — Templates, icons
```

### Frontmatter (Project Convention)

```yaml
---
name: my-skill
description: "ALWAYS invoke when [trigger]. Do NOT [negation]."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---
```

**Description rules:**
- Start with `ALWAYS invoke when...`
- Include `Do NOT...` negation
- Keep under 200 chars
- Be slightly "pushy" — Claude tends to undertrigger skills

### Writing Guide

- Keep SKILL.md under 500 lines
- Use imperative form in instructions
- Explain **why** things are important (not heavy-handed MUSTs)
- Include examples for complex patterns
- Reference files from SKILL.md with guidance on when to read
- For large reference files (>300 lines), include a table of contents

## Testing Skills

```json
// evals/evals.json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

For each test case, run Claude with and without the skill, then compare outputs.

## Description Optimization

1. **Generate 20 eval queries** — Mix of should-trigger (8-10) and should-not-trigger (8-10)
2. **Make queries realistic** — Include file paths, personal context, casual speech, typos
3. **Focus negatives on near-misses** — Adjacent domains, ambiguous phrasing
4. **Test triggering** — Run queries against the description
5. **Iterate** — Improve description based on trigger accuracy

## Validation

After creating/modifying a skill:

```bash
bash .claude/scripts/validate-skills.sh
```

Checks: frontmatter, imperative pattern, negation, char budget < 16,000.

## Critical Rules

1. **Interview first** — Understand the user's intent before writing
2. **Imperative description** — `ALWAYS invoke when... Do NOT...`
3. **Under 200 chars** — Description must be concise
4. **Test with real prompts** — Not abstract requests
5. **Generalize from feedback** — Don't overfit to test cases
6. **Explain the why** — Theory of mind over rigid MUSTs
7. **Bundle repeated work** — If every test run writes the same helper, put it in scripts/
