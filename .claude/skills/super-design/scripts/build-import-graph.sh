#!/usr/bin/env bash
# build-import-graph.sh — build a JS/TS import graph for the repo so
# super-design can propagate component-level changes to pages within N
# hops (artifact §8, line 666: default N=3).
#
# Usage:
#   build-import-graph.sh [--state <path>]            # full build
#   build-import-graph.sh importers <file> [--hops N] # BFS query
#
# Output (full build): .super-design/import-graph.json with shape
#   {
#     "nodes":   ["src/app/page.tsx", ...],
#     "edges":   [{"from":"src/app/page.tsx","to":"src/components/Nav.tsx"}, ...],
#     "hash":    "sha256:<hex>",
#     "backend": "madge" | "regex-fallback",
#     "built_at":"<ISO-8601>"
#   }
#
# State: writes `import_graph_sha` back into .audit-state.json via
# scripts/write-state.sh. The sha lives in audit-state.schema.json so
# detect-changes.sh can short-circuit re-propagation if the graph is
# unchanged.
#
# Backend choice:
#   1. If `npx madge --version` works, use `npx madge --json <roots>`
#      (artifact §8: madge reads .madgerc / package.json#madge).
#   2. Else fall back to a zero-dep regex scanner (JS/TS/JSX/TSX only —
#      no CSS/Vue/Svelte detectives, no alias resolution). Logs a
#      warning so the caller knows propagation is best-effort.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_PATH="docs/super-design/.audit-state.json"
OUT_DIR=".super-design"
OUT_FILE="$OUT_DIR/import-graph.json"

log() { printf '[build-import-graph] %s\n' "$*" >&2; }

# Source roots — read from state, else default.
resolve_roots() {
  local roots=""
  if [[ -f "$STATE_PATH" ]]; then
    roots="$(jq -r '.source_roots // empty | .[]?' "$STATE_PATH" 2>/dev/null || true)"
  fi
  if [[ -z "$roots" ]]; then
    for d in src app pages; do [[ -d "$d" ]] && echo "$d"; done
  else
    printf '%s\n' "$roots"
  fi
}

# --- Full build -----------------------------------------------------------

build_madge() {
  # madge prints { "file": [deps], ... }. We flatten to edges.
  local roots_json
  roots_json="$(resolve_roots | jq -Rn '[inputs]')"
  local roots
  roots="$(printf '%s' "$roots_json" | jq -r '.[]' | tr '\n' ' ')"
  [[ -z "$roots" ]] && { log "no source roots found"; echo '{}'; return; }
  # shellcheck disable=SC2086
  npx --yes madge --json $roots 2>/dev/null
}

