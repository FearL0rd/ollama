#!/usr/bin/env bash
# Usage: visual-regression.sh [--update-baselines] [<state_file>]
#
# Expected `.audit-state.json` `visual_regression` block (artifact §16
# lines 1367-1384). Kept inline here so the script self-documents the
# schema shape when audit-state.schema.json is not yet present.
#
#   "visual_regression": {
#     "enabled": true,
#     "engine": "pixelmatch",            // pixelmatch | odiff | sha256-fallback
#     "threshold": 0.1,                  // per-pixel YIQ (pixelmatch/odiff)
#     "max_diff_pixel_ratio": 0.01,      // 1% pixels allowed
#     "antialiasing": true,
#     "viewports": [
#       { "label": "mobile_375",  "width": 375,  "height": 667  },
#       { "label": "tablet_768",  "width": 768,  "height": 1024 },
#       { "label": "desktop_1280","width": 1280, "height": 800  }
#     ],
#     "mask_selectors": [
#       "[data-timestamp]", ".relative-time",
#       "[data-react-hydration]", "video", "canvas"
#     ],
#     "baseline_dir": ".super-design/baselines",
#     "current_dir":  "docs/super-design/.cache/hashes/screenshots",
#     "diff_dir":     "docs/super-design/.cache/hashes/diffs"
#   }
#
# Runner behaviour:
# - Reads the block from .audit-state.json (default path overridable via
#   positional arg).
# - For every (page, viewport) it finds a current screenshot for, locates
#   the matching baseline PNG, runs the configured diff engine, emits
#   {page, viewport, diff_ratio, threshold, pass, diff_image_path} into
#   <diff_dir>/results.json.
# - Engine fallback chain: pixelmatch (npx) → odiff (npx) → sha256
#   equality (logs warning on stderr).
# - --update-baselines replaces every baseline with the current capture
#   and exits without diffing.
#
# POSIX sh + node; runs under Windows git-bash.
set -euo pipefail

UPDATE_BASELINES=0
STATE="docs/super-design/.audit-state.json"
while (( $# )); do
  case "$1" in
    --update-baselines) UPDATE_BASELINES=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) STATE="$1" ;;
  esac
  shift
done

if [[ ! -f "$STATE" ]]; then
  echo '{"status":"missing-state","hint":"run audit first"}' >&2
  exit 2
fi

# Defaults match artifact §16. jq pulls the override from state, if any.
CFG="$(jq -c '.visual_regression // {}' "$STATE")"
ENABLED="$(jq -r '.enabled // false' <<<"$CFG")"
if [[ "$ENABLED" != "true" && "$UPDATE_BASELINES" -ne 1 ]]; then
  echo '{"status":"disabled","hint":"set visual_regression.enabled=true"}'
  exit 0
fi

BASELINE_DIR="$(jq -r '.baseline_dir // ".super-design/baselines"' <<<"$CFG")"
CURRENT_DIR="$(jq -r '.current_dir  // "docs/super-design/.cache/hashes/screenshots"' <<<"$CFG")"
DIFF_DIR="$(jq -r    '.diff_dir     // "docs/super-design/.cache/hashes/diffs"' <<<"$CFG")"
ENGINE="$(jq -r      '.engine       // "pixelmatch"' <<<"$CFG")"
THRESHOLD="$(jq -r   '.threshold    // 0.1' <<<"$CFG")"
MAX_RATIO="$(jq -r   '.max_diff_pixel_ratio // 0.01' <<<"$CFG")"
ANTIALIAS="$(jq -r   '.antialiasing // true' <<<"$CFG")"

mkdir -p "$BASELINE_DIR" "$DIFF_DIR"

# Enumerate current screenshots the hash-pages.sh pass wrote under
# <current_dir>/<url-encoded-url>/<viewport>.png.
if [[ ! -d "$CURRENT_DIR" ]]; then
  echo "{\"status\":\"no-screenshots\",\"hint\":\"run hash-pages.sh first\",\"looked_in\":\"$CURRENT_DIR\"}" >&2
  exit 2
fi

