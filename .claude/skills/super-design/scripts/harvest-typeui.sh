#!/usr/bin/env bash
# harvest-typeui.sh — discover + install typeui-* and related design skills.
#
# Sources, in order:
#   1. typeui.sh registry (if reachable) — fetch catalog.json, install missing
#   2. vercel-labs/agent-skills design skills (composition, web-design-guidelines)
#   3. anthropics/skills webapp-testing + mcp-builder (already covered, idempotent)
#
# Usage:
#   harvest-typeui.sh              # install everything missing (user-scope ~/.claude/skills/)
#   harvest-typeui.sh --list       # print catalog without installing
#   harvest-typeui.sh --refresh    # re-download even if already installed
#   harvest-typeui.sh --dest <dir> # install to custom dir (default: ~/.claude/skills)

set -euo pipefail

DEST="${HOME}/.claude/skills"
LIST_ONLY=0
REFRESH=0

while (( $# )); do
  case "$1" in
    --list) LIST_ONLY=1 ;;
    --refresh) REFRESH=1 ;;
    --dest) DEST="$2"; shift ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$DEST"

TYPEUI_CATALOG_URL="${TYPEUI_CATALOG_URL:-https://typeui.sh/catalog.json}"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

log() { echo "[harvest-typeui] $*"; }

fetch_catalog() {
  if command -v curl >/dev/null 2>&1; then
    curl -sSfL --max-time 10 "$TYPEUI_CATALOG_URL" -o "$TMP" 2>/dev/null && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q --timeout=10 -O "$TMP" "$TYPEUI_CATALOG_URL" 2>/dev/null && return 0
  fi
  return 1
}

# Fallback catalog — built-in list of known typeui skills + companions.
# Format: name|base_url (raw SKILL.md location)
DEFAULT_CATALOG=$(cat <<'EOF'
typeui-ant|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-ant/SKILL.md
typeui-application|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-application/SKILL.md
typeui-artistic|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-artistic/SKILL.md
typeui-bento|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-bento/SKILL.md
typeui-bold|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-bold/SKILL.md
typeui-clean|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-clean/SKILL.md
typeui-dashboard|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-dashboard/SKILL.md
typeui-doodle|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-doodle/SKILL.md
typeui-dramatic|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-dramatic/SKILL.md
typeui-enterprise|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-enterprise/SKILL.md
typeui-neobrutalism|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-neobrutalism/SKILL.md
typeui-paper|https://raw.githubusercontent.com/typeui-sh/skills/main/typeui-paper/SKILL.md
composition-patterns|https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/composition-patterns/SKILL.md
web-design-guidelines|https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/web-design-guidelines/SKILL.md
react-best-practices|https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/react-best-practices/SKILL.md
webapp-testing|https://raw.githubusercontent.com/anthropics/skills/main/skills/webapp-testing/SKILL.md
mcp-builder|https://raw.githubusercontent.com/anthropics/skills/main/skills/mcp-builder/SKILL.md
EOF
)

CATALOG=""
if fetch_catalog; then
  # typeui.sh returned JSON — extract {name,url} tuples via node
  if command -v node >/dev/null 2>&1; then
    CATALOG=$(node -e "
      const c = JSON.parse(require('fs').readFileSync('$TMP','utf8'));
      const items = c.skills || c.items || c;
      for (const it of items) {
        const n = it.name || it.slug;
        const u = it.skill_url || it.url || it.raw || it.source;
        if (n && u) console.log(n + '|' + u);
      }
    " 2>/dev/null || echo "")
  fi
fi

if [[ -z "$CATALOG" ]]; then
  log "registry unreachable or empty — using built-in catalog"
  CATALOG="$DEFAULT_CATALOG"
fi

if (( LIST_ONLY )); then
  echo "$CATALOG"
  exit 0
fi

INSTALLED=0
SKIPPED=0
FAILED=0

while IFS='|' read -r name url; do
  [[ -z "$name" ]] && continue
  target_dir="$DEST/$name"
  target_file="$target_dir/SKILL.md"

  if [[ -f "$target_file" && $REFRESH -eq 0 ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  mkdir -p "$target_dir"
  if command -v curl >/dev/null 2>&1; then
    if curl -sSfL --max-time 15 "$url" -o "$target_file" 2>/dev/null; then
      log "installed $name"
      INSTALLED=$((INSTALLED + 1))
    else
      log "failed $name ($url)"
      FAILED=$((FAILED + 1))
      rmdir "$target_dir" 2>/dev/null || true
    fi
  else
    log "curl missing — cannot fetch $name"
    FAILED=$((FAILED + 1))
  fi
done <<< "$CATALOG"

log "done: installed=$INSTALLED skipped=$SKIPPED failed=$FAILED dest=$DEST"
