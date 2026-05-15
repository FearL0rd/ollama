#!/usr/bin/env bash
set -euo pipefail
PREV="${1:?usage: diff-tokens.sh <prev> <curr>}"
CURR="${2:?usage: diff-tokens.sh <prev> <curr>}"
jq -n --slurpfile a "$PREV" --slurpfile b "$CURR" '
  ($a[0] // {}) as $before | ($b[0] // {}) as $after |
  {
    added: [$after | to_entries[] | select(.key as $k | ($before | has($k)) | not) | .key],
    removed: [$before | to_entries[] | select(.key as $k | ($after | has($k)) | not) | .key],
    modified: [$after | to_entries[] |
      select(.key as $k | ($before | has($k)) and (.value != $before[$k])) |
      { key: .key, before: $before[.key], after: .value }]
  }'