build_regex_fallback() {
  log "madge unavailable; using regex fallback (JS/TS only, no alias resolution)"
  local roots
  roots="$(resolve_roots | tr '\n' ' ')"
  [[ -z "$roots" ]] && { echo '{}'; return; }

  # Emit NDJSON: {"from":"<path>","to":"<dep>"} for each import line in
  # each JS/TS file, then fold into {file: [deps]} via jq.
  # shellcheck disable=SC2086
  find $roots -type f \( \
      -name '*.ts' -o -name '*.tsx' \
      -o -name '*.js' -o -name '*.jsx' \
      -o -name '*.mjs' -o -name '*.cjs' \) 2>/dev/null \
  | while IFS= read -r f; do
      # Grep import/require specifiers. Handles:
      #   import ... from 'x'
      #   import 'x'
      #   require('x')
      #   import('x')          (dynamic)
      #   export ... from 'x'
      grep -hoE "(from|require|import)[[:space:]]*\(?[[:space:]]*['\"][^'\"]+['\"]" "$f" 2>/dev/null \
        | sed -E "s|.*['\"]([^'\"]+)['\"].*|\1|" \
        | while IFS= read -r spec; do
            [[ -z "$spec" ]] && continue
            # Skip bare package specifiers for graph purposes (we only
            # want local file edges to compute importers).
            case "$spec" in
              .*|/*) : ;;
              *) continue ;;
            esac
            # Normalize: resolve relative to $f's directory, best-effort.
            local dir resolved
            dir="$(dirname "$f")"
            resolved="$dir/$spec"
            # Strip ./ and trailing /
            resolved="$(printf '%s' "$resolved" \
              | sed -E 's|/\./|/|g; s|/$||')"
            jq -cn --arg from "$f" --arg to "$resolved" '{from:$from,to:$to}'
          done
    done \
  | jq -sc 'group_by(.from) | map({key:.[0].from, value:(map(.to)|unique)}) | from_entries'
}

build_graph_json() {
  local raw
  if npx --yes madge --version >/dev/null 2>&1; then
    raw="$(build_madge || echo '{}')"
    BACKEND="madge"
  else
    raw="$(build_regex_fallback || echo '{}')"
    BACKEND="regex-fallback"
  fi
  [[ -z "$raw" ]] && raw='{}'
  printf '%s' "$raw"
}

emit_final() {
  local raw="$1"
  mkdir -p "$OUT_DIR"
  # Build nodes + edges from the {file: [deps]} shape. Keep original
  # paths verbatim (do not attempt alias resolution here).
  local body
  body="$(printf '%s' "$raw" | jq --arg backend "$BACKEND" --arg now "$(date -u +%FT%TZ)" '
    . as $g
    | ([keys[], (.[] | .[])] | unique) as $nodes
    | [to_entries[] | .key as $from | .value[] | {from:$from, to:.}] as $edges
    | {nodes:$nodes, edges:$edges, backend:$backend, built_at:$now}
  ')"
  # Hash over nodes+edges (stable serialization via jq --sort-keys -c).
  local hash
  hash="$(printf '%s' "$body" | jq -S -c '{nodes, edges}' | sha256sum | awk '{print "sha256:"$1}')"
  printf '%s' "$body" | jq --arg h "$hash" '. + {hash:$h}' > "$OUT_FILE"

  # Update state.import_graph_sha if state file exists.
  if [[ -f "$STATE_PATH" ]]; then
    jq --arg h "$hash" '. + {import_graph_sha:$h}' "$STATE_PATH" \
      | bash "$SCRIPT_DIR/write-state.sh" "$STATE_PATH" >/dev/null \
      || log "failed to persist import_graph_sha to state"
  fi

  jq -n --arg path "$OUT_FILE" --arg hash "$hash" --arg backend "$BACKEND" \
        --argjson nodes "$(jq '.nodes|length' "$OUT_FILE")" \
        --argjson edges "$(jq '.edges|length' "$OUT_FILE")" \
    '{status:"ok", path:$path, hash:$hash, backend:$backend, nodes:$nodes, edges:$edges}'
}

# --- Query: importers_of --------------------------------------------------

# importers_of <file> [--hops N]
#   BFS over the edge list using jq. Emits one path per line.
importers_of() {
  local file="$1"; shift || true
  local hops=3
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hops) hops="${2:-3}"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -f "$OUT_FILE" ]] || { log "no import graph; run build first"; return 1; }
  jq -r --arg start "$file" --argjson hops "$hops" '
    . as $g
    # Reverse adjacency: to → [from...]
    | ([.edges[] | {key:.to, value:.from}] | group_by(.key)
        | map({key:.[0].key, value:(map(.value)|unique)}) | from_entries) as $rev
    | def bfs(frontier; seen; depth):
        if depth >= $hops or (frontier|length)==0 then seen
        else
          (frontier | map($rev[.] // []) | add // [] | unique) as $next
          | ($next - (seen|keys | map(.))) as $fresh
          | bfs($fresh; (seen + ($fresh | map({(.):true}) | add // {})); depth + 1)
        end;
      bfs([$start]; {}; 0) | keys[]
  ' "$OUT_FILE"
}

# --- Dispatch -------------------------------------------------------------

main() {
  case "${1:-build}" in
    build|"")
      shift || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --state) STATE_PATH="${2:?}"; shift 2 ;;
          *) shift ;;
        esac
      done
      raw="$(build_graph_json)"
      emit_final "$raw"
      ;;
    importers)
      shift
      [[ -z "${1:-}" ]] && { log "usage: importers <file> [--hops N]"; exit 2; }
      importers_of "$@"
      ;;
    *)
      log "unknown subcommand: $1"
      exit 2
      ;;
  esac
}

main "$@"
