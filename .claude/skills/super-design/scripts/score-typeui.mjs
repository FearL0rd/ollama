#!/usr/bin/env node
// score-typeui.mjs — rank typeui-* skills by fit against a site fingerprint.
//
// Usage:
//   node score-typeui.mjs <fingerprint.json> [--top 3]
//   node score-typeui.mjs --from-audit <audit-dir>         # derive fingerprint from sd-audit findings + DIS
//   node score-typeui.mjs --list                            # list available typeui skills with axes
//
// Fingerprint input (JSON):
//   { density: "low|medium|high", contrast: "low|medium|high",
//     geometry: "round|square|mixed", color: "muted|vibrant|bold",
//     typography: "neutral|expressive|display", motion: "static|subtle|dynamic",
//     audience: "enterprise|developer|consumer|creative" }
//
// Output (stdout): JSON { ranked: [{ name, fit, reasons, applies_tokens }] }

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const AXES = ['density', 'contrast', 'geometry', 'color', 'typography', 'motion', 'audience'];

// Static fingerprint matrix — derived from each typeui SKILL.md style foundations.
// Keep in sync with skills at ~/.claude/skills/typeui-*/SKILL.md. Expand via harvest-typeui.sh.
const TYPEUI = {
  ant: {
    density: 'high', contrast: 'medium', geometry: 'square',
    color: 'muted', typography: 'neutral', motion: 'static', audience: 'enterprise',
    tokens: { primary: '#1677ff', radius: 6, spacing: [4, 8, 12, 16, 24, 32] },
    summary: 'Structured, enterprise-focused design. Data-dense tables, forms.',
  },
  application: {
    density: 'medium', contrast: 'high', geometry: 'round',
    color: 'vibrant', typography: 'neutral', motion: 'subtle', audience: 'developer',
    tokens: { primary: '#9333ea', radius: 8, spacing: [4, 8, 12, 16, 24, 32] },
    summary: 'Vercel/GitHub purple aesthetic. Top-bar nav, card layouts.',
  },
  artistic: {
    density: 'low', contrast: 'high', geometry: 'mixed',
    color: 'bold', typography: 'expressive', motion: 'dynamic', audience: 'creative',
    tokens: { primary: '#000000', radius: 0, spacing: [8, 16, 24, 40, 64, 96] },
    summary: 'High-contrast, expressive. Creative typography, bold color.',
  },
  bento: {
    density: 'medium', contrast: 'medium', geometry: 'round',
    color: 'muted', typography: 'neutral', motion: 'subtle', audience: 'consumer',
    tokens: { primary: '#0ea5e9', radius: 16, spacing: [8, 16, 24, 32, 48, 64] },
    summary: 'Modular grid of card-blocks. Clear hierarchy, soft spacing.',
  },
  bold: {
    density: 'low', contrast: 'high', geometry: 'square',
    color: 'bold', typography: 'display', motion: 'dynamic', audience: 'consumer',
    tokens: { primary: '#111111', radius: 4, spacing: [8, 16, 24, 48, 80, 128] },
    summary: 'Strong visual presence. Heavyweight type, high-contrast.',
  },
  clean: {
    density: 'low', contrast: 'medium', geometry: 'round',
    color: 'muted', typography: 'neutral', motion: 'static', audience: 'consumer',
    tokens: { primary: '#18181b', radius: 8, spacing: [8, 16, 24, 32, 48, 72] },
    summary: 'Simplicity-focused. Whitespace, legible type, limited palette.',
  },
  dashboard: {
    density: 'high', contrast: 'high', geometry: 'round',
    color: 'vibrant', typography: 'neutral', motion: 'subtle', audience: 'developer',
    tokens: { primary: '#3b82f6', radius: 6, spacing: [4, 8, 12, 16, 24, 32] },
    summary: 'Dark cloud-platform. Modular grids, glass panels, data hierarchy.',
  },
  doodle: {
    density: 'low', contrast: 'medium', geometry: 'mixed',
    color: 'vibrant', typography: 'expressive', motion: 'dynamic', audience: 'creative',
    tokens: { primary: '#f59e0b', radius: 12, spacing: [8, 16, 24, 40, 64, 96] },
    summary: 'Hand-drawn, sketch-like. Doodles, handwritten fonts.',
  },
  dramatic: {
    density: 'low', contrast: 'high', geometry: 'mixed',
    color: 'bold', typography: 'display', motion: 'dynamic', audience: 'creative',
    tokens: { primary: '#dc2626', radius: 0, spacing: [16, 32, 48, 80, 128, 200] },
    summary: 'Theatrical. Bold layouts, immersive visuals, unconventional.',
  },
  enterprise: {
    density: 'high', contrast: 'high', geometry: 'square',
    color: 'muted', typography: 'neutral', motion: 'static', audience: 'enterprise',
    tokens: { primary: '#0f172a', radius: 4, spacing: [4, 8, 12, 16, 24, 32] },
    summary: 'Clean, high-contrast enterprise. Drag-drop, structured layouts.',
  },
  neobrutalism: {
    density: 'medium', contrast: 'high', geometry: 'square',
    color: 'bold', typography: 'display', motion: 'subtle', audience: 'creative',
    tokens: { primary: '#ffd700', radius: 0, spacing: [8, 16, 24, 32, 48, 64] },
    summary: 'Bold borders, vivid accents, raw high-contrast on warm surfaces.',
  },
  paper: {
    density: 'medium', contrast: 'medium', geometry: 'round',
    color: 'muted', typography: 'expressive', motion: 'static', audience: 'consumer',
    tokens: { primary: '#78350f', radius: 4, spacing: [8, 16, 24, 32, 48, 64] },
    summary: 'Paper-textured, print-inspired. Serif/sans, tactile.',
  },
};

