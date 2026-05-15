#!/usr/bin/env bash
# Usage: validate-state.sh [<app_path_or_state_path>]
#
# Validates the super-design audit state file. On schema/parse errors,
# moves the broken file aside (artifact §3 "Graceful corruption handling"
# line 74) and emits a JSON verdict. Also enforces schema_version major
# compatibility (artifact §12 line 934).
#
# Monorepo support (artifact §11 line 902): the positional arg is the
# app root (e.g. `apps/web`); state is looked up at
# `<app_path>/docs/super-design/.audit-state.json`. For single-app
# repos pass "." or omit (default behavior preserved). Back-compat: if
# the arg ends in `.audit-state.json` it is used verbatim.
#
# Validation strategy:
#   1. If `ajv` is on PATH, validate against audit-state.schema.json
#      (draft-07 canonical schema, task #18).
#   2. Otherwise fall back to the inline jq shape check that existed
#      pre-schema. Same corrupt-rename behavior in both paths.
set -euo pipefail
ARG="${1:-.}"
case "$ARG" in
  *.audit-state.json) STATE="$ARG" ;;
  .|"")              STATE="docs/super-design/.audit-state.json" ;;
  *)                 STATE="${ARG%/}/docs/super-design/.audit-state.json" ;;
esac
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$SKILL_DIR/audit-state.schema.json"

# Current schema major is either read from a sibling .schema-version file
# (so the number can be bumped without editing shell) or falls back to 1.
SCHEMA_VERSION_FILE="$SKILL_DIR/.schema-version"
if [ -f "$SCHEMA_VERSION_FILE" ]; then
  CURRENT_SCHEMA_MAJOR="$(cut -d. -f1 <"$SCHEMA_VERSION_FILE" | tr -d '[:space:]')"
else
  CURRENT_SCHEMA_MAJOR=1
fi

if [ ! -f "$STATE" ]; then echo '{"status":"missing"}'; exit 2; fi

# Parse + shape check. On failure, rename so the user can inspect and we
# fall through to first-audit (SKILL.md Step 1 treats "corrupt" that way).
schema_ok=1
if command -v ajv >/dev/null 2>&1 && [ -f "$SCHEMA" ]; then
  if ! ajv validate -s "$SCHEMA" -d "$STATE" --errors=text >/dev/null 2>&1; then
    schema_ok=0
  fi
else
  # Fallback: inline jq shape check (pre-schema behavior).
  if ! jq -e '
    (.schema_version | type == "string") and
    (.last_audit_at  | fromdateiso8601 | . > 0) and
    (.git_sha_at_audit | test("^[0-9a-f]{7,64}$")) and
    (.skill_version  | type == "string") and
    (.tools | type == "object")
  ' "$STATE" >/dev/null 2>&1; then
    schema_ok=0
  fi
fi

if [ "$schema_ok" -eq 0 ]; then
  mv "$STATE" "$STATE.corrupt-$(date +%s)" 2>/dev/null || true
  echo '{"status":"corrupt"}'; exit 2
fi

# schema_version major-bump check — if state was written by a newer OR
# incompatible-older skill, force a full re-audit rather than silently
# trusting the shape.
STATE_MAJOR="$(jq -r '.schema_version' "$STATE" | cut -d. -f1)"
if [ -z "$STATE_MAJOR" ] || [ "$STATE_MAJOR" != "$CURRENT_SCHEMA_MAJOR" ]; then
  echo "{\"status\":\"schema-incompatible\",\"action\":\"force-full\",\"state_major\":\"${STATE_MAJOR:-unknown}\",\"current_major\":\"${CURRENT_SCHEMA_MAJOR}\"}"
  exit 1
fi

AGE_DAYS=$(( ( $(date -u +%s) - $(jq -r '.last_audit_at | fromdateiso8601' "$STATE") ) / 86400 ))
if [ "$AGE_DAYS" -gt 180 ]; then echo "{\"status\":\"stale-force-full\",\"age_days\":$AGE_DAYS}"; exit 1
elif [ "$AGE_DAYS" -gt 90 ]; then echo "{\"status\":\"stale-refresh-research\",\"age_days\":$AGE_DAYS}"; exit 1
else echo "{\"status\":\"fresh\",\"age_days\":$AGE_DAYS}"; exit 0; fi
