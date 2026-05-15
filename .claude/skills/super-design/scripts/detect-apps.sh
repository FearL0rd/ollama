#!/usr/bin/env bash
# Usage: detect-apps.sh [<repo_root>]
#
# Detects monorepo layout for super-design per-app audit state (artifact §11
# line 902). Reads workspace declarations from the known manifests:
#   - pnpm-workspace.yaml       (pnpm)
#   - package.json#workspaces   (npm / yarn / bun)
#   - turbo.json                (Turborepo — infers apps from pipeline scope)
#   - nx.json / workspace.json  (Nx)
#   - bunfig.toml               (Bun workspaces)
# For each matched glob we enumerate directories that also contain a
# package.json; those are the apps. When no workspace config is found we
# emit a single "single"-layout entry with path ".".
#
# Output JSON:
#   {
#     "layout": "monorepo" | "single",
#     "apps": [
#       { "name": "web",
#         "path": "apps/web",
#         "state_path": "apps/web/docs/super-design/.audit-state.json" }
#     ]
#   }
#
# POSIX-ish bash. Requires: jq. Works under git-bash on Windows (no GNU
# find -printf, no readarray).
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

log() { printf '[detect-apps] %s\n' "$*" >&2; }

# --- Collect workspace globs from whichever manifests exist ------------------
GLOBS=""

append_glob() {
  # $1 = glob string; skip empty, comments, and negative (!) patterns for now.
  local g
  g="$(printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$g" ] && return 0
  case "$g" in
    '#'*) return 0 ;;
    '!'*) return 0 ;;
  esac
  GLOBS="${GLOBS}
${g}"
}

# pnpm-workspace.yaml — very small YAML subset parser: lines under
# "packages:" that start with "- ".
if [ -f "pnpm-workspace.yaml" ]; then
  in_pkgs=0
  while IFS= read -r line; do
    case "$line" in
      packages:*) in_pkgs=1; continue ;;
    esac
    if [ "$in_pkgs" = "1" ]; then
      case "$line" in
        -\ *|\ *-\ *)
          entry="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*-[[:space:]]*//' -e 's/^["'\'']//' -e 's/["'\'']$//')"
          append_glob "$entry"
          ;;
        [A-Za-z]*:) in_pkgs=0 ;;
      esac
    fi
  done < "pnpm-workspace.yaml"
fi

# package.json#workspaces (array or { packages: [...] })
if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
  WS_JSON="$(jq -r '
    (.workspaces // empty)
    | if type == "array" then .[]
      elif type == "object" then (.packages // [])[]
      else empty end
  ' package.json 2>/dev/null || true)"
  if [ -n "$WS_JSON" ]; then
    while IFS= read -r g; do
      [ -n "$g" ] && append_glob "$g"
    done <<EOF
$WS_JSON
EOF
  fi
fi

# turbo.json — Turborepo does not declare apps itself but relies on the
# package manager's workspaces. Treat its presence as confirmation that
# we are in a monorepo; globs come from package.json/pnpm-workspace.yaml
# which we've already read. If only turbo.json exists (rare), fall back
# to the conventional apps/* + packages/* layout.
if [ -f "turbo.json" ] && [ -z "$GLOBS" ]; then
  append_glob "apps/*"
  append_glob "packages/*"
fi

# nx.json / workspace.json — Nx. Apps live under apps/, libs/ (or the
# workspaceLayout override).
if [ -f "nx.json" ]; then
  apps_dir="apps"
  libs_dir="libs"
  if command -v jq >/dev/null 2>&1; then
    override_apps="$(jq -r '.workspaceLayout.appsDir // empty' nx.json 2>/dev/null || true)"
    override_libs="$(jq -r '.workspaceLayout.libsDir // empty' nx.json 2>/dev/null || true)"
    [ -n "$override_apps" ] && apps_dir="$override_apps"
    [ -n "$override_libs" ] && libs_dir="$override_libs"
  fi
  append_glob "${apps_dir}/*"
  append_glob "${libs_dir}/*"
fi

# bunfig.toml — Bun workspaces. Bun primarily reads workspaces from
# package.json#workspaces (already handled); bunfig.toml presence alone
# is a monorepo hint only if nothing else matched.
if [ -f "bunfig.toml" ] && [ -z "$GLOBS" ]; then
  append_glob "apps/*"
  append_glob "packages/*"
fi

# --- Expand globs to real directories that contain a package.json ------------
APPS_JSON='[]'
seen_paths=""

expand_glob() {
  # $1 = glob like "apps/*" or "packages/marketing-site"
  local g="$1"
  # shellcheck disable=SC2086
  # We deliberately let the shell expand the glob. POSIX shells don't set
  # nullglob, so an unmatched pattern comes back as the literal string —
  # we filter that out below by checking directory existence.
  for d in $g; do
    [ -d "$d" ] || continue
    [ -f "$d/package.json" ] || continue
    # Normalize: strip trailing slash, leading ./
    p="$(printf '%s' "$d" | sed -e 's#^\./##' -e 's#/$##')"
    case "$seen_paths" in
      *"|${p}|"*) continue ;;
    esac
    seen_paths="${seen_paths}|${p}|"
    # Name = package.json "name" field (last path segment for scoped names),
    # fallback to basename.
    name="$(basename "$p")"
    if command -v jq >/dev/null 2>&1; then
      pkg_name="$(jq -r '.name // empty' "$p/package.json" 2>/dev/null || true)"
      if [ -n "$pkg_name" ]; then
        # Strip @scope/ prefix so "web" beats "@acme/web".
        name="$(printf '%s' "$pkg_name" | sed -e 's#^@[^/]*/##')"
      fi
    fi
    APPS_JSON="$(printf '%s' "$APPS_JSON" | jq --arg name "$name" --arg path "$p" \
      --arg state "$p/docs/super-design/.audit-state.json" \
      '. + [{name:$name, path:$path, state_path:$state}]')"
  done
}

if [ -n "$GLOBS" ]; then
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    expand_glob "$g"
  done <<EOF
$GLOBS
EOF
fi

APP_COUNT="$(printf '%s' "$APPS_JSON" | jq 'length')"

if [ "$APP_COUNT" -eq 0 ]; then
  # No monorepo config matched OR matched but produced no apps with
  # package.json. Emit single-app layout.
  jq -n '{
    layout: "single",
    apps: [ {name: ".", path: ".", state_path: "docs/super-design/.audit-state.json"} ]
  }'
  exit 0
fi

jq -n --argjson apps "$APPS_JSON" '{
  layout: "monorepo",
  apps: $apps
}'
