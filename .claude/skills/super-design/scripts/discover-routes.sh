#!/usr/bin/env bash
# discover-routes.sh — discover route URLs for the detected framework.
#
# Dynamic routes (Next `[slug]` / `[[...foo]]` / `[...bar]`, Remix `$slug`,
# React-Router/Vue `:slug`) are emitted with a `@fixture-<id>` suffix so
# the route map has a stable identity across audits (artifact §2.7 + §7:
# "/posts/[id]@fixture-post-123"). Fixtures are resolved via:
#
#   1. Sibling file: <route-dir>/<name>.fixture.json|ts (array of IDs or
#      objects with {id|slug|key}).
#   2. Nearby directory: <route-dir>/fixtures/*.json.
#   3. Env override: $SUPER_DESIGN_FIXTURES — a JSON object mapping the
#      raw pattern (e.g. "/posts/[slug]") to an array of fixture IDs.
#   4. Placeholder fallback: `@fixture-default` (with stderr warning).
#
# Consumers (hash-pages.sh, sd-audit) MUST strip the `@fixture-<id>`
# suffix before navigating; the suffix is identity-only.
#
# Output: JSON array of URL strings.
set -euo pipefail

log() { printf '[discover-routes] %s\n' "$*" >&2; }

detect_framework() {
  if   [[ -f next.config.js || -f next.config.ts || -f next.config.mjs ]]; then echo "next"
  elif [[ -f remix.config.js || -d app/routes ]]; then echo "remix"
  elif [[ -f svelte.config.js && -d src/routes ]]; then echo "sveltekit"
  elif [[ -f astro.config.mjs || -f astro.config.ts ]]; then echo "astro"
  elif [[ -f nuxt.config.ts || -f nuxt.config.js ]]; then echo "nuxt"
  elif [[ -f app.config.ts && -d src/routes ]]; then echo "solid-start"
  elif [[ -f gatsby-config.js || -f gatsby-config.ts ]]; then echo "gatsby"
  elif [[ -f angular.json ]]; then echo "angular"
  else echo "unknown"; fi
}

# is_dynamic <url> → 0 if URL contains a dynamic segment, else 1.
is_dynamic() {
  local u="$1"
  # Next-style: [foo], [[foo]], [...foo], [[...foo]]
  [[ "$u" == *"["*"]"* ]] && return 0
  # Remix-style: $foo
  [[ "$u" == *"$"* ]] && return 0
  # RR/Vue-style: :foo
  [[ "$u" == *":"* ]] && return 0
  return 1
}

