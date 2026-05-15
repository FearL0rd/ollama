#!/usr/bin/env bash
# verify-citations.sh — anti-hallucination gate.
# Reads a rendered research doc + the session sources.jsonl/claims.jsonl,
# verifies every citation: HTTP 200, quote greppable in cached snapshot,
# DOI resolvable in Crossref. Emits JSON array to stdout. Exits non-zero
# on any FAIL verdict.
#
# Usage:
#   verify-citations.sh <doc.md> <session_dir>
#
# Dependencies: bash, jq, curl, grep. All present on dev/CI defaults.
set -euo pipefail

DOC="${1:?usage: verify-citations.sh <doc.md> <session_dir>}"
SESSION_DIR="${2:?usage: verify-citations.sh <doc.md> <session_dir>}"

[ -f "$DOC" ] || { echo "doc not found: $DOC" >&2; exit 2; }
[ -d "$SESSION_DIR" ] || { echo "session dir not found: $SESSION_DIR" >&2; exit 2; }

SOURCES="${SESSION_DIR}/sources.jsonl"
CLAIMS="${SESSION_DIR}/claims.jsonl"
[ -f "$SOURCES" ] || { echo "missing sources.jsonl" >&2; exit 2; }
[ -f "$CLAIMS" ]  || { echo "missing claims.jsonl"  >&2; exit 2; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2; exit 2
fi

FAIL_COUNT=0
RESULTS=()

# Iterate every claim
while IFS= read -r CLAIM_JSON; do
  [ -z "$CLAIM_JSON" ] && continue
  CID=$(echo "$CLAIM_JSON" | jq -r '.id')
  SID=$(echo "$CLAIM_JSON" | jq -r '.source_id')
  QUOTE=$(echo "$CLAIM_JSON" | jq -r '.quote')

  SRC=$(grep -F "\"id\":\"$SID\"" "$SOURCES" || true)
  if [ -z "$SRC" ]; then
    RESULTS+=("$(jq -nc --arg cid "$CID" --arg sid "$SID" \
      '{citation_id:$cid, source_id:$sid, url_status:"missing-source", quote_match:false, doi_status:null, verdict:"fail"}')")
    FAIL_COUNT=$((FAIL_COUNT+1)); continue
  fi

  URL=$(echo "$SRC" | jq -r '.url // empty')
  DOI=$(echo "$SRC" | jq -r '.doi // empty')
  SNAP=$(echo "$SRC" | jq -r '.snapshot_path // empty')

  # 1. URL reachability (HEAD, then GET if HEAD denied)
  URL_STATUS="unknown"
  if [ -n "$URL" ]; then
    CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" --max-time 12 -I "$URL" 2>/dev/null || echo "000")
    if [ "$CODE" = "405" ] || [ "$CODE" = "403" ] || [ "$CODE" = "000" ]; then
      CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" --max-time 12 "$URL" 2>/dev/null || echo "000")
    fi
    URL_STATUS="$CODE"
  fi

  # 2. DOI Crossref check
  DOI_STATUS="n/a"
  if [ -n "$DOI" ]; then
    DOI_CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" --max-time 12 \
      "https://api.crossref.org/works/${DOI}" 2>/dev/null || echo "000")
    DOI_STATUS="$DOI_CODE"
  fi

  # 3. Quote-grep against snapshot
  QUOTE_MATCH="false"
  if [ -n "$SNAP" ] && [ -f "${CLAUDE_PROJECT_DIR:-.}/$SNAP" ]; then
    if grep -qF -- "$QUOTE" "${CLAUDE_PROJECT_DIR:-.}/$SNAP"; then
      QUOTE_MATCH="true"
    else
      # try whitespace-collapsed match
      NEEDLE=$(echo "$QUOTE" | tr -s '[:space:]' ' ')
      HAYSTACK=$(tr -s '[:space:]' ' ' < "${CLAUDE_PROJECT_DIR:-.}/$SNAP")
      if echo "$HAYSTACK" | grep -qF -- "$NEEDLE"; then QUOTE_MATCH="true"; fi
    fi
  fi

  # 4. Verdict
  VERDICT="pass"
  if [ "$QUOTE_MATCH" = "false" ]; then VERDICT="fail"; fi
  if [ -n "$DOI" ] && [ "$DOI_STATUS" != "200" ]; then VERDICT="fail"; fi
  if [ -z "$DOI" ] && [ "$URL_STATUS" != "200" ] && [ "$URL_STATUS" != "301" ] && [ "$URL_STATUS" != "302" ]; then
    if [ "$VERDICT" = "pass" ] && [ "$QUOTE_MATCH" = "true" ]; then VERDICT="stale"; else VERDICT="fail"; fi
  fi

  [ "$VERDICT" = "fail" ] && FAIL_COUNT=$((FAIL_COUNT+1))

  RESULTS+=("$(jq -nc \
    --arg cid "$CID" --arg sid "$SID" \
    --arg url "$URL_STATUS" --argjson qm "$QUOTE_MATCH" \
    --arg doi "$DOI_STATUS" --arg verdict "$VERDICT" \
    '{citation_id:$cid, source_id:$sid, url_status:$url, quote_match:$qm, doi_status:$doi, verdict:$verdict}')")
done < "$CLAIMS"

# Emit array
printf '['
FIRST=1
for R in "${RESULTS[@]}"; do
  if [ $FIRST -eq 1 ]; then FIRST=0; else printf ','; fi
  printf '%s' "$R"
done
printf ']\n'

[ "$FAIL_COUNT" -eq 0 ]
