#!/usr/bin/env bash
# Injects current git context (branch, dirty files, last commits) into Claude's
# SessionStart context so the assistant opens the session already situated.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "(detached)")
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "(no upstream)")
AHEAD_BEHIND=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null || echo "? ?")
DIRTY=$(git status --porcelain 2>/dev/null | head -20)
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
LAST_COMMITS=$(git log --oneline -5 2>/dev/null)

CONTEXT="GIT CONTEXT (auto-injected at session start)\n\nBranch: ${BRANCH} (upstream: ${UPSTREAM}, behind/ahead: ${AHEAD_BEHIND})\n\nUncommitted changes (${DIRTY_COUNT} files):\n${DIRTY:-(clean)}\n\nLast 5 commits:\n${LAST_COMMITS}\n\nUse this to ground your first response. Don't re-run git status unless the user asks for fresh state — this snapshot is from session start."

# Escape for JSON
CONTEXT_ESCAPED=$(printf '%s' "$CONTEXT" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//' | awk '{print "\"" $0 "\""}')

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$CONTEXT_ESCAPED"
