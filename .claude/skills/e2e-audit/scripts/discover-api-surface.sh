#!/usr/bin/env bash
# discover-api-surface.sh — enumerate every network-facing surface a browser
# or third-party client can hit: REST/HTTP route handlers, tRPC procedures,
# GraphQL resolvers, and server actions.
#
# Why: Playwright deduction misses endpoints that aren't touched by the
# flow you tested. A procedure that's only called from Settings > Advanced
# > Danger Zone, or an API route called only by a webhook, won't show up
# in a traffic log. This script reads the SOURCE and emits the full
# contract so the skill can report which endpoints HAVE no tests.
#
# Output: JSON object on stdout:
# {
#   "http_routes":     [{ "method": "POST", "path": "/api/users", "file": "...", "auth": "protected"|"public"|"unknown", "zod_schema_found": true|false }],
#   "trpc_procedures": [{ "name": "users.create", "kind": "query"|"mutation"|"subscription", "file": "...", "auth": "protected"|"public"|"unknown", "input_schema_found": true|false }],
#   "graphql":         { "found": true|false, "files": [...] },
#   "server_actions":  [{ "name": "createUser", "file": "...", "directive": "'use server'"|"file-scoped" }],
#   "middleware":      { "file": "middleware.ts"|null, "has_auth_guard": true|false, "matches_public_patterns": [...] }
# }
#
# No AST. False positives are OK — skill cross-references this with tests.
set -euo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 2; }

HTTP='[]'
TRPC='[]'
GQL_FOUND=false
GQL_FILES='[]'
ACTIONS='[]'
MW_FILE="null"
MW_AUTH=false
MW_PUBLIC='[]'

# --- 1. HTTP ROUTE HANDLERS -------------------------------------------------
# Next.js app router: app/**/route.{ts,tsx,js} with exported METHOD handlers.
# Next.js pages router: pages/api/**/*.{ts,tsx,js} with default export.
# Remix: resource routes (files in app/routes with a loader/action but no default).
# Express/Hono/Fastify: app.get/post/put/delete/patch etc.
METHODS='GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS'

# Next.js app router route.ts
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # URL path: strip app/src/app prefix and /route.* suffix; keep [param].
  p="$f"; p="${p#src/app/}"; p="${p#app/}"; p="${p%/route.ts}"; p="${p%/route.tsx}"; p="${p%/route.js}"
  # strip route-group segments
  p="$(echo "$p" | awk -F/ '{out=""; for(i=1;i<=NF;i++){if($i~/^\(.*\)$/)continue; out=out(out==""?"":"/")$i} print out}')"
  url="/$p"
  # which methods are exported?
  for m in GET POST PUT PATCH DELETE HEAD OPTIONS; do
    if grep -Eq "export[[:space:]]+(async[[:space:]]+)?function[[:space:]]+$m\\b|export[[:space:]]+const[[:space:]]+$m[[:space:]]*=" "$f" 2>/dev/null; then
      # zod schema mentioned in file?
      zod=false
      grep -Eq "z\\.object\\(|safeParse|\\.parse\\(|zodResolver" "$f" 2>/dev/null && zod=true
      # auth hint: look for session/auth/protected keywords
      auth="unknown"
      if   grep -Eq "getServerSession|auth\\(\\)|requireAuth|requireSession|getSession|currentUser\\(|userId" "$f" 2>/dev/null; then auth="protected"
      elif grep -Eq "// public|@public" "$f" 2>/dev/null; then auth="public"
      fi
      HTTP="$(jq --arg m "$m" --arg p "$url" --arg f "$f" --arg a "$auth" --argjson z "$zod" \
                '. + [{method:$m, path:$p, file:$f, auth:$a, zod_schema_found:$z}]' <<<"$HTTP")"
    fi
  done
done < <(find app src/app -type f \( -name 'route.ts' -o -name 'route.tsx' -o -name 'route.js' \) 2>/dev/null)

# Next.js pages/api
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  p="$f"; p="${p#src/pages/}"; p="${p#pages/}"
  p="${p%.ts}"; p="${p%.tsx}"; p="${p%.js}"; p="${p%.jsx}"
  # index.ts -> directory path
  p="${p%/index}"
  url="/$p"
  auth="unknown"
  if grep -Eq "getServerSession|requireAuth|getSession|authenticate\\(|req\\.session" "$f" 2>/dev/null; then auth="protected"; fi
  zod=false
  grep -Eq "z\\.object\\(|safeParse|\\.parse\\(" "$f" 2>/dev/null && zod=true
  HTTP="$(jq --arg p "$url" --arg f "$f" --arg a "$auth" --argjson z "$zod" \
            '. + [{method:"ANY", path:$p, file:$f, auth:$a, zod_schema_found:$z}]' <<<"$HTTP")"