# --update-baselines: mirror current -> baseline and exit.
if [[ "$UPDATE_BASELINES" -eq 1 ]]; then
  copied=0
  while IFS= read -r -d '' png; do
    rel="${png#$CURRENT_DIR/}"
    dst="$BASELINE_DIR/$rel"
    mkdir -p "$(dirname "$dst")"
    cp -f "$png" "$dst"
    copied=$((copied + 1))
  done < <(find "$CURRENT_DIR" -type f -name '*.png' -print0)
  echo "{\"status\":\"baselines-updated\",\"count\":$copied,\"baseline_dir\":\"$BASELINE_DIR\"}"
  exit 0
fi

# Resolve engine availability up-front so we warn once rather than per page.
resolve_engine() {
  local want="$1"
  case "$want" in
    pixelmatch)
      if command -v npx >/dev/null 2>&1; then
        if npx --yes pixelmatch --help >/dev/null 2>&1; then echo pixelmatch; return; fi
      fi
      ;;
    odiff)
      if command -v npx >/dev/null 2>&1; then
        if npx --yes odiff-bin --help >/dev/null 2>&1; then echo odiff; return; fi
      fi
      ;;
  esac
  # Chain: pixelmatch > odiff > sha256.
  if command -v npx >/dev/null 2>&1; then
    if npx --yes pixelmatch --help >/dev/null 2>&1; then echo pixelmatch; return; fi
    if npx --yes odiff-bin --help  >/dev/null 2>&1; then echo odiff;      return; fi
  fi
  echo sha256-fallback
}

RESOLVED_ENGINE="$(resolve_engine "$ENGINE")"
if [[ "$RESOLVED_ENGINE" == "sha256-fallback" ]]; then
  echo "warning: pixelmatch/odiff unavailable; falling back to sha256 equality (binary pass/fail, diff_ratio will be 0 or 1)" >&2
fi

