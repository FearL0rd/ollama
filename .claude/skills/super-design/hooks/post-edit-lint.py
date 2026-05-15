#!/usr/bin/env python3
"""PostToolUse hook: lint just-edited file; exit 2 on NEW errors."""
import json, sys, subprocess, os, hashlib, pathlib

EXT_LINTERS = {
    ".ts":  ["npx", "eslint", "--format", "json"],
    ".tsx": ["npx", "eslint", "--format", "json"],
    ".js":  ["npx", "eslint", "--format", "json"],
    ".jsx": ["npx", "eslint", "--format", "json"],
    ".vue": ["npx", "eslint", "--format", "json"],
    ".svelte": ["npx", "eslint", "--format", "json"],
    ".astro":  ["npx", "eslint", "--format", "json"],
}
BASELINE_DIR = pathlib.Path(".super-design/.cache/lint-baselines")

def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    path = (payload.get("tool_input", {}) or {}).get("file_path", "")
    if not path or not os.path.exists(path):
        sys.exit(0)
    ext = os.path.splitext(path)[1]
    cmd = EXT_LINTERS.get(ext)
    if not cmd:
        sys.exit(0)
    try:
        result = subprocess.run(cmd + [path], capture_output=True, text=True, timeout=30)
    except Exception as e:
        print(f"post-edit-lint: failed to run lint: {e}", file=sys.stderr)
        sys.exit(0)
    try:
        data = json.loads(result.stdout or "[]")
    except Exception:
        sys.exit(0)
    current_count = sum((f.get("errorCount", 0) + f.get("warningCount", 0)) for f in data)
    BASELINE_DIR.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(path.encode()).hexdigest()[:16]
    baseline_file = BASELINE_DIR / f"{key}.txt"
    baseline_count = -1
    if baseline_file.exists():
        try:
            baseline_count = int(baseline_file.read_text().strip())
        except:
            pass
    if baseline_count < 0:
        baseline_file.write_text(str(current_count))
        sys.exit(0)
    if current_count > baseline_count:
        print(f"post-edit-lint: REGRESSION in {path}: {baseline_count} -> {current_count}", file=sys.stderr)
        sys.exit(2)
    baseline_file.write_text(str(current_count))
    sys.exit(0)

if __name__ == "__main__":
    main()
