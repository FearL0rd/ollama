#!/usr/bin/env node
// Extract + canonicalize + hash design tokens from Tailwind configs, CSS custom
// properties, and DTCG / Tokens Studio JSON (artifact §9.1 lines 707-709, §9.2
// lines 720-761). Output is deterministic regardless of insertion order
// (artifact §9.2 line 722: "canonical = JSON.stringify(theme,
// Object.keys(theme).sort())").
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";

const out = {};
const sources = [];
const tailwindConfigs = ["tailwind.config.ts", "tailwind.config.js", "tailwind.config.mjs", "tailwind.config.cjs"];
let tailwindFound = false;
for (const candidate of tailwindConfigs) {
  if (fs.existsSync(candidate)) {
    try {
      const { default: resolveConfig } = await import("tailwindcss/resolveConfig");
      const cfg = (await import(pathToFileURL(path.resolve(candidate)).href)).default;
      const resolved = resolveConfig(cfg);
      flatten(resolved.theme, "tw", out);
      tailwindFound = true;
    } catch (e) { out[`_error_${candidate}`] = String(e.message || e); }
    break;
  }
}
if (tailwindFound) sources.push("tailwind");

let cssFound = false;
try {
  const postcss = (await import("postcss")).default;
  const cssCandidates = ["styles/globals.css","src/styles/globals.css","app/globals.css","styles/theme.css","src/app/globals.css"];
  for (const css of cssCandidates) {
    if (!fs.existsSync(css)) continue;
    const source = fs.readFileSync(css, "utf8");
    const root = postcss.parse(source);
    root.walkAtRules("theme", at => { at.walkDecls(/^--/, d => { out[`css:${d.prop}`] = d.value.trim(); cssFound = true; }); });
    root.walkRules(":root", rule => { rule.walkDecls(/^--/, d => { out[`css:${d.prop}`] = d.value.trim(); cssFound = true; }); });
  }
} catch (e) { out._postcss_error = String(e.message || e); }
if (cssFound) sources.push("css-vars");

// DTCG + Tokens Studio support (artifact §9.1 line 707-709, §9.2 line 747).
const dtcgFiles = discoverDtcgFiles(".");
let dtcgFound = false;
for (const file of dtcgFiles) {
  try {
    const raw = fs.readFileSync(file, "utf8");
    const parsed = JSON.parse(raw);
    // Tokens Studio $metadata/$themes are not token trees — skip.
    if (path.basename(file) === "$metadata.json" || path.basename(file) === "$themes.json") continue;
    const resolved = resolveDtcgAliases(parsed, file);
    const relFile = path.relative(".", file).replaceAll("\\", "/");
    flattenDtcg(resolved, `dtcg:${relFile}`, out);
    dtcgFound = true;
  } catch (e) {
    out[`_dtcg_error_${file}`] = String(e.message || e);
  }
}
if (dtcgFound) sources.push("dtcg");

// Deterministic canonical form: keys sorted top-to-bottom.
const sorted = Object.keys(out).sort().reduce((acc, k) => { acc[k] = out[k]; return acc; }, {});
const canonical = JSON.stringify(sorted);
const tokens_hash = "sha256:" + createHash("sha256").update(canonical).digest("hex");

console.log(JSON.stringify({ tokens: sorted, tokens_hash, sources: sources.sort() }, null, 2));

function flatten(obj, prefix, acc) {
  if (obj == null) return;
  if (typeof obj !== "object") { acc[prefix] = String(obj); return; }
  // Sort keys so hash is stable across JS engines / config formatters.
  // Artifact §9.2 line 722 calls this out explicitly.
  for (const k of Object.keys(obj).sort()) {
    const v = obj[k];
    const key = `${prefix}.${k}`;
    if (v && typeof v === "object" && !Array.isArray(v)) flatten(v, key, acc);
    else acc[key] = Array.isArray(v) ? v.join(",") : String(v);
  }
}

// Walk cwd, returning **/*.tokens.json (excluding build/vendor dirs) plus the
// two conventional Tokens Studio single-file exports.
function discoverDtcgFiles(rootDir) {
  const skipDirs = new Set(["node_modules", "dist", ".next", "build", ".git", "coverage", ".turbo", ".cache"]);
  const found = [];
  const walk = (dir) => {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (skipDirs.has(entry.name) || entry.name.startsWith(".")) {
          // Allow explicit `.tokens` dir used by some Tokens Studio setups.
          if (entry.name !== ".tokens") continue;
        }
        walk(path.join(dir, entry.name));
      } else if (entry.isFile()) {
        const full = path.join(dir, entry.name);
        if (entry.name.endsWith(".tokens.json")) found.push(full);
        else if (entry.name === "tokens.json" && (dir === rootDir || path.basename(dir) === ".tokens")) found.push(full);
      }
    }
  };
  walk(rootDir);
  return found.sort();
}

