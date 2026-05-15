---
description: Run super-design audit (or re-audit) on this project
---

Invoke the super-design skill with flags: $ARGUMENTS

Follow SKILL.md entry flow:
1. Preflight state check
2. Scope decision (incremental vs full)
3. Dispatch: sd-research → sd-audit → sd-synthesis
4. Only run sd-fix if user included `--fix`
5. Write state + history
6. Return ≤5-sentence summary

Do not paste the overview into chat.
