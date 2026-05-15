#!/usr/bin/env bash
# Usage: hash-pages.sh <urls_file>
#
# Captures three viewports per URL (mobile_375, tablet_768, desktop_1280),
# computes sha256 (exact) + phash (perceptual) for each, and emits a single
# JSON file with one record per URL (artifact §3.4, §10 line 492, §16 lines
# 1367-1384).
#
# Env vars:
#   OUT_DIR          — where to write hashes.json and the per-viewport PNGs
#                      (default: docs/super-design/.cache/hashes).
#   MASK_SELECTORS   — comma-separated CSS selectors masked on every
#                      screenshot via Playwright's `mask:` option with
#                      maskColor "#000". Artifact §3.4 defaults are always
#                      merged in; user-supplied selectors are additive.
#   MASK_COLOR       — overrides the mask fill color (default #000).
#   HASH_URL_TIMEOUT — per-URL navigation timeout ms (default 30000).
#
# Output shape (artifact §10 line 492):
#   {
#     "url": "...",
#     "html_hash":          "sha256:...",
#     "dom_structure_hash": "sha256:...",
#     "screenshot_hash":    "sha256:...",   (desktop, back-compat)
#     "viewport_hashes": {
#       "mobile_375":  { "sha256": "...", "phash": "..." },
#       "tablet_768":  { "sha256": "...", "phash": "..." },
#       "desktop_1280":{ "sha256": "...", "phash": "..." }
#     }
#   }
#
# Perceptual hash (phash):
#   We prefer `sharp` if installed (true DCT/aHash on a 32x32 greyscale
#   downsample). If sharp is unavailable we fall back to a deterministic
#   PNG-structural fingerprint — 64 bits derived from 8 evenly-sliced
#   sha256 windows over the PNG buffer. This is NOT a true perceptual
#   hash; it survives identical re-renders but is sensitive to any pixel
#   change. Compare with Hamming distance only when sharp was used (the
#   emitted record includes an "engine" field so consumers can pick the
#   right distance metric).
set -euo pipefail

URLS="${1:?usage: hash-pages.sh <urls_file>}"
OUT_DIR="${OUT_DIR:-docs/super-design/.cache/hashes}"
MASK_SELECTORS="${MASK_SELECTORS:-}"
MASK_COLOR="${MASK_COLOR:-#000}"
HASH_URL_TIMEOUT="${HASH_URL_TIMEOUT:-30000}"
mkdir -p "$OUT_DIR"

URLS="$URLS" OUT_DIR="$OUT_DIR" \
MASK_SELECTORS="$MASK_SELECTORS" MASK_COLOR="$MASK_COLOR" \
HASH_URL_TIMEOUT="$HASH_URL_TIMEOUT" node --experimental-vm-modules <<'JS'
import { chromium } from "playwright";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const urlsFile = process.env.URLS;
const outDir = process.env.OUT_DIR;
const maskColor = process.env.MASK_COLOR || "#000";
const navTimeout = Number(process.env.HASH_URL_TIMEOUT || 30000);

// Artifact §3.4 defaults — always masked.
const DEFAULT_MASKS = [
  "[data-timestamp]",
  ".relative-time",
  "[data-react-hydration]",
  "video",
  "canvas",
];
const userMasks = (process.env.MASK_SELECTORS || "")
  .split(",").map(s => s.trim()).filter(Boolean);
const maskSelectors = [...new Set([...DEFAULT_MASKS, ...userMasks])];

// Volatile attributes stripped from the DOM structure hash (artifact §3.4
// — added data-react-hydration to match the mask defaults).
const VOLATILE_ATTRS = new Set([
  "nonce",
  "data-timestamp",
  "data-reactid",
  "data-next-hydrate",
  "data-react-hydration",
]);

const urls = readFileSync(urlsFile, "utf8")
  .split("\n").map(s => s.trim()).filter(Boolean);

const VIEWPORTS = [
  { label: "mobile_375",  width: 375,  height: 667  },
  { label: "tablet_768",  width: 768,  height: 1024 },
  { label: "desktop_1280", width: 1280, height: 800  },
];

const sha = (s) => createHash("sha256").update(s).digest("hex");

// Optional sharp — gives us a real perceptual hash. Falls back to a
// PNG-structural fingerprint (documented in the header) when absent.
let sharp = null;
let phashEngine = "fallback-png-fingerprint";
try {
  sharp = (await import("sharp")).default;
  phashEngine = "sharp-ahash-8x8";
} catch { /* no sharp installed; use fallback */ }

