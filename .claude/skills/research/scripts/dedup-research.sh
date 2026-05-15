#!/usr/bin/env bash
# dedup-research.sh — detect topic overlap between /docs/research/*.md docs.
# Computes Jaccard similarity over (a) frontmatter `concepts:` arrays and
# (b) Sources URL sets. Reports pairs above thresholds with a suggested
# action (merge | cross-link | leave).
#
# Usage:
#   dedup-research.sh                # scan all
#   dedup-research.sh <doc.md>       # find dups for one doc
#
# Output: TSV to stdout (a, b, jaccard_concepts, jaccard_sources, action)
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DIR="${ROOT}/docs/research"
TARGET="${1:-}"

[ -d "$DIR" ] || { echo "no docs/research/ yet" >&2; exit 0; }

extract_concepts() {
  awk '
    /^---$/ { fm = !fm; next }
    fm && /^concepts:/ { incon = 1; sub(/^concepts:[[:space:]]*/, ""); }
    incon && /^[a-zA-Z]/ && !/^concepts:/ && !/^- / { incon = 0 }
    incon { print }
  ' "$1" \
  | tr -d '[]' \
  | tr ',' '\n' \
  | sed -E 's/^[[:space:]]*-?[[:space:]]*//; s/[[:space:]]*$//' \
  | grep -v '^$' \
  | sort -u
}

extract_sources() {
  awk '/^## Sources/{flag=1; next} /^## /{flag=0} flag' "$1" \
  | grep -oE 'https?://[^ )]+' \
  | sed -E 's/[\)\.,]+$//' \
  | sort -u
}

jaccard() {
  # Jaccard over two newline-separated sets in tmpfiles $1 $2
  local A B AB
  A=$(wc -l < "$1"); B=$(wc -l < "$2")
  if [ "$A" -eq 0 ] && [ "$B" -eq 0 ]; then echo 0; return; fi
  AB=$(comm -12 "$1" "$2" | wc -l)
  local UN=$(( A + B - AB ))
  [ "$UN" -eq 0 ] && { echo 0; return; }
  awk -v ab="$AB" -v un="$UN" 'BEGIN { printf("%.3f", ab/un) }'
}

if [ -n "$TARGET" ]; then
  FILES=("$TARGET")
  COMP=$(find "$DIR" -maxdepth 1 -type f -name "*.md" ! -name "index.md" ! -path "$TARGET")
else
  FILES=$(find "$DIR" -maxdepth 1 -type f -name "*.md" ! -name "index.md" | sort)
  COMP="$FILES"
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

printf 'a\tb\tjaccard_concepts\tjaccard_sources\taction\n'

# Pairwise scan (O(n^2) — fine for hundreds of docs)
for A in $FILES; do
  extract_concepts "$A" > "$TMP/a.concepts"
  extract_sources  "$A" > "$TMP/a.sources"
  for B in $COMP; do
    [ "$A" = "$B" ] && continue
    [ "$A" \> "$B" ] && continue   # avoid duplicate pairs
    extract_concepts "$B" > "$TMP/b.concepts"
    extract_sources  "$B" > "$TMP/b.sources"
    JC=$(jaccard "$TMP/a.concepts" "$TMP/b.concepts")
    JS=$(jaccard "$TMP/a.sources"  "$TMP/b.sources")
    ACTION="leave"
    awk -v jc="$JC" -v js="$JS" 'BEGIN { exit !(jc >= 0.6 || js >= 0.6) }' && ACTION="merge"
    [ "$ACTION" = "leave" ] && awk -v jc="$JC" -v js="$JS" 'BEGIN { exit !(jc >= 0.3 || js >= 0.3) }' && ACTION="cross-link"
    printf '%s\t%s\t%s\t%s\t%s\n' "$A" "$B" "$JC" "$JS" "$ACTION"
  done
done
