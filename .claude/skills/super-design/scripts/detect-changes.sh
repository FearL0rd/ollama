#!/usr/bin/env bash
# Usage:
#   detect-changes.sh <last_sha> [<last_iso>]                 (single app)
#   detect-changes.sh --app <path> <last_sha> [<last_iso>]    (one app, path-scoped)
#   detect-changes.sh --all-apps                              (monorepo loop)
#
# Emits JSON. Single-app form:
#   { mode, range_start, commits, files, classified }
#
# Monorepo form (--all-apps) — one wrapper with per-app results; each
# app reads its own `.audit-state.json` via detect-apps.sh:
#   { "layout": "monorepo"|"single",
#     "apps": [ { "name", "path", "state_path",
#                 "last_sha", "changes": {<single-app form>} } ] }
#
# Implements the fallback ladder from artifact §6 + §14:
#   1. Anchor exists → diff with rename detection (-M90%).
#   2. Anchor missing + shallow repo → `git fetch --unshallow --no-tags`.
#   3. Still missing → fetch super-design git notes, retry.
#   4. Still missing → `--since=<iso>` time-based fallback.
#   5. Empty repo / no last_sha at all → diff against empty-tree SHA
#      4b825dc642cb6eb9a060e54bf8d69288fbee4904 (artifact line 900).
# Also uses --first-parent + --cherry-pick --right-only when walking
# history (artifact §2.5 line 167-172).
#
# Monorepo per-app state (artifact §11 line 902): when --app is given,
# `git diff --name-status` is narrowed via `-- <app_path>/` pathspec so
# only files under that app show up. `--all-apps` discovers apps via
# detect-apps.sh and runs the per-app path for each.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"

log() { printf '[detect-changes] %s\n' "$*" >&2; }

# --- Arg parsing -------------------------------------------------------------
MODE_SELECT="single"   # single | app | all
APP_PATH="."
if [ "${1:-}" = "--all-apps" ]; then
  MODE_SELECT="all"; shift
elif [ "${1:-}" = "--app" ]; then
  MODE_SELECT="app"; APP_PATH="${2:-.}"; shift 2
fi
LAST_SHA="${1:-}"
LAST_ISO="${2:-}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then echo '{"error":"not-a-git-repo"}'; exit 3; fi

# --- --all-apps: discover via detect-apps.sh, recurse per app ----------------
if [ "$MODE_SELECT" = "all" ]; then
  APPS_DOC="$(bash "$SCRIPT_DIR/detect-apps.sh" .)"
  LAYOUT="$(printf '%s' "$APPS_DOC" | jq -r '.layout')"
  RESULT='[]'
  APP_COUNT="$(printf '%s' "$APPS_DOC" | jq '.apps | length')"
  i=0
  while [ "$i" -lt "$APP_COUNT" ]; do
    APP_NAME="$(printf '%s' "$APPS_DOC" | jq -r ".apps[$i].name")"
    A_PATH="$(printf '%s' "$APPS_DOC" | jq -r ".apps[$i].path")"
    A_STATE="$(printf '%s' "$APPS_DOC" | jq -r ".apps[$i].state_path")"
    A_LAST_SHA=""; A_LAST_ISO=""
    if [ -f "$A_STATE" ]; then
      A_LAST_SHA="$(jq -r '.git_sha_at_audit // ""' "$A_STATE" 2>/dev/null || true)"
      A_LAST_ISO="$(jq -r '.last_audit_at  // ""' "$A_STATE" 2>/dev/null || true)"
    fi
    A_CHANGES="$(bash "$0" --app "$A_PATH" "$A_LAST_SHA" "$A_LAST_ISO")"
    RESULT="$(printf '%s' "$RESULT" | jq \
      --arg name "$APP_NAME" --arg path "$A_PATH" --arg state "$A_STATE" \
      --arg lsha "$A_LAST_SHA" --argjson ch "$A_CHANGES" '
      . + [{name:$name, path:$path, state_path:$state, last_sha:$lsha, changes:$ch}]
    ')"
    i=$((i + 1))
  done
  jq -n --arg layout "$LAYOUT" --argjson apps "$RESULT" '{layout:$layout, apps:$apps}'
  exit 0
fi

# Determine HEAD availability — empty repos have no commits at all.
if ! git rev-parse --verify --quiet HEAD >/dev/null; then
  log "no HEAD commit; using empty-tree SHA fallback"
  LAST_SHA="$EMPTY_TREE"
fi

# If caller didn't pass a last_sha, treat it as empty-tree (first audit).
if [[ -z "$LAST_SHA" ]]; then
  log "missing last_sha; defaulting to empty-tree SHA"
  LAST_SHA="$EMPTY_TREE"
fi

resolve_anchor() {
  # Sets RANGE_START (may be empty if anchor unrecoverable).
  if [[ "$LAST_SHA" == "$EMPTY_TREE" ]]; then
    RANGE_START="$EMPTY_TREE"; return 0
  fi
  if git rev-parse --verify --quiet "${LAST_SHA}^{commit}" >/dev/null; then
    if git merge-base --is-ancestor "$LAST_SHA" HEAD 2>/dev/null; then
      RANGE_START="$LAST_SHA"
    else
      RANGE_START="$(git merge-base HEAD "$LAST_SHA" 2>/dev/null || echo "")"
    fi
    return 0
  fi
  RANGE_START=""
  return 1
}

