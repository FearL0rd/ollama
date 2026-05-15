#!/usr/bin/env bash
# extract-project-rules.sh — parse project FORBIDDEN rules from
# CLAUDE.md / AGENTS.md / .cursorrules into an authoritative rule
# source for sd-audit Step 3h.
#
# User-owned FORBIDDEN tables ("Use Cards on mobile", "Waterfall data
# fetching", "Make responsive UI only") are HIGHER-PRIORITY than generic
# Nielsen/WCAG heuristics because the project owner has already
# codified them as the right answer for this codebase. sd-audit treats
# violations as primary findings — NOT as a severity bump or a tag on
# another finding. If CLAUDE.md says "no cards on mobile" and we see a
# Card in a mobile flex-col, the rule fires as
# `project-forbidden-use-cards-on-mobile` with the project's own wording.
#
# Output: JSON on stdout
# {
#   "source_files": ["CLAUDE.md", ".claude/CLAUDE.md"],
#   "rules": [
#     {
#       "raw": "Use Cards on mobile",
#       "reason": "Waste space in flex-col",
#       "slug": "use-cards-on-mobile",
#       "audit_applicable": true,
#       "detector_family": "mobile",
#       "template_id": "M2",
#       "detector_hint": "flag <Card> inside flex-col at viewport ≤ 768"
#     }
#   ]
# }
#
# `audit_applicable: false` means the rule is code-level (e.g. "Files >
# 400 lines", "Use `any` type", "'use client' at top level") and does
# NOT produce an audit finding. sd-audit only iterates applicable rules.
set -euo pipefail

log() { printf '[extract-project-rules] %s\n' "$*" >&2; }

# Files to scan in order of authority.
CANDIDATE_FILES=(
  "CLAUDE.md"
  "AGENTS.md"
  "GEMINI.md"
  ".claude/CLAUDE.md"
  ".cursorrules"
)

SOURCE_FILES=()
for f in "${CANDIDATE_FILES[@]}"; do
  [[ -f "$f" ]] && SOURCE_FILES+=("$f")
done

if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
  log "no project rule files found; emitting empty rule set"
  jq -n '{source_files:[],rules:[]}'
  exit 0
fi

# Extract FORBIDDEN table rows. We look for Markdown tables under any
# heading that contains the word "FORBIDDEN" (case-insensitive). Rows
# have shape: `| <action> | <reason> |`. We skip header, separator, and
# empty rows.
#
# Implementation: awk state machine — enter "in table" when we see a
# FORBIDDEN-ish heading followed by a table header; exit when we see a
# blank line followed by a new heading or the next "---" separator
# OUTSIDE the table.
extract_rows() {
  local file="$1"
  awk '
    BEGIN { mode=0; seen_header=0 }
    /^#+[[:space:]]+.*[Ff][Oo][Rr][Bb][Ii][Dd][Dd][Ee][Nn]/ { mode=1; seen_header=0; next }
    # Close on next top-level or section heading when we were inside
    mode == 1 && /^#+[[:space:]]/ && !/[Ff][Oo][Rr][Bb][Ii][Dd][Dd][Ee][Nn]/ { mode=0; seen_header=0; next }
    mode == 1 && /^\|.*\|.*\|/ {
      if (seen_header == 0) { seen_header=1; next }
      # skip separator row
      if ($0 ~ /^\|[[:space:]]*[-]+/) { next }
      # split on | and take cells 1 and 2 (cells 0 and last are empty)
      n = split($0, cells, "|");
      # cells[2] = action, cells[3] = reason (after leading |)
      action = cells[2]; reason = cells[3];
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", action);
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", reason);
      if (action != "" && action !~ /^-+$/ && action !~ /^Action$/i) {
        printf "%s\t%s\n", action, reason;
      }
    }
  ' "$file"
}

# Slugify: lowercase, non-word → dash, collapse, trim.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

