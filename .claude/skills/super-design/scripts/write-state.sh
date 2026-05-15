#!/usr/bin/env bash
# Usage: write-state.sh [<app_path>] [<explicit_target>]
#        (reads JSON body from stdin)
#
# Atomic state writer: accepts JSON on stdin, writes to <target>.tmp,
# validates with jq, then renames in place. Referenced from
# docs/compass_artifact §11 ("Write-then-rename (atomic)") and SKILL.md
# Step 4 ("Atomic write .audit-state.json").
#
# Monorepo support (artifact §11 line 902): first positional arg is the
# app root (e.g. `apps/web`). Target state path is derived as
# `<app_path>/docs/super-design/.audit-state.json`. For single-app
# repos pass "." or omit (default behavior preserved).
# Back-compat: if the first arg already ends in `.audit-state.json`, it
# is treated as an explicit target path (legacy one-arg call sites).
set -euo pipefail

APP_PATH="${1:-.}"
EXPLICIT="${2:-}"

if [ -n "$EXPLICIT" ]; then
  TARGET="$EXPLICIT"
else
  case "$APP_PATH" in
    *.audit-state.json)
      # Legacy single-arg call: treat $APP_PATH as the full target path.
      TARGET="$APP_PATH"
      ;;
    .|"")
      TARGET="docs/super-design/.audit-state.json"
      ;;
    *)
      TARGET="${APP_PATH%/}/docs/super-design/.audit-state.json"
      ;;
  esac
fi

TMP="${TARGET}.tmp"

mkdir -p "$(dirname "$TARGET")"

# Drain stdin into the tmp file.
cat >"$TMP"

# Validate it is parseable JSON before swapping.
if ! jq -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
  rm -f "$TMP"
  echo '{"error":"invalid-json-on-stdin"}' >&2
  exit 2
fi

mv -f "$TMP" "$TARGET"
echo "{\"status\":\"written\",\"path\":\"$TARGET\"}"
