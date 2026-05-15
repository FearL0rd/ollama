#!/usr/bin/env bash
# discover-surfaces.sh — source-first discovery of modals, forms, triggers,
# internal navigation, and Next.js layout/error/loading/parallel surfaces.
#
# Purpose: sd-audit cannot trust runtime-only modal discovery (click every
# trigger in Playwright). A modal hidden behind a flow step, a feature flag,
# or an auth gate will be missed. This script reads the SOURCE CODE first
# and emits an authoritative inventory; Step 2.5 Phase B cross-checks at
# runtime and emits `modal-coverage-gap` findings for anything declared in
# source but never opened during the audit.
#
# Output: JSON object on stdout with shape:
# {
#   "modals":     [{ "component": "CreateUserDialog", "file": "...", "used_in": [...] }],
#   "forms":      [{ "id": "LoginForm", "file": "...", "fields": [...] }],
#   "triggers":   [{ "kind": "DialogTrigger", "file": "..." }],
#   "navigation": [{ "from": "src/...", "to": "/users", "kind": "Link" }],
#   "layouts":    ["src/app/layout.tsx", "src/app/(app)/layout.tsx"],
#   "errors":     ["src/app/error.tsx"],
#   "loading":    ["src/app/loading.tsx"],
#   "not_found":  ["src/app/not-found.tsx"],
#   "parallel":   ["src/app/@modal"],
#   "intercepting": ["src/app/(.)photos"],
#   "framework":  "next" | "remix" | "sveltekit" | "astro" | "nuxt" | "unknown"
# }
#
# Best-effort grep-based scanner. No AST. False positives are OK —
# sd-audit treats this as an inventory, not a contract. Missed items
# are the real failure mode.
set -euo pipefail

log() { printf '[discover-surfaces] %s\n' "$*" >&2; }

detect_framework() {
  if   [[ -f next.config.js || -f next.config.ts || -f next.config.mjs ]]; then echo "next"
  elif [[ -f remix.config.js || -d app/routes ]]; then echo "remix"
  elif [[ -f svelte.config.js && -d src/routes ]]; then echo "sveltekit"
  elif [[ -f astro.config.mjs || -f astro.config.ts ]]; then echo "astro"
  elif [[ -f nuxt.config.ts || -f nuxt.config.js ]]; then echo "nuxt"
  else echo "unknown"; fi
}

# Source roots to scan. Frameworks differ; union keeps the scanner simple.
SCAN_ROOTS=()
for d in src app src/app src/components components src/pages pages src/features features src/routes app/routes; do
  [[ -d "$d" ]] && SCAN_ROOTS+=("$d")
done
if [[ ${#SCAN_ROOTS[@]} -eq 0 ]]; then
  log "no known source roots found; emitting empty inventory"
  jq -n '{modals:[],forms:[],triggers:[],navigation:[],layouts:[],errors:[],loading:[],not_found:[],parallel:[],intercepting:[],framework:"unknown"}'
  exit 0
fi

# File extensions we care about.
EXT_GLOB='\.(tsx|jsx|ts|js|svelte|vue|astro)$'

# --- 1. MODALS --------------------------------------------------------------
# Match common modal/overlay component usages. We key on JSX opening tags so
# we catch both <Dialog> and <Dialog.Root>. The component NAME is what
# the audit logs as the `component` field.
MODAL_PATTERN='<(Dialog|AlertDialog|Sheet|Drawer|Modal|Popover|HoverCard|Tooltip|CommandDialog|DropdownMenu|ContextMenu|Menubar|NavigationMenu|Select|Combobox|DatePicker|ColorPicker)\b'

modals_json="$(
  {
    for root in "${SCAN_ROOTS[@]}"; do
      grep -rEHn --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
        --include='*.svelte' --include='*.vue' --include='*.astro' \
        "$MODAL_PATTERN" "$root" 2>/dev/null || true
    done
  } | awk -F: '{
    file=$1; line=$2;
    # capture component name between < and the next non-word char
    match($0, /<([A-Z][A-Za-z0-9_]*)/, m);
    if (m[1] != "") printf "{\"component\":\"%s\",\"file\":\"%s\",\"line\":%s}\n", m[1], file, line;
  }' | jq -s 'unique_by([.component,.file])'
)"

# --- 2. FORMS ---------------------------------------------------------------
# Match react-hook-form useForm() calls, <Form> / <form> elements, and
# zod schema imports co-located with forms.
FORM_PATTERN='(useForm\s*\(|<Form[[:space:]>]|<form[[:space:]>])'

forms_json="$(
  {
    for root in "${SCAN_ROOTS[@]}"; do
      grep -rEHln --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
        --include='*.svelte' --include='*.vue' --include='*.astro' \
        "$FORM_PATTERN" "$root" 2>/dev/null || true
    done
  } | sort -u | awk '{ printf "{\"file\":\"%s\"}\n", $0 }' | jq -s '.'
)"

