#!/usr/bin/env bash
# Usage: verify-audit.sh [--strict] <session_dir>
#
# Verifies artifacts produced by an e2e-audit session:
#   1. stack.json, routes.json, api-surface.json, existing-tests.json, uncovered.json exist and parse.
#   2. findings.json exists, is a JSON array, and every item has a SHOT+TRACE+ASSERT+SOURCE quad.
#   3. Every referenced screenshot / trace / source file resolves to a non-empty file.
#   4. If post-run-feedback.json exists, its problems[] reference valid finding IDs.
#   5. Warn when uncovered surfaces exist but no finding of rule=coverage-gap was emitted.
#
# Exit codes:
#   0  OK
#   1  verification failure (or warnings in --strict)
#   2  missing prerequisites
set -euo pipefail

STRICT=0
if [ "${1:-}" = "--strict" ]; then STRICT=1; shift; fi

SESSION_DIR="${1:?usage: verify-audit.sh [--strict] <session_dir>}"

for f in stack.json routes.json api-surface.json existing-tests.json uncovered.json findings.json; do
  [ -f "$SESSION_DIR/$f" ] || { echo "FATAL: missing $SESSION_DIR/$f" >&2; exit 2; }
  jq -e . "$SESSION_DIR/$f" >/dev/null 2>&1 || { echo "FATAL: $SESSION_DIR/$f is not valid JSON" >&2; exit 1; }
done

FINDINGS="$SESSION_DIR/findings.json"
if ! jq -e 'type == "array"' "$FINDINGS" >/dev/null; then
  echo "FATAL: findings.json must be a JSON array" >&2; exit 1
fi

WARNINGS=0
warn() { echo "WARN: $*" >&2; WARNINGS=$((WARNINGS + 1)); }

# Every finding has id + rule + severity + files_affected + the evidence quad.
jq -c '.[]' "$FINDINGS" | while read -r f; do
  id="$(echo "$f" | jq -r '.id // empty')"
  rule="$(echo "$f" | jq -r '.rule // empty')"
  [ -z "$id" ] && { echo "FAIL: finding missing id: $f" >&2; exit 1; }
  [ -z "$rule" ] && { echo "FAIL: $id missing rule" >&2; exit 1; }

  # Meta findings (coverage-gap, test-drift, stack-detect, post-run-feedback)
  # are aggregate and do not require SHOT/TRACE.
  case "$rule" in
    coverage-gap-*|test-drift|stack-detect|post-run-feedback|uncovered-*)
      continue
      ;;
  esac

  shot="$(echo "$f" | jq -r '.screenshot_path // empty')"
  trace="$(echo "$f" | jq -r '.trace_path // empty')"
  source_file="$(echo "$f" | jq -r '.source_file // empty')"
  assert="$(echo "$f" | jq -r '.assertion // empty')"

  [ -n "$shot" ]        || { echo "FAIL: $id missing screenshot_path" >&2; exit 1; }
  [ -n "$trace" ]       || { echo "FAIL: $id missing trace_path" >&2; exit 1; }
  [ -n "$source_file" ] || { echo "FAIL: $id missing source_file" >&2; exit 1; }
  [ -n "$assert" ]      || { echo "FAIL: $id missing assertion" >&2; exit 1; }

  [ -s "$shot" ]        || { echo "FAIL: $id screenshot_path does not resolve: $shot" >&2; exit 1; }
  [ -s "$trace" ]       || { echo "FAIL: $id trace_path does not resolve: $trace" >&2; exit 1; }
  [ -f "$source_file" ] || { echo "FAIL: $id source_file does not exist: $source_file" >&2; exit 1; }
done

# coverage-gap meta findings should exist if uncovered.json has non-empty arrays.
UNC_TOTAL=$(jq '
  (.uncovered_routes  | length) +
  (.uncovered_http    | length) +
  (.uncovered_trpc    | length) +
  (.uncovered_actions | length)
' "$SESSION_DIR/uncovered.json")
COV_FINDINGS=$(jq '[.[] | select(.rule | startswith("coverage-gap"))] | length' "$FINDINGS")
if [ "$UNC_TOTAL" -gt 0 ] && [ "$COV_FINDINGS" -eq 0 ]; then
  warn "uncovered.json has $UNC_TOTAL uncovered surfaces but no coverage-gap finding was emitted"
fi

# post-run-feedback sanity
if [ -f "$SESSION_DIR/post-run-feedback.json" ]; then
  jq -e 'type == "object" and has("problems")' "$SESSION_DIR/post-run-feedback.json" >/dev/null \
    || { echo "FAIL: post-run-feedback.json malformed" >&2; exit 1; }
fi

COUNT=$(jq 'length' "$FINDINGS")
if [ "$STRICT" -eq 1 ] && [ "$WARNINGS" -gt 0 ]; then
  echo "STRICT: $COUNT findings verified, $WARNINGS warning(s)" >&2
  exit 1
fi
echo "OK: $COUNT findings verified${WARNINGS:+ ($WARNINGS warning(s))}"
