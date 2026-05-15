#!/usr/bin/env bash
# Stop hook: runs available quality gates (typecheck, lint, test) before
# letting the session end. If any fail, exits 2 to force Claude to fix them.
# Respects stop_hook_active to avoid infinite loops.
# Skips gracefully if scripts aren't defined in package.json.
set -uo pipefail

INPUT=$(cat)

ACTIVE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("stop_hook_active",False))' 2>/dev/null || echo "False")
[ "$ACTIVE" = "True" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ ! -f package.json ] && exit 0

# Skip if no source files were touched in this branch vs origin
if command -v git >/dev/null 2>&1; then
  CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' | head -1 || true)
  STAGED=$(git diff --name-only --cached 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|mjs|cjs)$' | head -1 || true)
  if [ -z "$CHANGED" ] && [ -z "$STAGED" ]; then
    exit 0
  fi
fi

has_script() {
  python3 -c "import json,sys;d=json.load(open('package.json'));sys.exit(0 if '$1' in d.get('scripts',{}) else 1)" 2>/dev/null
}

RUNNER="bun run"
command -v bun >/dev/null 2>&1 || RUNNER="npm run"

FAIL=""
for script in typecheck lint test; do
  if has_script "$script"; then
    if ! $RUNNER "$script" >/dev/null 2>&1; then
      FAIL="$FAIL $script"
    fi
  fi
done

if [ -n "$FAIL" ]; then
  printf '{"decision":"block","reason":"Quality gate failed:%s. Run the failing script(s), fix the errors, and try again. Do not bypass — these run because TypeScript/lint/test errors block PRs."}\n' "$FAIL"
  exit 0
fi

exit 0