if ! resolve_anchor; then
  # Ladder step (a): unshallow if possible.
  if [[ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo false)" == "true" ]]; then
    log "anchor missing and repo is shallow; attempting git fetch --unshallow --no-tags"
    git fetch --unshallow --no-tags 2>/dev/null || log "unshallow fetch failed (continuing)"
    resolve_anchor || true
  fi
fi
if [[ -z "${RANGE_START:-}" ]]; then
  # Ladder step (b): try to fetch super-design notes; they may pin a commit
  # we don't have locally.
  log "anchor still missing; fetching refs/notes/super-design"
  git fetch origin '+refs/notes/super-design:refs/notes/super-design' 2>/dev/null \
    || log "notes fetch failed (continuing)"
  resolve_anchor || true
fi

# Build the pathspec used to narrow diff/log to a single app (monorepo
# per-app state, artifact §11 line 902). For the default "." the scope
# is the repo root, preserving pre-existing single-app behavior.
case "$APP_PATH" in
  .|"") SCOPE_PATH="." ;;
  *)    SCOPE_PATH="${APP_PATH%/}" ;;
esac

# Ladder step (c): time-based fallback.
if [[ -z "${RANGE_START:-}" && -n "$LAST_ISO" ]]; then
  log "using --since=$LAST_ISO time-based fallback (scope=$SCOPE_PATH)"
  FILES="$(git log --since="$LAST_ISO" --name-only --pretty=format: -- "$SCOPE_PATH" 2>/dev/null | sort -u | sed '/^$/d' || true)"
  COMMITS="$(git log --first-parent --since="$LAST_ISO" --pretty=format:'%H|%s|%an|%aI' -- "$SCOPE_PATH" 2>/dev/null || true)"
  MODE="since-time"
  RANGE_START=""
elif [[ -z "${RANGE_START:-}" ]]; then
  echo '{"error":"lost-anchor-no-fallback-time"}'; exit 4
else
  # SHA range available. Use --name-status -M90% -z to catch renames AND
  # filenames with spaces (NUL-terminated output).
  RANGE="${RANGE_START}..HEAD"
  if [[ "$RANGE_START" == "$EMPTY_TREE" ]]; then
    # Empty-tree baseline: everything in HEAD is "new".
    RANGE="${EMPTY_TREE} HEAD"
  fi

  # Parse NUL-terminated name-status output.
  # Format: <STATUS>\0<path>[\0<new_path>]  where STATUS can be A/M/D/Rnn/Cnn.
  # We collapse to the post-rename path so downstream classification matches
  # the current file layout.
  FILES="$(
    git diff --name-status -M90% -z \
      -- "$SCOPE_PATH" ':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml' ':!yarn.lock' \
         ':!.github/**' ':!**/*.test.*' ':!**/*.spec.*' ':!**/*.stories.*' \
      $RANGE 2>/dev/null |
    awk -v RS='\0' '
      BEGIN { status = "" }
      {
        if (status == "") { status = $0; next }
        # Rename/copy has two path fields; we want the second (post-rename).
        if (status ~ /^R/ || status ~ /^C/) {
          if (wanted == "") { wanted = 1; next }
          print; status = ""; wanted = ""
        } else {
          print; status = ""
        }
      }
    ' | sort -u
  )"

  # --first-parent keeps one entry per merged PR (trunk-based). Combine
  # with --cherry-pick --right-only to dedupe back-ports / rebased copies.
  if [[ "$RANGE_START" == "$EMPTY_TREE" ]]; then
    COMMITS="$(git log --first-parent --pretty=format:'%H|%s|%an|%aI' HEAD 2>/dev/null || true)"
  else
    COMMITS="$(git log --first-parent --cherry-pick --right-only --no-merges \
      --pretty=format:'%H|%s|%an|%aI' "${RANGE_START}...HEAD" 2>/dev/null || true)"
  fi
  MODE="sha-range"
fi

declare -A CLASSIFIED
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  case "$p" in
    tailwind.config.*|*.tokens.json|*.tokens|styles/tokens.css|styles/theme.css) CLASSIFIED[tokens]+="$p,";;
    components/*|src/components/*|app/_components/*) CLASSIFIED[components]+="$p,";;
    app/*/page.*|app/page.*|app/*/route.*|app/route.*|pages/*|src/pages/*|app/routes/*|src/routes/*) CLASSIFIED[routes]+="$p,";;
    public/*|src/assets/*|assets/*) CLASSIFIED[imagery]+="$p,";;
    package.json) CLASSIFIED[deps]+="$p,";;
    references/design-theory.md|references/market-analysis.md) CLASSIFIED[theory]+="$p,";;
    *.md|*.mdx) CLASSIFIED[content]+="$p,";;
    *) CLASSIFIED[other]+="$p,";;
  esac
done <<< "$FILES"

jq -Rn --arg mode "$MODE" --arg range_start "${RANGE_START:-}" --arg last_iso "$LAST_ISO" \
  --arg app_path "$APP_PATH" \
  --arg tokens "${CLASSIFIED[tokens]:-}" --arg components "${CLASSIFIED[components]:-}" \
  --arg routes "${CLASSIFIED[routes]:-}" --arg imagery "${CLASSIFIED[imagery]:-}" \
  --arg deps "${CLASSIFIED[deps]:-}" --arg theory "${CLASSIFIED[theory]:-}" \
  --arg content "${CLASSIFIED[content]:-}" \
  --argjson files "$(printf '%s\n' "$FILES" | jq -R . | jq -s .)" \
  --argjson commits "$(printf '%s\n' "$COMMITS" | jq -R . | jq -s .)" '
  def tolist(s): s | split(",") | map(select(length>0));
  {app_path:$app_path,
   mode:$mode, range_start:$range_start, since_iso:$last_iso,
   commits:$commits, files:$files,
   classified: {
     tokens: tolist($tokens), components: tolist($components),
     routes: tolist($routes), imagery: tolist($imagery),
     deps: tolist($deps), theory: tolist($theory), content: tolist($content)
   }
  }'
