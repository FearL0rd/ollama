#!/usr/bin/env python3
"""PreToolUse hook: reject Edit/MultiEdit/Write on protected paths."""
import json, sys, re

DENY_PATTERNS = [
    r"^\.env", r"(^|/)node_modules/", r"(^|/)dist/", r"(^|/)\.next/",
    r"(^|/)build/", r"(^|/)out/", r"package-lock\.json$",
    r"pnpm-lock\.yaml$", r"yarn\.lock$", r"^\.git/",
]
ALLOW_PREFIXES = [
    "src/", "app/", "pages/", "components/", "styles/", "public/",
    "docs/super-design/", ".super-design/", ".claude/",
]

def main():
    try:
        payload = json.load(sys.stdin)
    except Exception as e:
        print(f"guard-paths: invalid stdin JSON: {e}", file=sys.stderr)
        sys.exit(0)
    path = (payload.get("tool_input", {}) or {}).get("file_path", "")
    if not path:
        sys.exit(0)
    rel = path.lstrip("./")
    for pat in DENY_PATTERNS:
        if re.search(pat, rel):
            print(f"guard-paths: BLOCKED edit on protected path: {rel}", file=sys.stderr)
            sys.exit(2)
    if not any(rel.startswith(p) for p in ALLOW_PREFIXES):
        print(f"guard-paths: WARN edit outside configured source roots: {rel}", file=sys.stderr)
        sys.exit(0)
    sys.exit(0)

if __name__ == "__main__":
    main()
