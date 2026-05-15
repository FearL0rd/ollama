#!/usr/bin/env bash
# inventory-existing-tests.sh — catalog every E2E test the project already has,
# so the audit can reuse setup and detect DRIFT between audit runs.
#
# Why: (1) If the project has tests/e2e/, we must not reinvent the fixtures,
# auth storage state, or page objects. (2) Between audit runs the test layout
# may change (test deleted, fixture renamed, new storageState file), and the
# skill should warn the user when that happens instead of silently producing
# stale findings.
#
# Output: JSON object on stdout:
# {
#   "runner":          "playwright" | "cypress" | "vitest-browser" | "none",
#   "config_file":     "playwright.config.ts" | "cypress.config.ts" | null,
#   "test_dirs":       ["tests/e2e", "e2e"],
#   "test_files":      [{ "file": "tests/e2e/login.spec.ts", "test_count": 5, "describe_count": 1 }],
#   "fixtures":        [{ "file": "...", "fixtures_defined": ["authenticatedPage", "apiErrors"] }],
#   "page_objects":    [{ "file": "...", "class": "LoginPage" }],
#   "storage_states":  ["tests/e2e/.auth/owner.json", ...],
#   "has_global_setup": true | false,
#   "hash":            "<sha256 of file-list + sizes>"   // for drift detection
# }
set -euo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }

RUNNER="none"
CFG="null"
TDIRS='[]'
TFILES='[]'
FIXTURES='[]'
PAGES='[]'
STATES='[]'
HAS_GLOBAL_SETUP=false

# --- detect runner + config -------------------------------------------------
for c in playwright.config.ts playwright.config.js playwright.config.mjs; do
  if [[ -f "$c" ]]; then RUNNER="playwright"; CFG="\"$c\""; break; fi
done
if [[ "$RUNNER" == "none" ]]; then
  for c in cypress.config.ts cypress.config.js; do
    [[ -f "$c" ]] && RUNNER="cypress" && CFG="\"$c\"" && break
  done
fi
if [[ "$RUNNER" == "none" ]] && jq -e '.dependencies["@vitest/browser"] // .devDependencies["@vitest/browser"]' package.json >/dev/null 2>&1; then
  RUNNER="vitest-browser"
fi

# --- detect test dirs -------------------------------------------------------
CANDIDATE_DIRS=(tests/e2e tests/playwright tests/integration e2e playwright-tests cypress/e2e cypress/integration)
for d in "${CANDIDATE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    TDIRS="$(jq --arg d "$d" '. + [$d]' <<<"$TDIRS")"
  fi
done

# --- list test files + count tests -----------------------------------------
SPEC_GLOBS=()
if [[ "$RUNNER" == "playwright" ]]; then
  SPEC_GLOBS=('*.spec.ts' '*.spec.tsx' '*.spec.js' '*.test.ts' '*.test.tsx')
elif [[ "$RUNNER" == "cypress" ]]; then
  SPEC_GLOBS=('*.cy.ts' '*.cy.js' '*.spec.ts' '*.spec.js')
elif [[ "$RUNNER" == "vitest-browser" ]]; then
  SPEC_GLOBS=('*.test.ts' '*.test.tsx')
fi