# Look for a fixtures source for a given route URL and emit IDs one per
# line. Echo `__DEFAULT__` if nothing found.
resolve_fixture_ids() {
  local url="$1"
  local segment
  # Strip leading / and use the last dynamic-bearing segment to find a file.
  # Rough heuristic: pick the last path component that is a bare identifier
  # (strip brackets/dollar/colon) to look up fixtures/<name>.*.
  segment="$(printf '%s' "$url" \
    | sed -E 's|^/||' \
    | tr '/' '\n' \
    | grep -E '^(\[\[?\.\.\.?.+\]\]?|\[.+\]|\$.+|:.+)$' \
    | tail -1 \
    | sed -E 's|^\[\[?\.?\.?\.?||; s|\]\]?$||; s|^\$||; s|^:||')"
  [[ -z "$segment" ]] && { echo "__DEFAULT__"; return; }

  # 1. Env override.
  if [[ -n "${SUPER_DESIGN_FIXTURES:-}" ]]; then
    local ids
    ids="$(printf '%s' "$SUPER_DESIGN_FIXTURES" \
      | jq -r --arg k "$url" '.[$k][]? // empty' 2>/dev/null || true)"
    if [[ -n "$ids" ]]; then
      printf '%s\n' "$ids"; return
    fi
  fi

  # 2. Sibling / nearby fixture files. Search in common locations.
  local candidate ids=""
  for candidate in \
      "${segment}.fixture.json" \
      "fixtures/${segment}.json" \
      "tests/fixtures/${segment}.json" \
      "__fixtures__/${segment}.json" \
      ".super-design/fixtures/${segment}.json"; do
    local found
    found="$(find . -type f -name "$(basename "$candidate")" 2>/dev/null \
      | grep -F "/$candidate" | head -1 || true)"
    if [[ -n "$found" && -f "$found" ]]; then
      ids="$(jq -r '
        if type == "array" then
          .[] | if type == "object" then (.id // .slug // .key // empty) else . end
        elif type == "object" and (.fixtures|type=="array") then
          .fixtures[] | if type=="object" then (.id // .slug // .key // empty) else . end
        else empty end
      ' "$found" 2>/dev/null | head -5 || true)"
      if [[ -n "$ids" ]]; then
        printf '%s\n' "$ids"; return
      fi
    fi
  done

  # 3. Give up → default placeholder with warning.
  log "no fixtures for $url; using @fixture-default"
  echo "__DEFAULT__"
}

# suffix_dynamic_routes: read raw URLs on stdin, write suffixed URLs on
# stdout. Static routes pass through untouched.
suffix_dynamic_routes() {
  local url ids id
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    if is_dynamic "$url"; then
      ids="$(resolve_fixture_ids "$url")"
      if [[ "$ids" == "__DEFAULT__" ]]; then
        printf '%s@fixture-default\n' "$url"
      else
        while IFS= read -r id; do
          [[ -z "$id" ]] && continue
          printf '%s@fixture-%s\n' "$url" "$id"
        done <<<"$ids"
      fi
    else
      printf '%s\n' "$url"
    fi
  done
}

FW="$(detect_framework)"
case "$FW" in
  next)
    APP="$(find app src/app -type f \( -name 'page.tsx' -o -name 'page.ts' -o -name 'page.jsx' -o -name 'page.js' -o -name 'page.md' -o -name 'page.mdx' -o -name 'route.ts' -o -name 'route.js' \) 2>/dev/null \
      | sed -E 's|(^|/)(app|src/app)/||; s|/page\.[a-z]+$||; s|/route\.[a-z]+$||; s|^$|/|' \
      | sed -E 's|\([^)]+\)/||g; /(^|\/)_/d' | sort -u || true)"
    PG="$(find pages src/pages -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | grep -vE '(^|/)(pages|src/pages)/(_app|_document|_error|404|500|api/)' \
      | sed -E 's|(^|/)(pages|src/pages)/||; s|\.(tsx|ts|jsx|js|md|mdx)$||; s|index$||' | sort -u || true)"
    printf '%s\n%s\n' "$APP" "$PG" | awk 'NF' | sed -E 's|^|/|; s|//|/|g' | sort -u \
      | suffix_dynamic_routes | jq -Rn '[inputs]';;
  sveltekit)
    find src/routes -type f -name '+page.svelte' 2>/dev/null \
      | sed -E 's|^src/routes||; s|/\+page\.svelte$||; s|\([^)]+\)/||g' \
      | awk 'NF==0 {print "/"; next} {print}' | sort -u \
      | suffix_dynamic_routes | jq -Rn '[inputs]';;
  astro)
    find src/pages -type f \( -name '*.astro' -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | sed -E 's|^src/pages||; s|\.(astro|md|mdx)$||; s|/index$||' | sort -u \
      | suffix_dynamic_routes | jq -Rn '[inputs]';;
  nuxt)
    find pages app/pages -type f -name '*.vue' 2>/dev/null \
      | sed -E 's|^(app/)?pages||; s|\.vue$||; s|/index$||' | sort -u \
      | suffix_dynamic_routes | jq -Rn '[inputs]';;
  remix)
    find app/routes -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | sed -E 's|^app/routes/||; s|\.(tsx|ts|jsx|js|md|mdx)$||; s|\.|/|g; s|_index$||; s|^|/|' \
      | sort -u | suffix_dynamic_routes | jq -Rn '[inputs]';;
  solid-start)
    find src/routes -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' \) 2>/dev/null \
      | sed -E 's|^src/routes||; s|\.(tsx|ts|jsx|js)$||; s|/index$||; s|\([^)]+\)/||g' \
      | sort -u | suffix_dynamic_routes | jq -Rn '[inputs]';;
  *) echo '[]';;
esac
