#!/usr/bin/env bash
# PostToolUse hook: auto-formats files written/edited by Claude using prettier.
# Silently no-ops if prettier is unavailable or the file type isn't supported.
# Always exits 0 so it never blocks the workflow.
set -uo pipefail

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || echo "")

[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.css|*.scss|*.html|*.yml|*.yaml) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

if command -v bunx >/dev/null 2>&1; then
  bunx --bun prettier --write --log-level=silent "$FILE" 2>/dev/null || true
elif command -v npx >/dev/null 2>&1; then
  npx --no-install prettier --write --log-level=silent "$FILE" 2>/dev/null || true
fi

exit 0
