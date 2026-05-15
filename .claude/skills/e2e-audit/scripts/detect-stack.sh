#!/usr/bin/env bash
# detect-stack.sh — identify framework, test runner, package manager, dev server,
# and environment files so downstream scripts + the skill prompt can adapt.
#
# Output: JSON object on stdout:
# {
#   "framework":       "next" | "remix" | "sveltekit" | "nuxt" | "astro" | "express" | "hono" | "fastify" | "unknown",
#   "router_style":    "app-router" | "pages-router" | "mixed" | "file-routes" | "n/a",
#   "trpc":            true | false,
#   "trpc_version":    "10" | "11" | "unknown" | null,
#   "graphql":         true | false,
#   "orm":             ["prisma" | "drizzle" | "mongoose" | "typeorm" | "kysely", ...],
#   "auth":            ["next-auth" | "authjs" | "clerk" | "auth0" | "lucia" | "better-auth" | "supabase" | "custom", ...],
#   "test_runner":     "playwright" | "cypress" | "vitest-browser" | "jest-puppeteer" | "none",
#   "playwright_config": "playwright.config.ts" | null,
#   "package_manager": "bun" | "pnpm" | "yarn" | "npm",
#   "dev_command":     "bun run dev" | "pnpm dev" | ...,
#   "dev_port":        <number> | null,
#   "base_url":        "http://localhost:<port>",
#   "env_files":       [".env.local", ".env.test", ...],
#   "src_root":        "src" | "app" | "." ,
#   "has_middleware":  true | false,
#   "middleware_file": "middleware.ts" | "src/middleware.ts" | null
# }
#
# Best-effort. Absence of jq is fatal (downstream scripts require it).
set -euo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }

read_pkg() {
  [[ -f package.json ]] || { echo "null"; return; }
  jq -r "${1:-.}" package.json 2>/dev/null || echo "null"
}

has_dep() {
  local name="$1"
  [[ -f package.json ]] || return 1
  jq -e --arg n "$name" '(.dependencies[$n]? // .devDependencies[$n]? // empty)' package.json >/dev/null 2>&1
}

dep_version() {
  local name="$1"
  [[ -f package.json ]] || { echo ""; return; }
  jq -r --arg n "$name" '.dependencies[$n]? // .devDependencies[$n]? // ""' package.json 2>/dev/null | sed 's/^[^0-9]*//'
}

# --- framework --------------------------------------------------------------
FRAMEWORK="unknown"
ROUTER_STYLE="n/a"
if   has_dep next; then
  FRAMEWORK="next"
  if   [[ -d app || -d src/app ]] && [[ -d pages || -d src/pages ]]; then ROUTER_STYLE="mixed"
  elif [[ -d app || -d src/app ]]; then ROUTER_STYLE="app-router"
  elif [[ -d pages || -d src/pages ]]; then ROUTER_STYLE="pages-router"
  fi
elif has_dep @remix-run/react || has_dep @remix-run/node; then FRAMEWORK="remix"; ROUTER_STYLE="file-routes"
elif has_dep @sveltejs/kit; then FRAMEWORK="sveltekit"; ROUTER_STYLE="file-routes"
elif has_dep nuxt;       then FRAMEWORK="nuxt";       ROUTER_STYLE="file-routes"
elif has_dep astro;      then FRAMEWORK="astro";      ROUTER_STYLE="file-routes"
elif has_dep hono;       then FRAMEWORK="hono"
elif has_dep fastify;    then FRAMEWORK="fastify"
elif has_dep express;    then FRAMEWORK="express"
fi

# --- trpc / graphql ---------------------------------------------------------
TRPC=false; TRPC_VER="null"
if has_dep @trpc/server; then
  TRPC=true
  v="$(dep_version @trpc/server)"
  if   [[ "$v" =~ ^10\. ]]; then TRPC_VER='"10"'
  elif [[ "$v" =~ ^11\. ]]; then TRPC_VER='"11"'
  else TRPC_VER='"unknown"'
  fi
fi
GRAPHQL=false
if has_dep graphql || has_dep @apollo/server || has_dep @apollo/client || has_dep graphql-yoga; then
  GRAPHQL=true
fi

# --- ORMs -------------------------------------------------------------------
orm_arr='[]'
for candidate in @prisma/client drizzle-orm mongoose typeorm kysely; do
  if has_dep "$candidate"; then
    short="${candidate##*/}"; short="${short%-orm}"
    orm_arr="$(jq --arg o "$short" '. + [$o]' <<<"$orm_arr")"
  fi
done

# --- auth providers ---------------------------------------------------------
auth_arr='[]'
add_auth() { auth_arr="$(jq --arg o "$1" '. + [$o]' <<<"$auth_arr")"; }
has_dep next-auth        && add_auth next-auth
has_dep @auth/core       && add_auth authjs
has_dep @clerk/nextjs    && add_auth clerk
has_dep @clerk/clerk-sdk-node && add_auth clerk
has_dep @auth0/nextjs-auth0 && add_auth auth0
has_dep lucia            && add_auth lucia
has_dep better-auth      && add_auth better-auth
has_dep @supabase/supabase-js && add_auth supabase

