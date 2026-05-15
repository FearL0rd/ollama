#!/usr/bin/env bash
# detect-uncovered.sh — intersect (current branch diff) × (existing tests) and
# emit every NEW or CHANGED surface that has no test coverage.
#
# Inputs (all produced earlier in the pipeline):
#   $1  routes.json         (from discover-routes.sh)
#   $2  api-surface.json    (from discover-api-surface.sh)
#   $3  existing-tests.json (from inventory-existing-tests.sh)
#   $4  base-ref            (default: origin/main)
#
# Output: JSON object on stdout:
# {
#   "base_ref":   "origin/main",
#   "diff_files": ["src/app/users/page.tsx", ...],
#   "changed_routes":    [{route from routes.json}, ...],
#   "changed_http":      [{route from api-surface.http_routes}, ...],
#   "changed_trpc":      [{proc from api-surface.trpc_procedures}, ...],
#   "changed_actions":   [{action from api-surface.server_actions}, ...],
#   "uncovered_routes":  [...],  // changed AND no test references its URL or file
#   "uncovered_http":    [...],
#   "uncovered_trpc":    [...],
#   "uncovered_actions": [...]
# }
set -euo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }

ROUTES_JSON="${1:?usage: detect-uncovered.sh routes.json api-surface.json existing-tests.json [base-ref]}"
API_JSON="${2:?api-surface.json required}"
TESTS_JSON="${3:?existing-tests.json required}"
BASE_REF="${4:-origin/main}"

for f in "$ROUTES_JSON" "$API_JSON" "$TESTS_JSON"; do
  [[ -f "$f" ]] || { echo "missing: $f" >&2; exit 2; }
done

# --- 1. branch diff ---------------------------------------------------------
DIFF_FILES='[]'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # If the base ref doesn't exist locally, fall back to HEAD~10..HEAD
  if git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
    MERGE_BASE="$(git merge-base "$BASE_REF" HEAD 2>/dev/null || echo "$BASE_REF")"
  else
    MERGE_BASE="$(git rev-parse HEAD~10 2>/dev/null || git rev-parse HEAD)"
  fi
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    DIFF_FILES="$(jq --arg f "$f" '. + [$f]' <<<"$DIFF_FILES")"
  done < <(git diff --name-only "$MERGE_BASE"...HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git diff --name-only 2>/dev/null)
  DIFF_FILES="$(jq 'unique' <<<"$DIFF_FILES")"
fi

# --- 2. filter each inventory by membership in diff -------------------------
# Helper: pass stdin JSON array + filter over .file field.
filter_by_file() {
  jq --argjson diff "$DIFF_FILES" '[.[] | select(.file as $f | $diff | any(. == $f))]'
}

CHANGED_ROUTES="$(jq '.' "$ROUTES_JSON" | filter_by_file)"
CHANGED_HTTP="$(jq '.http_routes' "$API_JSON" | filter_by_file)"
CHANGED_TRPC="$(jq '.trpc_procedures' "$API_JSON" | filter_by_file)"
CHANGED_ACTIONS="$(jq '.server_actions' "$API_JSON" | filter_by_file)"

# --- 3. load test corpus contents for string-search coverage ---------------
# Build a single concatenated lowercase blob of all test-file contents;
# a route is "covered" if its URL path OR its source file path appears in any test.
TEST_FILES="$(jq -r '.test_files[]?.file // empty' "$TESTS_JSON")"
TEST_BLOB="/tmp/e2e-audit-testblob-$$.txt"
: >"$TEST_BLOB"
while IFS= read -r tf; do
  [[ -z "$tf" ]] && continue
  [[ -f "$tf" ]] && tr '[:upper:]' '[:lower:]' <"$tf" >>"$TEST_BLOB" || true
done <<<"$TEST_FILES"

is_covered() {
  # args: needle1 needle2 ...
  local n
  for n in "$@"; do
    [[ -z "$n" ]] && continue
    # Strip dynamic segments to make a loose match: /users/[id] → /users/
    loose="$(echo "$n" | sed -E 's#\[[^]]+\]#[^/]+#g' | tr '[:upper:]' '[:lower:]')"
    # Plain literal check first
    if grep -qF "$(echo "$n" | tr '[:upper:]' '[:lower:]')" "$TEST_BLOB" 2>/dev/null; then return 0; fi
    # Regex-ish check with dynamic wildcards
    if grep -Eq "$loose" "$TEST_BLOB" 2>/dev/null; then return 0; fi
  done
  return 1
}

# --- 4. compute uncovered for each category --------------------------------
compute_uncovered() {
  local changed_json="$1"
  local name_field="$2"   # which field(s) to probe as test needles
  local secondary_field="$3"  # optional (e.g., path as well as file)
  local out='[]'
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    primary="$(jq -r --arg k "$name_field" '.[$k] // ""' <<<"$item")"
    secondary="$(jq -r --arg k "$secondary_field" '.[$k] // ""' <<<"$item")"
    if ! is_covered "$primary" "$secondary"; then
      out="$(jq --argjson o "$item" '. + [$o]' <<<"$out")"
    fi
  done < <(jq -c '.[]' <<<"$changed_json")
  echo "$out"
}

UNC_ROUTES="$(compute_uncovered   "$CHANGED_ROUTES"  "path" "file")"
UNC_HTTP="$(compute_uncovered     "$CHANGED_HTTP"    "path" "file")"
UNC_TRPC="$(compute_uncovered     "$CHANGED_TRPC"    "name" "file")"
UNC_ACTIONS="$(compute_uncovered  "$CHANGED_ACTIONS" "name" "file")"

rm -f "$TEST_BLOB"

# --- 5. assemble ------------------------------------------------------------
jq -n \
  --arg base_ref "$BASE_REF" \
  --argjson diff_files "$DIFF_FILES" \
  --argjson changed_routes "$CHANGED_ROUTES" \
  --argjson changed_http "$CHANGED_HTTP" \
  --argjson changed_trpc "$CHANGED_TRPC" \
  --argjson changed_actions "$CHANGED_ACTIONS" \
  --argjson uncovered_routes "$UNC_ROUTES" \
  --argjson uncovered_http "$UNC_HTTP" \
  --argjson uncovered_trpc "$UNC_TRPC" \
  --argjson uncovered_actions "$UNC_ACTIONS" \
  '{
    base_ref: $base_ref,
    diff_files: $diff_files,
    changed_routes: $changed_routes,
    changed_http: $changed_http,
    changed_trpc: $changed_trpc,
    changed_actions: $changed_actions,
    uncovered_routes: $uncovered_routes,
    uncovered_http: $uncovered_http,
    uncovered_trpc: $uncovered_trpc,
    uncovered_actions: $uncovered_actions
  }'
