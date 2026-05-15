#!/usr/bin/env bash
# Usage: setup-git-notes.sh
#
# One-shot setup so `git notes --ref=super-design` round-trips across
# clones. Without the remote refspec, git fetch ignores notes by default
# (artifact §7 line 570-573).
set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"error":"not-a-git-repo"}' >&2; exit 3
fi

# Idempotent: only add if absent.
if git config --get-all remote.origin.fetch 2>/dev/null |
   grep -q 'refs/notes/super-design'; then
  echo '{"status":"already-configured"}'
else
  git config --add remote.origin.fetch \
    '+refs/notes/super-design:refs/notes/super-design'
  echo '{"status":"added","ref":"refs/notes/super-design"}'
fi