# --- 3. TRIGGERS ------------------------------------------------------------
# Explicit *Trigger components (Radix / shadcn convention) tell us the
# connection between a button and its overlay.
TRIGGER_PATTERN='<(DialogTrigger|SheetTrigger|DrawerTrigger|PopoverTrigger|DropdownMenuTrigger|AlertDialogTrigger|HoverCardTrigger|TooltipTrigger|SelectTrigger|ComboboxTrigger|ContextMenuTrigger|MenubarTrigger|NavigationMenuTrigger)\b'

triggers_json="$(
  {
    for root in "${SCAN_ROOTS[@]}"; do
      grep -rEHn --include='*.tsx' --include='*.jsx' \
        "$TRIGGER_PATTERN" "$root" 2>/dev/null || true
    done
  } | awk -F: '{
    file=$1; line=$2;
    match($0, /<([A-Z][A-Za-z0-9_]*Trigger)/, m);
    if (m[1] != "") printf "{\"kind\":\"%s\",\"file\":\"%s\",\"line\":%s}\n", m[1], file, line;
  }' | jq -s '.'
)"

# --- 4. NAVIGATION ----------------------------------------------------------
# Internal nav: <Link href=...>, <Link to=...>, router.push("/..."),
# redirect("/..."), navigate("/..."). We only keep destinations that start
# with "/" (internal) — external URLs are not audit targets here.
nav_json="$(
  {
    for root in "${SCAN_ROOTS[@]}"; do
      grep -rEHno --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
        "(href|to)=[\"']/[^\"']*[\"']|(router\.push|redirect|navigate)\(\s*[\"']/[^\"']*[\"']" \
        "$root" 2>/dev/null || true
    done
  } | awk -F: '{
    file=$1; line=$2; rest=""; for (i=3;i<=NF;i++) rest = rest (i==3?"":":") $i;
    # extract first "/..." path literal from the match
    match(rest, /[\"'"'"']\/[^\"'"'"']*[\"'"'"']/, m);
    if (m[0] != "") {
      dest=m[0]; gsub(/[\"'"'"']/, "", dest);
      kind = (rest ~ /push|redirect|navigate/) ? "imperative" : "link";
      printf "{\"from\":\"%s\",\"to\":\"%s\",\"kind\":\"%s\",\"line\":%s}\n", file, dest, kind, line;
    }
  }' | jq -s 'unique_by([.from,.to])'
)"

# --- 5. NEXT.JS LAYOUT / ERROR / LOADING / NOT-FOUND / PARALLEL -------------
# Empty arrays for non-Next frameworks.
FW="$(detect_framework)"
layouts_json='[]'
errors_json='[]'
loading_json='[]'
notfound_json='[]'
parallel_json='[]'
intercepting_json='[]'

if [[ "$FW" == "next" ]]; then
  # layout.tsx / template.tsx nesting defines wrapper chrome (headers,
  # sidebars) — sd-audit must audit these at EVERY viewport because a
  # layout that misbehaves on mobile breaks every child page.
  layouts_json="$(
    find app src/app -type f \( -name 'layout.tsx' -o -name 'layout.ts' -o -name 'layout.jsx' -o -name 'layout.js' -o -name 'template.tsx' -o -name 'template.ts' \) 2>/dev/null \
      | jq -Rn '[inputs]'
  )"
  errors_json="$(
    find app src/app -type f \( -name 'error.tsx' -o -name 'global-error.tsx' \) 2>/dev/null \
      | jq -Rn '[inputs]'
  )"
  loading_json="$(
    find app src/app -type f -name 'loading.tsx' 2>/dev/null | jq -Rn '[inputs]'
  )"
  notfound_json="$(
    find app src/app -type f -name 'not-found.tsx' 2>/dev/null | jq -Rn '[inputs]'
  )"
  # Parallel route slots: directories starting with @
  parallel_json="$(
    find app src/app -type d -name '@*' 2>/dev/null | jq -Rn '[inputs]'
  )"
  # Intercepting routes: directories starting with (.) / (..) / (...)
  intercepting_json="$(
    find app src/app -type d \( -name '(.)*' -o -name '(..)*' -o -name '(...)*' \) 2>/dev/null | jq -Rn '[inputs]'
  )"
fi

# --- ASSEMBLE ---------------------------------------------------------------
jq -n \
  --argjson modals "$modals_json" \
  --argjson forms "$forms_json" \
  --argjson triggers "$triggers_json" \
  --argjson navigation "$nav_json" \
  --argjson layouts "$layouts_json" \
  --argjson errors "$errors_json" \
  --argjson loading "$loading_json" \
  --argjson not_found "$notfound_json" \
  --argjson parallel "$parallel_json" \
  --argjson intercepting "$intercepting_json" \
  --arg framework "$FW" \
  '{
    framework: $framework,
    modals: $modals,
    forms: $forms,
    triggers: $triggers,
    navigation: $navigation,
    layouts: $layouts,
    errors: $errors,
    loading: $loading,
    not_found: $not_found,
    parallel: $parallel,
    intercepting: $intercepting
  }'
