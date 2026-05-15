#!/usr/bin/env bash
# discover-routes.sh — enumerate every user-facing page route from the source tree.
#
# Output: JSON array on stdout. Each item:
# { "path": "/users/[id]", "kind": "page" | "layout" | "route-group" | "parallel" | "intercepting",
#   "file": "src/app/users/[id]/page.tsx", "dynamic": true, "catch_all": false }
#
# Supports next (app + pages router), remix, sveltekit, nuxt, astro.
# Non-framework repos emit an empty array.
set -euo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }

detect_fw() {
  if   jq -e '.dependencies.next // .devDependencies.next' package.json >/dev/null 2>&1; then echo "next"
  elif jq -e '.dependencies["@remix-run/react"] // .devDependencies["@remix-run/react"]' package.json >/dev/null 2>&1; then echo "remix"
  elif jq -e '.dependencies["@sveltejs/kit"] // .devDependencies["@sveltejs/kit"]' package.json >/dev/null 2>&1; then echo "sveltekit"
  elif jq -e '.dependencies.nuxt // .devDependencies.nuxt' package.json >/dev/null 2>&1; then echo "nuxt"
  elif jq -e '.dependencies.astro // .devDependencies.astro' package.json >/dev/null 2>&1; then echo "astro"
  else echo "unknown"
  fi
}

FW="$(detect_fw)"
OUT='[]'

emit() {
  # args: path kind file dynamic catch_all
  OUT="$(jq --arg p "$1" --arg k "$2" --arg f "$3" \
            --argjson d "$4" --argjson c "$5" \
            '. + [{path:$p, kind:$k, file:$f, dynamic:$d, catch_all:$c}]' <<<"$OUT")"
}

# Translate a Next/Remix/Nuxt/SvelteKit file path into a URL path.
# Strips: src/app, app, src/pages, pages, src/routes, app/routes.
# Drops: route-group segments like (marketing), private _segments (Nuxt/SvelteKit),
# converts [param] into a URL segment that keeps the bracket notation.
path_to_url() {
  local p="$1"
  # strip known leading prefixes
  p="${p#src/app/}"; p="${p#app/}"
  p="${p#src/pages/}"; p="${p#pages/}"
  p="${p#src/routes/}"; p="${p#app/routes/}"
  p="${p#routes/}"
  # drop trailing filename
  p="${p%/page.tsx}"; p="${p%/page.ts}"; p="${p%/page.jsx}"; p="${p%/page.js}"
  p="${p%/+page.svelte}"; p="${p%/+layout.svelte}"
  p="${p%/index.tsx}"; p="${p%/index.ts}"; p="${p%/index.jsx}"; p="${p%/index.js}"
  p="${p%/index.vue}"; p="${p%/index.astro}"
  p="${p%.tsx}"; p="${p%.ts}"; p="${p%.jsx}"; p="${p%.js}"
  p="${p%.vue}"; p="${p%.astro}"; p="${p%.svelte}"
  # remove Next route-group segments (parentheses)
  p="$(echo "$p" | awk -F/ '{
    out=""; for(i=1;i<=NF;i++){
      if($i ~ /^\(.*\)$/) continue;
      out = out (out==""?"":"/") $i;
    }
    print out
  }')"
  # remove private Nuxt/SvelteKit underscore segments
  p="$(echo "$p" | awk -F/ '{
    out=""; for(i=1;i<=NF;i++){
      if($i ~ /^_/) continue;
      out = out (out==""?"":"/") $i;
    }
    print out
  }')"
  # remix: convert dot-delimited route files to slashes, $param -> [param]
  if [[ "$FW" == "remix" ]]; then
    p="$(echo "$p" | sed 's/\./\//g; s/\$/:/g')"
  fi
  # sveltekit/nuxt: [[optional]] / [...rest] already close enough; leave as-is
  echo "/${p}"
}

classify() {
  # args: url file
  local url="$1" file="$2"
  local dyn=false cat=false
  [[ "$url" == *"["*"]"* || "$url" == *":"* ]] && dyn=true
  [[ "$url" == *"[..."*"]"* || "$url" == *"\$\$"* ]] && cat=true
  echo "$dyn $cat"
}

# --- Next.js app router -----------------------------------------------------
if [[ "$FW" == "next" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find app src/app -type f \( -name 'page.tsx' -o -name 'page.ts' -o -name 'page.jsx' -o -name 'page.js' \) 2>/dev/null)

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    emit "$url" "layout" "$f" false false
  done < <(find app src/app -type f \( -name 'layout.tsx' -o -name 'layout.ts' \) 2>/dev/null)

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    emit "${d#*app/}" "parallel" "$d" false false
  done < <(find app src/app -type d -name '@*' 2>/dev/null)

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    emit "${d#*app/}" "intercepting" "$d" false false
  done < <(find app src/app -type d \( -name '(.)*' -o -name '(..)*' -o -name '(...)*' \) 2>/dev/null)

  # Pages router (legacy)
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # exclude _app, _document, _error, api/
    case "$f" in
      */_app.*|*/_document.*|*/_error.*|*/api/*) continue ;;
    esac
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find pages src/pages -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' \) 2>/dev/null)
fi

# --- Remix ------------------------------------------------------------------
if [[ "$FW" == "remix" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find app/routes src/routes -type f \( -name '*.tsx' -o -name '*.ts' \) 2>/dev/null)
fi

# --- SvelteKit --------------------------------------------------------------
if [[ "$FW" == "sveltekit" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find src/routes -type f -name '+page.svelte' 2>/dev/null)
fi

# --- Nuxt -------------------------------------------------------------------
if [[ "$FW" == "nuxt" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find pages src/pages -type f \( -name '*.vue' \) 2>/dev/null)
fi

# --- Astro ------------------------------------------------------------------
if [[ "$FW" == "astro" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    url="$(path_to_url "$f")"
    read -r dyn cat < <(classify "$url" "$f")
    emit "$url" "page" "$f" "$dyn" "$cat"
  done < <(find src/pages -type f \( -name '*.astro' -o -name '*.tsx' -o -name '*.ts' \) 2>/dev/null)
fi

echo "$OUT" | jq '. | unique_by([.path, .file])'