# --- test runner ------------------------------------------------------------
TEST_RUNNER="none"
PLAYWRIGHT_CFG="null"
if has_dep @playwright/test; then
  TEST_RUNNER="playwright"
  for c in playwright.config.ts playwright.config.js playwright.config.mjs; do
    [[ -f "$c" ]] && PLAYWRIGHT_CFG="\"$c\"" && break
  done
elif has_dep cypress; then TEST_RUNNER="cypress"
elif has_dep @vitest/browser; then TEST_RUNNER="vitest-browser"
elif has_dep jest-puppeteer; then TEST_RUNNER="jest-puppeteer"
fi

# --- package manager + dev command -----------------------------------------
if   [[ -f bun.lockb || -f bun.lock ]]; then PM="bun";  DEV_CMD="bun run dev"
elif [[ -f pnpm-lock.yaml ]];            then PM="pnpm"; DEV_CMD="pnpm dev"
elif [[ -f yarn.lock ]];                 then PM="yarn"; DEV_CMD="yarn dev"
else                                          PM="npm";  DEV_CMD="npm run dev"
fi

# Check `scripts.dev` exists; fall back to start script if not.
if [[ -f package.json ]]; then
  HAS_DEV="$(jq -r '.scripts.dev // empty' package.json)"
  [[ -z "$HAS_DEV" ]] && {
    if jq -re '.scripts.start' package.json >/dev/null 2>&1; then
      DEV_CMD="${DEV_CMD% dev} start"
    fi
  }
fi

# --- dev port ---------------------------------------------------------------
DEV_PORT="null"
# Common places: package.json scripts.dev "-p 3000" or "--port 3000", next.config, remix config
if [[ -f package.json ]]; then
  if script="$(jq -r '.scripts.dev // ""' package.json)"; then
    p="$(echo "$script" | grep -oE -- '--port[= ]+[0-9]+|-p[= ]+[0-9]+|PORT=[0-9]+' | grep -oE '[0-9]+' | head -1 || true)"
    [[ -n "$p" ]] && DEV_PORT="$p"
  fi
fi
# Fallback defaults per framework
if [[ "$DEV_PORT" == "null" ]]; then
  case "$FRAMEWORK" in
    next|express|hono|fastify) DEV_PORT=3000 ;;
    remix)                     DEV_PORT=3000 ;;
    sveltekit)                 DEV_PORT=5173 ;;
    nuxt)                      DEV_PORT=3000 ;;
    astro)                     DEV_PORT=4321 ;;
  esac
fi
BASE_URL="http://localhost:${DEV_PORT:-3000}"

# --- env files --------------------------------------------------------------
env_arr='[]'
for f in .env .env.local .env.development .env.development.local .env.test .env.test.local; do
  [[ -f "$f" ]] && env_arr="$(jq --arg n "$f" '. + [$n]' <<<"$env_arr")"
done

# --- src root + middleware --------------------------------------------------
SRC_ROOT="."
[[ -d src ]] && SRC_ROOT="src"
[[ -d app && ! -d src/app ]] && SRC_ROOT="."
HAS_MW=false; MW_FILE="null"
for f in middleware.ts middleware.js src/middleware.ts src/middleware.js; do
  if [[ -f "$f" ]]; then HAS_MW=true; MW_FILE="\"$f\""; break; fi
done

# --- assemble ---------------------------------------------------------------
jq -n \
  --arg framework "$FRAMEWORK" \
  --arg router_style "$ROUTER_STYLE" \
  --argjson trpc "$TRPC" \
  --argjson trpc_version "$TRPC_VER" \
  --argjson graphql "$GRAPHQL" \
  --argjson orm "$orm_arr" \
  --argjson auth "$auth_arr" \
  --arg test_runner "$TEST_RUNNER" \
  --argjson playwright_config "$PLAYWRIGHT_CFG" \
  --arg package_manager "$PM" \
  --arg dev_command "$DEV_CMD" \
  --argjson dev_port "${DEV_PORT:-null}" \
  --arg base_url "$BASE_URL" \
  --argjson env_files "$env_arr" \
  --arg src_root "$SRC_ROOT" \
  --argjson has_middleware "$HAS_MW" \
  --argjson middleware_file "$MW_FILE" \
  '{
    framework: $framework,
    router_style: $router_style,
    trpc: $trpc,
    trpc_version: $trpc_version,
    graphql: $graphql,
    orm: $orm,
    auth: $auth,
    test_runner: $test_runner,
    playwright_config: $playwright_config,
    package_manager: $package_manager,
    dev_command: $dev_command,
    dev_port: $dev_port,
    base_url: $base_url,
    env_files: $env_files,
    src_root: $src_root,
    has_middleware: $has_middleware,
    middleware_file: $middleware_file
  }'
