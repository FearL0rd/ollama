#!/usr/bin/env bash
# check-cache.sh — slugify a topic + scan /docs/research/ for existing fresh findings.
# Output: JSON to stdout (or just the slug when --slugify is the only arg).
# Compatible with bash on Windows git-bash and Linux.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RESEARCH_DIR="${ROOT}/docs/research"

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | sed -E 's/-(a|an|the|of|in|on|at|to|for|and|or|with|how|do|does|is|are|what|why|vs|via)-/-/g' \
    | cut -c1-60
}

classify_bucket() {
  # heuristic content-type bucket: fast | medium | slow | permanent
  local q="$1"
  local lower; lower=$(echo "$q" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    *"pricing"*|*"version"*|*"latest"*|*"2026"*|*"this week"*|*"breaking change"*|*"sota"*|*"state of the art"*) echo fast ;;
    *"react"*|*"next.js"*|*"nextjs"*|*"vercel"*|*"openai"*|*"anthropic"*|*"llm"*|*"ai sdk"*) echo fast ;;
    *"theorem"*|*"law of"*|*"history of"*|*"definition of"*) echo permanent ;;
    *"prisma"*|*"cochrane"*|*"wcag"*|*"rfc"*|*"iso"*|*"ietf"*|*"w3c"*) echo slow ;;
    *) echo medium ;;
  esac
}

bucket_window_days() {
  case "$1" in
    fast)      echo 30 ;;
    medium)    echo 90 ;;
    slow)      echo 365 ;;
    permanent) echo 1825 ;;
    *)         echo 90 ;;
  esac
}

age_status() {
  local age=$1 bucket=$2
  case "$bucket" in
    fast)      if [ "$age" -lt 30 ]; then echo fresh; elif [ "$age" -lt 90 ]; then echo aging; elif [ "$age" -lt 180 ]; then echo stale; else echo outdated; fi ;;
    medium)    if [ "$age" -lt 90 ]; then echo fresh; elif [ "$age" -lt 180 ]; then echo aging; elif [ "$age" -lt 365 ]; then echo stale; else echo outdated; fi ;;
    slow)      if [ "$age" -lt 365 ]; then echo fresh; elif [ "$age" -lt 730 ]; then echo aging; elif [ "$age" -lt 1825 ]; then echo stale; else echo outdated; fi ;;
    permanent) if [ "$age" -lt 1825 ]; then echo fresh; elif [ "$age" -lt 3650 ]; then echo aging; else echo stale; fi ;;
  esac
}

verdict_from() {
  case "$1" in
    fresh)    echo reuse ;;
    aging)    echo delta-update ;;
    stale)    echo delta-update ;;
    outdated) echo full-research ;;
    *)        echo full-research ;;
  esac
}

# ---- arg parsing ----
TOPIC=""
QUESTION=""
ONLY_SLUGIFY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --slugify)  ONLY_SLUGIFY=1; shift ;;
    --topic)    TOPIC="${2:-}"; shift 2 ;;
    --question) QUESTION="${2:-}"; shift 2 ;;
    *)          # treat positional as the question for slugify mode
                if [ -z "$QUESTION" ]; then QUESTION="$1"; fi; shift ;;
  esac
done

if [ "$ONLY_SLUGIFY" -eq 1 ]; then
  slugify "${QUESTION:-$TOPIC}"
  exit 0
fi

[ -z "$TOPIC" ] && TOPIC=$(slugify "$QUESTION")

DOC="${RESEARCH_DIR}/${TOPIC}.md"
BUCKET=$(classify_bucket "${QUESTION:-$TOPIC}")
WINDOW=$(bucket_window_days "$BUCKET")

if [ -f "$DOC" ]; then
  # Read frontmatter date if present, else file mtime
  DATE=$(awk '/^date:/ { print $2; exit }' "$DOC" 2>/dev/null || true)
  if [ -z "$DATE" ]; then
    if stat -c %Y "$DOC" >/dev/null 2>&1; then
      MTIME=$(stat -c %Y "$DOC")
    else
      MTIME=$(stat -f %m "$DOC")
    fi
    DATE=$(date -u -d "@$MTIME" +%Y-%m-%d 2>/dev/null || date -u -r "$MTIME" +%Y-%m-%d)
  fi
  NOW_EPOCH=$(date -u +%s)
  DOC_EPOCH=$(date -u -d "$DATE" +%s 2>/dev/null || date -u -j -f "%Y-%m-%d" "$DATE" +%s 2>/dev/null || echo "$NOW_EPOCH")
  AGE_DAYS=$(( (NOW_EPOCH - DOC_EPOCH) / 86400 ))
  STATUS=$(age_status "$AGE_DAYS" "$BUCKET")
  VERDICT=$(verdict_from "$STATUS")
  cat <<JSON
{
  "topic_slug": "${TOPIC}",
  "existing_doc": "docs/research/${TOPIC}.md",
  "exists": true,
  "doc_date": "${DATE}",
  "age_days": ${AGE_DAYS},
  "content_type_bucket": "${BUCKET}",
  "freshness_window_days": ${WINDOW},
  "freshness_status": "${STATUS}",
  "verdict": "${VERDICT}"
}
JSON
else
  cat <<JSON
{
  "topic_slug": "${TOPIC}",
  "existing_doc": null,
  "exists": false,
  "doc_date": null,
  "age_days": null,
  "content_type_bucket": "${BUCKET}",
  "freshness_window_days": ${WINDOW},
  "freshness_status": "missing",
  "verdict": "full-research"
}
JSON
fi