async function aHash(buf) {
  if (!sharp) return fallbackFingerprint(buf);
  // Average-hash: downscale to 8x8 greyscale, threshold at mean.
  const raw = await sharp(buf)
    .greyscale()
    .resize(8, 8, { fit: "fill", kernel: "cubic" })
    .raw()
    .toBuffer();
  let sum = 0;
  for (let i = 0; i < raw.length; i++) sum += raw[i];
  const mean = sum / raw.length;
  let bits = 0n;
  for (let i = 0; i < 64; i++) {
    bits = (bits << 1n) | (raw[i] >= mean ? 1n : 0n);
  }
  return bits.toString(16).padStart(16, "0");
}

function fallbackFingerprint(buf) {
  // Zero-dep deterministic fingerprint: slice PNG into 8 windows, take the
  // first byte of each window's sha256, concat to 16 hex chars. Order of
  // magnitude cheaper than a real pHash and only collision-safe for
  // identical-buffer comparisons, but it gives us a stable 64-bit slot in
  // viewport_hashes so downstream tooling can still key on it.
  if (buf.length === 0) return "0".repeat(16);
  const windows = 8;
  const step = Math.max(1, Math.floor(buf.length / windows));
  let out = "";
  for (let i = 0; i < windows; i++) {
    const start = i * step;
    const end = i === windows - 1 ? buf.length : start + step;
    const slice = buf.subarray(start, end);
    const h = createHash("sha256").update(slice).digest();
    out += h.subarray(0, 1).toString("hex");
  }
  return out;
}

const browser = await chromium.launch();
const results = [];
for (const url of urls) {
  const entry = { url, viewport_hashes: {} };
  try {
    // Shared context: cache html/dom work on first (desktop) viewport.
    let capturedHtml = null;
    let capturedDom = null;

    for (const vp of VIEWPORTS) {
      const ctx = await browser.newContext({
        viewport: { width: vp.width, height: vp.height },
        reducedMotion: "reduce",
        deviceScaleFactor: 1,
      });
      const page = await ctx.newPage();
      await page.goto(url, { waitUntil: "networkidle", timeout: navTimeout });

      if (capturedHtml === null) {
        capturedHtml = (await page.content()).replace(/\s+/g, " ").trim();
        capturedDom = await page.evaluate((volatileList) => {
          const V = new Set(volatileList);
          const walk = (n) => n.nodeType !== 1 ? "" :
            `<${n.tagName.toLowerCase()}[${[...n.attributes]
              .filter(a => !V.has(a.name))
              .map(a => `${a.name}=${a.value}`)
              .sort().join(",")}]${[...n.childNodes].map(walk).join("")}>`;
          return walk(document.documentElement);
        }, [...VOLATILE_ATTRS]);
      }

      // Build mask locator list (skip selectors that error — they're OK
      // if nothing matches; only invalid syntax throws).
      const masks = [];
      for (const sel of maskSelectors) {
        try { masks.push(page.locator(sel)); } catch { /* bad selector */ }
      }

      const buf = await page.screenshot({
        fullPage: true,
        animations: "disabled",
        caret: "hide",
        mask: masks,
        maskColor,
      });

      // Persist PNG for visual-regression.sh to consume.
      const pngDir = join(outDir, "screenshots", encodeURIComponent(url));
      mkdirSync(pngDir, { recursive: true });
      const pngPath = join(pngDir, `${vp.label}.png`);
      writeFileSync(pngPath, buf);

      const ph = await aHash(buf);
      entry.viewport_hashes[vp.label] = {
        sha256: "sha256:" + sha(buf),
        phash: `${phashEngine === "sharp-ahash-8x8" ? "phash" : "fpr"}:${ph}`,
        png_path: pngPath,
      };

      if (vp.label === "desktop_1280") {
        entry.screenshot_hash = entry.viewport_hashes[vp.label].sha256;
      }

      await ctx.close();
    }

    entry.html_hash = "sha256:" + sha(capturedHtml);
    entry.dom_structure_hash = "sha256:" + sha(capturedDom);
    entry.mask_selectors = maskSelectors;
    entry.phash_engine = phashEngine;
  } catch (e) {
    entry.error = String(e.message || e);
  }
  results.push(entry);
}

writeFileSync(join(outDir, "hashes.json"), JSON.stringify(results, null, 2));
await browser.close();
console.log(JSON.stringify({
  count: results.length,
  path: join(outDir, "hashes.json"),
  phash_engine: phashEngine,
  viewports: VIEWPORTS.map(v => v.label),
  mask_selectors: maskSelectors,
}));
JS