// Resolve DTCG aliases transitively. Supports both `{color.brand.primary}` and
// Tokens Studio legacy `$color.brand.primary`. Cycle detection throws loudly.
function resolveDtcgAliases(tree, filename) {
  const resolving = new Set();
  const lookup = (pathStr) => {
    const segs = pathStr.split(".");
    let node = tree;
    for (const s of segs) {
      if (node == null || typeof node !== "object") return undefined;
      node = node[s];
    }
    return node;
  };
  const resolveValue = (value, trail) => {
    if (typeof value !== "string") return value;
    const braceMatch = value.match(/^\{([^}]+)\}$/);
    const dollarMatch = value.match(/^\$([A-Za-z_][A-Za-z0-9_.-]*)$/);
    const aliasPath = braceMatch ? braceMatch[1] : dollarMatch ? dollarMatch[1] : null;
    if (!aliasPath) return value;
    if (trail.has(aliasPath)) {
      throw new Error(`DTCG alias cycle in ${filename}: ${[...trail, aliasPath].join(" -> ")}`);
    }
    const target = lookup(aliasPath);
    if (target == null) return value; // dangling alias: pass through raw
    const next = typeof target === "object" && target !== null && "$value" in target ? target.$value : target;
    return resolveValue(next, new Set([...trail, aliasPath]));
  };
  const walk = (node) => {
    if (node == null || typeof node !== "object") return node;
    if (Array.isArray(node)) return node.map(walk);
    if ("$value" in node) {
      const copy = { ...node };
      try {
        copy.$value = resolveValue(copy.$value, new Set());
      } catch (err) {
        // Cycles must fail loudly per requirements.
        throw err;
      }
      copy.$value = applyTokensStudioTransforms(copy.$value, node.$extensions, filename);
      return copy;
    }
    const result = {};
    for (const k of Object.keys(node)) result[k] = walk(node[k]);
    return result;
  };
  return walk(tree);
}

// Apply Tokens Studio `modify` transforms (lighten/darken/alpha). Anything
// unparseable emits a warning to stderr and passes through the raw $value.
function applyTokensStudioTransforms(value, extensions, filename) {
  const modify = extensions?.["studio.tokens"]?.modify;
  if (!modify || typeof value !== "string") return value;
  const { type, amount, space } = modify;
  const num = Number(amount);
  try {
    if (type === "alpha" && /^#([0-9a-f]{6})$/i.test(value) && Number.isFinite(num)) {
      const a = Math.round(Math.max(0, Math.min(1, num)) * 255).toString(16).padStart(2, "0");
      return value + a;
    }
    if ((type === "lighten" || type === "darken") && /^#([0-9a-f]{6})$/i.test(value) && Number.isFinite(num)) {
      const hex = value.slice(1);
      const rgb = [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16));
      const factor = type === "lighten" ? num : -num;
      const adjusted = rgb.map(c => Math.max(0, Math.min(255, Math.round(c + (factor * 255)))));
      return "#" + adjusted.map(c => c.toString(16).padStart(2, "0")).join("");
    }
    process.stderr.write(`[extract-tokens] warn: unsupported Tokens Studio modify(${type}, space=${space}) in ${filename}; passing through raw value\n`);
    return value;
  } catch {
    process.stderr.write(`[extract-tokens] warn: failed to apply Tokens Studio modify(${type}) in ${filename}; passing through raw value\n`);
    return value;
  }
}

// Flatten a resolved DTCG tree into `prefix.path = stringified $value` leaves.
function flattenDtcg(node, prefix, acc) {
  if (node == null) return;
  if (typeof node !== "object" || Array.isArray(node)) {
    acc[prefix] = Array.isArray(node) ? node.join(",") : String(node);
    return;
  }
  if ("$value" in node) {
    const v = node.$value;
    const t = node.$type;
    const key = t ? `${prefix}[${t}]` : prefix;
    acc[key] = typeof v === "object" ? JSON.stringify(v, Object.keys(v).sort()) : String(v);
    return;
  }
  for (const k of Object.keys(node).sort()) {
    if (k.startsWith("$")) continue; // $description / $extensions / $metadata
    flattenDtcg(node[k], `${prefix}.${k}`, acc);
  }
}
