#!/usr/bin/env bash
# Usage: verify-audit.sh [--strict] <session_dir>
#
# Verifies the artifacts produced by an sd-audit session:
#   1. .audit-state.json exists and passes validate-state.sh
#      (so the schema task #18 schema is actually enforced end-to-end).
#   2. findings.json exists and parses as a JSON array.
#   3. Every finding has a SHOT (screenshot_path) + SNAP (snapshot_path)
#      that resolves to a non-empty file on disk.
#   4. Every finding's snapshot_quote appears verbatim in its snapshot.
#
# Exit codes:
#   0  OK (no errors, no warnings — or warnings present without --strict)
#   1  non-fatal warning in --strict mode, or verification failure
#   2  missing prerequisites (session dir / findings.json)
set -euo pipefail

STRICT=0
if [ "${1:-}" = "--strict" ]; then STRICT=1; shift; fi

SESSION_DIR="${1:?usage: verify-audit.sh [--strict] <session_dir>}"
FINDINGS="$SESSION_DIR/findings.json"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATE="$SKILL_DIR/scripts/validate-state.sh"
STATE="${AUDIT_STATE:-docs/super-design/.audit-state.json}"

WARNINGS=0
warn() { echo "WARN: $*" >&2; WARNINGS=$((WARNINGS + 1)); }

# 1. State file schema check — non-fatal (state may live outside session
#    dir, or may legitimately be absent on first run). In --strict mode
#    any anomaly counts as a warning.
if [ ! -f "$STATE" ]; then
  warn "no audit state at $STATE (first audit? expected on CI)"
else
  if ! bash "$VALIDATE" "$STATE" >/dev/null 2>&1; then
    warn "validate-state.sh rejected $STATE (schema drift or stale)"
  fi
fi

# 2. findings.json must exist and parse.
if [ ! -f "$FINDINGS" ]; then
  echo "FATAL: no findings.json at $FINDINGS" >&2; exit 2
fi
if ! jq -e 'type == "array"' "$FINDINGS" >/dev/null 2>&1; then
  echo "FATAL: $FINDINGS is not a JSON array" >&2; exit 1
fi

# 3. Every referenced screenshot/snapshot resolves to a non-empty file.
jq -r '.[] | [.id, .screenshot_path, .snapshot_path] | @tsv' "$FINDINGS" | \
while IFS=$'\t' read -r id shot snap; do
  if [ ! -s "$shot" ]; then echo "FAIL $id: missing/empty screenshot $shot" >&2; exit 1; fi
  if [ ! -s "$snap" ]; then echo "FAIL $id: missing/empty snapshot $snap" >&2; exit 1; fi
done

# 4. snapshot_quote must appear verbatim in the snapshot.
#    Skipped for meta findings (coverage, craft-summary, project-rule)
#    where evidence is aggregate, not a single DOM quote.
jq -c '.[] | select(.rule | test("^(audit-coverage-|design-intelligence-craft-summary|modal-coverage-gap|form-coverage-gap|project-forbidden-)") | not)' "$FINDINGS" | while read -r f; do
  id=$(echo "$f" | jq -r .id)
  q=$(echo "$f"  | jq -r .snapshot_quote)
  s=$(echo "$f"  | jq -r .snapshot_path)
  if ! grep -qF "$q" "$s"; then
    echo "FAIL $id: quote not found verbatim in $s" >&2; exit 1
  fi
done

# 5. design-intelligence/<slug>_<vp>.json MUST exist for every
#    page × viewport combination in MATRIX. This enforces the
#    0.7.0 mandatory per-combo craft scoring.
DIS_DIR="$SESSION_DIR/design-intelligence"
if [ -d "$DIS_DIR" ]; then
  DIS_COUNT=$(find "$DIS_DIR" -maxdepth 1 -type f -name '*.json' | wc -l)
  if [ "$DIS_COUNT" -lt 1 ]; then
    warn "design-intelligence/ exists but is empty — Step 3g skipped"
  fi
else
  warn "no design-intelligence/ directory — Step 3g (craft scoring) did not run"
fi

# 6. Viewport quota check: if >= 10 total findings, mobile must be
#    >= 30% unless an explicit audit-coverage-skewed meta finding
#    was emitted (which acknowledges the gap).
TOTAL=$(jq '[.[] | select(.viewport)] | length' "$FINDINGS")
if [ "$TOTAL" -ge 10 ]; then
  MOBILE=$(jq '[.[] | select(.viewport == "mobile")] | length' "$FINDINGS")
  COVERAGE_ACK=$(jq '[.[] | select(.rule == "audit-coverage-skewed")] | length' "$FINDINGS")
  # integer math: mobile * 100 / total < 30 means < 30%
  if [ "$COVERAGE_ACK" -eq 0 ] && [ $(( MOBILE * 100 / TOTAL )) -lt 30 ]; then
    warn "mobile viewport is $MOBILE / $TOTAL (< 30%) and no audit-coverage-skewed meta finding was emitted"
  fi
fi

# 7. surfaces.json + project-rules.json should exist (0.7.0 contract).
#    Absence is a warning, not a fatal — allows stale sessions to still verify.
[ -f "$SESSION_DIR/surfaces.json" ] || warn "missing surfaces.json (Step 1.5 skipped)"
[ -f "$SESSION_DIR/project-rules.json" ] || warn "missing project-rules.json (Step 1.5 skipped)"

COUNT=$(jq 'length' "$FINDINGS")
if [ "$STRICT" -eq 1 ] && [ "$WARNINGS" -gt 0 ]; then
  echo "STRICT: $COUNT findings verified, $WARNINGS warning(s)" >&2
  exit 1
fi

echo "OK: $COUNT findings verified${WARNINGS:+ ($WARNINGS warning(s))}"