# Per-comparison worker. Runs in a node one-shot because pixelmatch /
# odiff are both invoked there; sha256 fallback is pure node too.
compare_pair() {
  local baseline="$1"
  local current="$2"
  local diff_out="$3"

  BASE="$baseline" CURR="$current" DIFF="$diff_out" \
  ENGINE="$RESOLVED_ENGINE" THRESHOLD="$THRESHOLD" \
  ANTIALIAS="$ANTIALIAS" \
  node --experimental-vm-modules <<'JS'
import { createHash } from "node:crypto";
import { readFileSync, existsSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { spawnSync } from "node:child_process";

const base = process.env.BASE;
const curr = process.env.CURR;
const diffPath = process.env.DIFF;
const engine = process.env.ENGINE;
const threshold = Number(process.env.THRESHOLD);
const antialias = process.env.ANTIALIAS === "true";

mkdirSync(dirname(diffPath), { recursive: true });

function sha(buf) { return createHash("sha256").update(buf).digest("hex"); }

if (!existsSync(base)) {
  console.log(JSON.stringify({
    pass: false, diff_ratio: 1, reason: "baseline-missing",
    engine, diff_image_path: null,
  }));
  process.exit(0);
}

if (engine === "sha256-fallback") {
  const bHash = sha(readFileSync(base));
  const cHash = sha(readFileSync(curr));
  const ratio = bHash === cHash ? 0 : 1;
  console.log(JSON.stringify({
    pass: ratio === 0, diff_ratio: ratio, engine,
    diff_image_path: null,
  }));
  process.exit(0);
}

if (engine === "pixelmatch") {
  // npx pixelmatch <baseline> <current> <diff> [threshold]
  const r = spawnSync("npx", [
    "--yes", "pixelmatch", base, curr, diffPath, String(threshold),
  ], { encoding: "utf8", shell: process.platform === "win32" });
  // pixelmatch prints e.g. "error: 123 different pixels\n" to stdout.
  // total-pixels isn't emitted, so we read PNG dimensions from the diff
  // header (the diff PNG is always produced even on zero-diff).
  const diffPixels = Number((r.stdout.match(/(\d+)\s+different/) || [0, 0])[1]);
  let total = 1;
  if (existsSync(diffPath)) {
    const buf = readFileSync(diffPath);
    // PNG width/height live at bytes 16..23 big-endian.
    if (buf.length >= 24 && buf[0] === 0x89 && buf[1] === 0x50) {
      const w = buf.readUInt32BE(16);
      const h = buf.readUInt32BE(20);
      total = Math.max(1, w * h);
    }
  }
  const ratio = diffPixels / total;
  console.log(JSON.stringify({
    pass: null, // decided by caller against max_diff_pixel_ratio
    diff_ratio: ratio, diff_pixels: diffPixels, total_pixels: total,
    engine, diff_image_path: diffPath,
    exit: r.status, stderr: (r.stderr || "").trim().slice(0, 500),
  }));
  process.exit(0);
}

if (engine === "odiff") {
  // odiff-bin <baseline> <current> <diff> --threshold=<t>
  const args = [
    "--yes", "odiff-bin", base, curr, diffPath,
    `--threshold=${threshold}`,
  ];
  if (!antialias) args.push("--antialiasing");
  const r = spawnSync("npx", args, {
    encoding: "utf8", shell: process.platform === "win32",
  });
  const matchRatio = (r.stdout + r.stderr).match(/(\d+(?:\.\d+)?)\s*%/);
  const pctDiff = matchRatio ? Number(matchRatio[1]) / 100 : (r.status === 0 ? 0 : 1);
  console.log(JSON.stringify({
    pass: null,
    diff_ratio: pctDiff,
    engine, diff_image_path: diffPath,
    exit: r.status, stderr: (r.stderr || "").trim().slice(0, 500),
  }));
  process.exit(0);
}

// Unknown engine — surface as a hard failure rather than silent pass.
console.log(JSON.stringify({
  pass: false, diff_ratio: 1,
  reason: `unknown-engine:${engine}`, engine, diff_image_path: null,
}));
JS
}

results="[]"
any_fail=0
while IFS= read -r -d '' curr_png; do
  rel="${curr_png#$CURRENT_DIR/}"             # e.g. https%3A%2F%2F.../mobile_375.png
  page_dir="$(dirname "$rel")"
  viewport="$(basename "$rel" .png)"
  page_url="$(printf '%s' "$page_dir" | node -e 'process.stdin.on("data",d=>process.stdout.write(decodeURIComponent(d.toString())))')"
  base_png="$BASELINE_DIR/$rel"
  diff_png="$DIFF_DIR/$rel"

  raw="$(compare_pair "$base_png" "$curr_png" "$diff_png" || echo '{"pass":false,"diff_ratio":1,"reason":"compare-error"}')"

  # Decide pass/fail against max_diff_pixel_ratio when engine left it null.
  merged="$(jq -c \
    --arg page "$page_url" \
    --arg viewport "$viewport" \
    --argjson threshold "$THRESHOLD" \
    --argjson max_ratio "$MAX_RATIO" \
    '. as $r
     | .pass = (if .pass == null then (.diff_ratio <= $max_ratio) else .pass end)
     | .page = $page
     | .viewport = $viewport
     | .threshold = $threshold
     | .max_diff_pixel_ratio = $max_ratio' <<<"$raw")"

  if [[ "$(jq -r '.pass' <<<"$merged")" != "true" ]]; then any_fail=1; fi
  results="$(jq -c --argjson m "$merged" '. + [$m]' <<<"$results")"
done < <(find "$CURRENT_DIR" -type f -name '*.png' -print0)

out_file="$DIFF_DIR/results.json"
mkdir -p "$DIFF_DIR"
jq -n --argjson r "$results" \
  --arg engine "$RESOLVED_ENGINE" \
  --argjson threshold "$THRESHOLD" \
  --argjson max_ratio "$MAX_RATIO" \
  '{engine:$engine, threshold:$threshold, max_diff_pixel_ratio:$max_ratio,
    results:$r, count: ($r|length),
    passed: ([$r[] | select(.pass==true)] | length),
    failed: ([$r[] | select(.pass!=true)] | length)}' \
  >"$out_file"

cat "$out_file"
exit $any_fail