// Axis weights — density/contrast/geometry dominate; audience is secondary.
const WEIGHTS = {
  density: 0.22, contrast: 0.18, geometry: 0.16, color: 0.14,
  typography: 0.12, motion: 0.10, audience: 0.08,
};

function matchScore(a, b) {
  if (a === b) return 1.0;
  const pairs = {
    'low|medium': 0.5, 'medium|high': 0.5,
    'muted|vibrant': 0.5, 'vibrant|bold': 0.5,
    'neutral|expressive': 0.5, 'expressive|display': 0.5,
    'static|subtle': 0.5, 'subtle|dynamic': 0.5,
    'round|mixed': 0.6, 'square|mixed': 0.6,
  };
  const key = [a, b].sort().join('|');
  return pairs[key] ?? 0;
}

function scoreFor(fp, typeui) {
  let total = 0;
  const reasons = [];
  for (const axis of AXES) {
    const fpv = fp[axis];
    const tuv = typeui[axis];
    if (!fpv || !tuv) continue;
    const s = matchScore(fpv, tuv);
    total += s * WEIGHTS[axis];
    if (s >= 0.5) reasons.push(`${axis}:${tuv}`);
  }
  return { fit: Math.round(total * 100) / 100, reasons };
}

function rank(fp, topN = 3) {
  const scored = Object.entries(TYPEUI).map(([name, tu]) => ({
    name: `typeui-${name}`,
    ...scoreFor(fp, tu),
    applies_tokens: tu.tokens,
    summary: tu.summary,
  }));
  scored.sort((a, b) => b.fit - a.fit);
  return scored.slice(0, topN);
}

// Derive fingerprint from sd-audit findings.json + design-intelligence.json.
function fingerprintFromAudit(auditDir) {
  const fp = {};
  const diPath = path.join(auditDir, 'design-intelligence.json');
  const fPath = path.join(auditDir, 'findings.json');
  if (!fs.existsSync(diPath)) {
    throw new Error(`design-intelligence.json not found in ${auditDir}`);
  }
  const di = JSON.parse(fs.readFileSync(diPath, 'utf8'));
  const findings = fs.existsSync(fPath) ? JSON.parse(fs.readFileSync(fPath, 'utf8')) : [];

  const scores = di.per_page?.[0]?.categories || di.categories || {};
  const s = (k) => scores[k]?.score ?? scores[k] ?? 5;

  // Density: C1 density + C11 information scent
  const densityScore = (s('C1') + s('C11')) / 2;
  fp.density = densityScore >= 7 ? 'high' : densityScore >= 4 ? 'medium' : 'low';

  // Contrast: C6 contrast (inverse — low craft = low contrast detected)
  fp.contrast = s('C6') >= 7 ? 'high' : s('C6') >= 4 ? 'medium' : 'low';

  // Geometry: C14 border-radius variance (heuristic)
  const radiusVar = di.summary?.radius_variance ?? 0;
  fp.geometry = radiusVar > 8 ? 'mixed' : radiusVar > 2 ? 'round' : 'square';

  // Color: C5 palette saturation
  const satScore = di.summary?.color_saturation ?? 0.5;
  fp.color = satScore > 0.7 ? 'bold' : satScore > 0.4 ? 'vibrant' : 'muted';

  // Typography: C7 type scale variance
  const typeVariance = di.summary?.type_variance ?? 0.5;
  fp.typography = typeVariance > 0.7 ? 'display' : typeVariance > 0.4 ? 'expressive' : 'neutral';

  // Motion: C13 motion/transitions
  fp.motion = s('C13') >= 7 ? 'dynamic' : s('C13') >= 4 ? 'subtle' : 'static';

  // Audience: inferred from findings categories — best-effort
  const mobileCount = findings.filter((f) => f.id?.startsWith('M')).length;
  const dataCount = findings.filter((f) => /table|dense|data/i.test(f.quote || '')).length;
  fp.audience = dataCount > mobileCount ? 'enterprise' : 'consumer';

  return fp;
}

function listSkills() {
  return Object.entries(TYPEUI).map(([name, tu]) => ({
    name: `typeui-${name}`,
    axes: AXES.reduce((o, a) => ({ ...o, [a]: tu[a] }), {}),
    summary: tu.summary,
  }));
}

// CLI
const args = process.argv.slice(2);
if (args.includes('--list')) {
  console.log(JSON.stringify(listSkills(), null, 2));
  process.exit(0);
}

let fp;
let topN = 3;
const topIdx = args.indexOf('--top');
if (topIdx >= 0) topN = parseInt(args[topIdx + 1], 10) || 3;

const fromAuditIdx = args.indexOf('--from-audit');
if (fromAuditIdx >= 0) {
  const dir = args[fromAuditIdx + 1];
  if (!dir) {
    console.error('--from-audit requires a directory path');
    process.exit(2);
  }
  fp = fingerprintFromAudit(dir);
} else if (args[0] && fs.existsSync(args[0])) {
  fp = JSON.parse(fs.readFileSync(args[0], 'utf8'));
} else {
  console.error('Usage: score-typeui.mjs <fingerprint.json> | --from-audit <dir> | --list');
  process.exit(2);
}

const ranked = rank(fp, topN);
console.log(JSON.stringify({ fingerprint: fp, ranked }, null, 2));