if [[ ${#SPEC_GLOBS[@]} -gt 0 ]]; then
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    for g in "${SPEC_GLOBS[@]}"; do
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        tc=$(grep -cE "^[[:space:]]*(test|it)\\(" "$f" 2>/dev/null || echo 0)
        dc=$(grep -cE "^[[:space:]]*describe\\(" "$f" 2>/dev/null || echo 0)
        TFILES="$(jq --arg f "$f" --argjson t "$tc" --argjson dc "$dc" \
                    '. + [{file:$f, test_count:$t, describe_count:$dc}]' <<<"$TFILES")"
      done < <(find "$d" -type f -name "$g" 2>/dev/null)
    done
  done < <(jq -r '.[]' <<<"$TDIRS")
fi

# --- detect fixtures --------------------------------------------------------
# Playwright: files that use `test.extend<>`, or export a test with extend.
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    defined='[]'
    # Extract fixture names from `extend<{ name1: ..., name2: ... }>` blocks.
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      defined="$(jq --arg n "$name" '. + [$n]' <<<"$defined")"
    done < <(grep -oE "([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:" "$f" 2>/dev/null \
             | awk '{sub(":",""); print $1}' | sort -u | head -30)
    if [[ "$(jq 'length' <<<"$defined")" -gt 0 ]]; then
      FIXTURES="$(jq --arg fi "$f" --argjson df "$defined" '. + [{file:$fi, fixtures_defined:$df}]' <<<"$FIXTURES")"
    fi
  done < <(grep -rl "test\\.extend\\|base\\.extend\\|defineConfig" "$d" --include='*.ts' --include='*.tsx' 2>/dev/null | head -40)
done < <(jq -r '.[]' <<<"$TDIRS")

# --- detect page objects ---------------------------------------------------
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    f="${hit%%:*}"; rest="${hit#*:}"
    cls="$(echo "$rest" | grep -oE "class[[:space:]]+[A-Z][A-Za-z0-9_]*Page" | awk '{print $2}' | head -1)"
    [[ -n "$cls" ]] && PAGES="$(jq --arg f "$f" --arg c "$cls" '. + [{file:$f, class:$c}]' <<<"$PAGES")"
  done < <(grep -rHn "class[[:space:]]\\+[A-Z][A-Za-z0-9_]*Page" "$d" --include='*.ts' --include='*.tsx' 2>/dev/null)
done < <(jq -r '.[]' <<<"$TDIRS")

# --- detect storage states --------------------------------------------------
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    STATES="$(jq --arg f "$f" '. + [$f]' <<<"$STATES")"
  done < <(find "$d" -type f \( -path '*/.auth/*.json' -o -name 'storageState*.json' -o -path '*/storage/*.json' \) 2>/dev/null | head -40)
done < <(jq -r '.[]' <<<"$TDIRS")

# --- global setup ----------------------------------------------------------
if [[ "$CFG" != "null" ]]; then
  cfg_file="$(jq -r . <<<"$CFG")"
  if grep -Eq "globalSetup|globalTeardown" "$cfg_file" 2>/dev/null; then
    HAS_GLOBAL_SETUP=true
  fi
fi

# --- drift hash -------------------------------------------------------------
# Hash the sorted list of test files + their byte sizes. Changing any test or
# adding/removing one flips this hash; the skill uses this to alert the user.
HASH=""
if command -v sha256sum >/dev/null 2>&1; then
  HASH="$(jq -r '.[] | .file' <<<"$TFILES" 2>/dev/null | sort | while IFS= read -r f; do
    sz=$(wc -c <"$f" 2>/dev/null | awk '{print $1}'); printf '%s|%s\n' "$f" "${sz:-0}";
  done | sha256sum | awk '{print $1}')"
fi
[[ -z "$HASH" ]] && HASH="unknown"

# --- assemble ---------------------------------------------------------------
jq -n \
  --arg runner "$RUNNER" \
  --argjson config_file "$CFG" \
  --argjson test_dirs "$TDIRS" \
  --argjson test_files "$TFILES" \
  --argjson fixtures "$FIXTURES" \
  --argjson page_objects "$PAGES" \
  --argjson storage_states "$STATES" \
  --argjson has_global_setup "$HAS_GLOBAL_SETUP" \
  --arg hash "$HASH" \
  '{
    runner: $runner,
    config_file: $config_file,
    test_dirs: $test_dirs,
    test_files: $test_files,
    fixtures: $fixtures,
    page_objects: $page_objects,
    storage_states: $storage_states,
    has_global_setup: $has_global_setup,
    hash: $hash
  }'