done < <(find pages/api src/pages/api -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' \) 2>/dev/null)

# Express / Hono / Fastify style (app.get/post/...)
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  f="${hit%%:*}"; rest="${hit#*:}"
  line="${rest%%:*}"
  match="${rest#*:}"
  m="$(echo "$match" | grep -oE "\\.(get|post|put|patch|delete|head|options)\\(" | head -1 | tr -d '.(' | tr '[:lower:]' '[:upper:]')"
  url="$(echo "$match" | grep -oE "[\"'][^\"']+[\"']" | head -1 | tr -d "\"'")"
  [[ -z "$m" || -z "$url" ]] && continue
  [[ "$url" =~ ^/ ]] || continue
  HTTP="$(jq --arg m "$m" --arg p "$url" --arg f "$f" \
            '. + [{method:$m, path:$p, file:$f, auth:"unknown", zod_schema_found:false}]' <<<"$HTTP")"
done < <(grep -rEHn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' \
           "\\.(get|post|put|patch|delete|head|options)\\([\"'][^\"']+[\"']" \
           src server app 2>/dev/null | head -500 || true)

# --- 2. tRPC PROCEDURES -----------------------------------------------------
# Look for files that import `router` or `procedure` and enumerate calls:
#   foo: publicProcedure.input(...).query(...)
#   bar: protectedProcedure.mutation(...)
#
# We don't build a router namespace tree; we emit procedure names as seen.
# Nested router paths can be computed by the skill from the file layout.
TRPC_FILES="$(grep -rl -E "createTRPCRouter|publicProcedure|protectedProcedure|router\\(\\{" \
  --include='*.ts' --include='*.tsx' \
  src server 2>/dev/null || true)"

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # For each procedure definition in this file, capture name + kind + auth.
  # Pattern matches: <name>: (public|protected|<prefix>)Procedure[.input(...)]?.<query|mutation|subscription>
  awk -v file="$f" '
    /(\w+Procedure)/ {
      # join multi-line chains until we hit one of the terminators.
      chain = chain " " $0
    }
    /\.query\s*\(|\.mutation\s*\(|\.subscription\s*\(/ {
      chain = chain " " $0
      # extract name (the last "foo:" before the chain start)
      if (match(chain, /([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[A-Za-z_][A-Za-z0-9_]*Procedure/, m)) {
        name = m[1]
      } else name = "_"
      # extract kind
      if (chain ~ /\.query\s*\(/) kind = "query"
      else if (chain ~ /\.mutation\s*\(/) kind = "mutation"
      else kind = "subscription"
      # extract auth (protected vs public vs custom)
      if (chain ~ /protectedProcedure/) auth = "protected"
      else if (chain ~ /publicProcedure/) auth = "public"
      else auth = "unknown"
      # input schema?
      input_found = (chain ~ /\.input\s*\(/) ? "true" : "false"
      printf "%s|%s|%s|%s|%s\n", name, kind, file, auth, input_found
      chain = ""
    }
  ' "$f" 2>/dev/null || true
done <<<"$TRPC_FILES" | while IFS='|' read -r name kind file auth input_found; do
  [[ -z "$name" ]] && continue
  jq --arg n "$name" --arg k "$kind" --arg f "$file" --arg a "$auth" --argjson i "$input_found" \
     '. + [{name:$n, kind:$k, file:$f, auth:$a, input_schema_found:$i}]'
done > /tmp/e2e-audit-trpc-$$.jsonl || true

if [[ -s /tmp/e2e-audit-trpc-$$.jsonl ]]; then
  # The above pipeline created one growing JSON object per line via jq --arg,
  # but each jq invocation started from scratch. Join properly:
  TRPC='[]'
  while IFS= read -r _; do :; done < /tmp/e2e-audit-trpc-$$.jsonl
fi
rm -f /tmp/e2e-audit-trpc-$$.jsonl

# Simpler, correct approach for tRPC — rebuild as JSON array in a single pass.
TRPC='[]'
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  while IFS='|' read -r name kind file auth input_found; do
    [[ -z "$name" ]] && continue
    TRPC="$(jq --arg n "$name" --arg k "$kind" --arg fi "$file" --arg a "$auth" --argjson i "$input_found" \
              '. + [{name:$n, kind:$k, file:$fi, auth:$a, input_schema_found:$i}]' <<<"$TRPC")"
  done < <(
    awk -v file="$f" '
      /(\w+Procedure)/ { chain = chain " " $0 }
      /\.query\s*\(|\.mutation\s*\(|\.subscription\s*\(/ {
        chain = chain " " $0
        name = "_"
        if (match(chain, /([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*Procedure/, m)) name = m[1]
        if (chain ~ /\.query[[:space:]]*\(/) kind = "query"
        else if (chain ~ /\.mutation[[:space:]]*\(/) kind = "mutation"
        else kind = "subscription"
        if (chain ~ /protectedProcedure/) auth = "protected"
        else if (chain ~ /publicProcedure/) auth = "public"
        else auth = "unknown"
        input_found = (chain ~ /\.input[[:space:]]*\(/) ? "true" : "false"
        printf "%s|%s|%s|%s|%s\n", name, kind, file, auth, input_found
        chain = ""
      }
    ' "$f" 2>/dev/null
  )
done <<<"$TRPC_FILES"

# --- 3. GRAPHQL -------------------------------------------------------------
GQL_HITS="$(grep -rl -E 'typeDefs|buildSchema|gql`|@ObjectType|@Resolver|createSchema' \
  --include='*.ts' --include='*.tsx' --include='*.graphql' --include='*.gql' \
  src server schema 2>/dev/null | head -50 || true)"
if [[ -n "$GQL_HITS" ]]; then
  GQL_FOUND=true
  GQL_FILES="$(echo "$GQL_HITS" | jq -Rn '[inputs]')"
fi

# --- 4. SERVER ACTIONS (Next.js) --------------------------------------------
# Two forms: 'use server' directive at top of file, or 'use server' inline in a
# function body. We emit both kinds.
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if grep -Eq "^['\"]use server['\"]" "$f" 2>/dev/null; then
    # File-scoped: every exported async function is an action.
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      ACTIONS="$(jq --arg n "$name" --arg fi "$f" '. + [{name:$n, file:$fi, directive:"file-scoped"}]' <<<"$ACTIONS")"
    done < <(grep -Eo "export[[:space:]]+(async[[:space:]]+)?function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*" "$f" \
             | awk '{print $NF}' | sed 's/^function[[:space:]]*//')
  fi
  # Inline: async function () { 'use server'; ... }
  while IFS= read -r hit; do
    name="$(echo "$hit" | grep -oE "function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*" | awk '{print $2}')"
    [[ -z "$name" ]] && continue
    ACTIONS="$(jq --arg n "$name" --arg fi "$f" '. + [{name:$n, file:$fi, directive:"'\''use server'\''"}]' <<<"$ACTIONS")"
  done < <(grep -B1 -E "^[[:space:]]*['\"]use server['\"]" "$f" 2>/dev/null | grep -E "function[[:space:]]+[A-Za-z_]" || true)
done < <(find src app server -type f \( -name '*.ts' -o -name '*.tsx' \) 2>/dev/null)

# --- 5. MIDDLEWARE (Next.js) -----------------------------------------------
for cand in middleware.ts middleware.js src/middleware.ts src/middleware.js; do
  if [[ -f "$cand" ]]; then
    MW_FILE="\"$cand\""
    grep -Eq "auth|getToken|getSession|currentUser|getServerSession|redirect\\(.*sign[_-]?in" "$cand" 2>/dev/null && MW_AUTH=true
    # Extract matcher patterns that look like public paths.
    while IFS= read -r pat; do
      [[ -z "$pat" ]] && continue
      MW_PUBLIC="$(jq --arg p "$pat" '. + [$p]' <<<"$MW_PUBLIC")"
    done < <(grep -oE "['\"]/[^'\"]*['\"]" "$cand" | tr -d "'\"" | sort -u | head -40)
    break
  fi
done

# --- ASSEMBLE ---------------------------------------------------------------
jq -n \
  --argjson http "$HTTP" \
  --argjson trpc "$TRPC" \
  --argjson graphql_found "$GQL_FOUND" \
  --argjson graphql_files "$GQL_FILES" \
  --argjson actions "$ACTIONS" \
  --argjson mw_file "$MW_FILE" \
  --argjson mw_auth "$MW_AUTH" \
  --argjson mw_public "$MW_PUBLIC" \
  '{
    http_routes: ($http | unique_by([.method, .path, .file])),
    trpc_procedures: ($trpc | unique_by([.name, .kind, .file])),
    graphql: { found: $graphql_found, files: $graphql_files },
    server_actions: ($actions | unique_by([.name, .file])),
    middleware: { file: $mw_file, has_auth_guard: $mw_auth, matches_public_patterns: $mw_public }
  }'