# Classify a rule into {audit_applicable, detector_family, template_id,
# detector_hint}. Keyword-based — additive over time.
#
# Audit-applicable families:
#   mobile    → M1-M15 (cards on mobile, responsive-only, card grid on mobile, etc.)
#   design    → V1-V8  (Cards used everywhere, masonry on mobile, etc.)
#   ux        → U1-U10 (no loading states, waterfall fetching hits UX)
#   perf      → P1-P10 (bundle size, waterfall as perf issue)
#   a11y      → A1-A15 (contrast, focus, etc.)
#
# Non-audit (code-level, skip): "Files >", "'use client'", "Use any
# type", "wildcard imports", "skip typecheck", etc.
classify() {
  local raw="$1"
  local low
  low="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"

  # -- code-level (NOT audit-applicable) --
  case "$low" in
    *"files >"*|*"> 400 lines"*|*"> 300 lines"*|*"wildcard icon"*|\
    *"'use client'"*|*"use \`any\`"*|*"use any type"*|\
    *"relative imports"*|*"skip typecheck"*|*"skip lint"*|\
    *"define types in"*|*"@types"*|*"skip docker"*|*"write in non-english"*|\
    *"commit directly to main"*|*"skip code-simplifier"*|\
    *"auto-document"*|*"mix doc types"*|*"leave docs unlinked"*|\
    *"skip claude.md"*|*"use mui"*|*"skip todo"*|*"stack last change"*|\
    *"skip research"*|*"skip superpowers"*|*"skip documenter"*|\
    *"skip planning"*|*"skip domain"*|*"skip cn utility"*|\
    *"skip flow documentation"*|*"waterfall data fetching"*)
      # note: waterfall IS audit-adjacent via perf, but the primary
      # signal is in package code not in rendered UI. Keep as code-level.
      echo "false	code-level	-	-"
      return
      ;;
  esac

  # -- mobile (M family) --
  case "$low" in
    *"card"*"mobile"*|*"mobile"*"card"*|*"cards on mobile"*|\
    *"masonry grid on mobile"*|*"3d elements on mobile"*)
      echo "true	mobile	M2	flag <Card>/card components inside vertical stack at viewport ≤ 768"
      return
      ;;
    *"responsive ui only"*|*"responsive only"*|*"make responsive"*)
      echo "true	mobile	M-distinct	check mobile viewport is a distinct layout not a scaled-down desktop"
      return
      ;;
    *"hamburger-only"*|*"no bottom tabs"*|*"bottom nav"*)
      echo "true	mobile	M1	require bottom tabs on mobile for primary nav"
      return
      ;;
    *"centered modal on mobile"*|*"centered dialog on mobile"*)
      echo "true	mobile	M6	require bottom-sheet on mobile, not centered dialog"
      return
      ;;
  esac

  # -- design (V family) --
  case "$low" in
    *"neumorphism"*)
      echo "true	design	V-neumorphism	flag neumorphic styles on form surfaces (accessibility risk)"
      return
      ;;
    *"scroll animations on dashboard"*)
      echo "true	design	V-scroll	flag scroll-triggered animations on dashboard/app routes"
      return
      ;;
    *"mix animation libraries"*)
      echo "true	design	V-animmix	flag presence of multiple animation libs (framer + gsap + lottie)"
      return
      ;;
  esac

  # -- ux (U family) --
  case "$low" in
    *"skip loading.tsx"*|*"no loading state"*|*"skip skeleton"*)
      echo "true	ux	U3	flag absence of loading state on data-fetching page"
      return
      ;;
    *"skip empty state"*|*"no empty state"*)
      echo "true	ux	U4	flag absence of empty state on zero-data views"
      return
      ;;
  esac

  # -- default: unknown but still emit, detector_family=generic --
  echo "true	generic	-	match rule text against page copy / component names"
}

# Build the rules array.
rules_tsv=""
for f in "${SOURCE_FILES[@]}"; do
  rows="$(extract_rows "$f" || true)"
  [[ -z "$rows" ]] && continue
  while IFS=$'\t' read -r action reason; do
    [[ -z "$action" ]] && continue
    cls="$(classify "$action")"
    slug="$(slugify "$action")"
    # pack: raw \t reason \t slug \t applicable \t family \t template \t hint \t source
    IFS=$'\t' read -r applicable family tpl hint <<<"$cls"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$action" "$reason" "$slug" "$applicable" "$family" "$tpl" "$hint" "$f"
    rules_tsv+="1"
  done <<<"$rows"
done

# Emit JSON. jq slurps TSV lines from stdin.
rules_json="$(
  {
    for f in "${SOURCE_FILES[@]}"; do
      rows="$(extract_rows "$f" || true)"
      [[ -z "$rows" ]] && continue
      while IFS=$'\t' read -r action reason; do
        [[ -z "$action" ]] && continue
        cls="$(classify "$action")"
        slug="$(slugify "$action")"
        IFS=$'\t' read -r applicable family tpl hint <<<"$cls"
        jq -n \
          --arg raw "$action" \
          --arg reason "$reason" \
          --arg slug "$slug" \
          --arg applicable "$applicable" \
          --arg family "$family" \
          --arg tpl "$tpl" \
          --arg hint "$hint" \
          --arg source "$f" \
          '{
            raw: $raw,
            reason: $reason,
            slug: $slug,
            source_file: $source,
            audit_applicable: ($applicable == "true"),
            detector_family: $family,
            template_id: $tpl,
            detector_hint: $hint
          }'
      done <<<"$rows"
    done
  } | jq -s 'unique_by(.slug)'
)"

jq -n \
  --argjson sources "$(printf '%s\n' "${SOURCE_FILES[@]}" | jq -Rn '[inputs]')" \
  --argjson rules "${rules_json:-[]}" \
  '{ source_files: $sources, rules: $rules }'
