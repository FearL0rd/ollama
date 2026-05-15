# Change-detection playbook for the super-design skill

**Purpose.** This reference lets a Claude instance execute the full re-audit flow of the `super-design` skill from this document alone. It specifies how to detect whether an audit has run before, how to compute exactly what changed since the last audit, how to scope the incremental re-audit, and how to persist state robustly. Every command, library option, and threshold cited here is traceable to a primary source listed inline.

The skill's contract: on first invocation, produce `/docs/super-design/overview.md` plus a full findings set. On every subsequent invocation, read prior state, compute the delta, and re-audit only the impacted surface — falling back to a full audit only when the delta cannot be bounded (token change, theory-doc change, corrupt state, staleness threshold, or explicit user override).

---

## 1. Detecting whether an audit has run before

The skill's entry check is cheap: **stat the state file, then validate it**. Two files carry authority together — never just one.

```
/docs/super-design/overview.md         # human-readable output
/docs/super-design/.audit-state.json   # machine-readable state (committed)
```

**Presence logic.**

```bash
OVERVIEW="docs/super-design/overview.md"
STATE="docs/super-design/.audit-state.json"

if [[ ! -f "$STATE" ]]; then
  MODE="first-audit"          # no prior state at all
elif [[ ! -f "$OVERVIEW" ]]; then
  MODE="regenerate-overview"  # state exists but report was deleted; rebuild from findings/
else
  MODE="incremental-candidate"
fi
```

**Reading audit metadata.** The state file carries `last_audit_at`, `git_sha_at_audit`, `skill_version`, `theory_doc_sha`, tool versions, per-page hashes, and finding counts. Parse defensively: a single unreadable field must not abort the skill.

```ts
import { z } from "zod";

const StateSchema = z.object({
  schema_version: z.string(),
  last_audit_at: z.string().datetime(),
  git_sha_at_audit: z.string().regex(/^[0-9a-f]{7,64}$/),
  git_branch: z.string().optional(),
  skill_version: z.string(),
  theory_doc_sha: z.string(),
  tools: z.record(z.string()),
  pages_audited: z.array(z.object({
    url: z.string(),
    html_hash: z.string().optional(),
    dom_structure_hash: z.string().optional(),
    screenshot_hash: z.string().optional(),
    viewport_hashes: z.record(z.string()).optional(),
    last_audited: z.string().datetime(),
  })),
  components: z.record(z.string()).optional(), // path -> content hash
  route_map: z.array(z.string()).optional(),
  findings_counts: z.object({
    blockers: z.number(), high: z.number(),
    medium: z.number(), nitpicks: z.number(),
  }),
  research_at: z.string().datetime().optional(),
  market_analysis_sha: z.string().optional(),
});

function readState(path: string) {
  try {
    const raw = JSON.parse(fs.readFileSync(path, "utf8"));
    return { ok: true, state: StateSchema.parse(raw) };
  } catch (err) {
    return { ok: false, reason: err instanceof z.ZodError ? "schema" : "parse", err };
  }
}
```

**Graceful corruption handling.** If `readState` fails, log the reason, move the broken file to `.audit-state.json.corrupt-<timestamp>`, and fall through to `first-audit`. Never delete silently — the user should be able to inspect what went wrong.

**Invalidation criteria (any one triggers a full re-audit).**

| Condition | Check |
|---|---|
| **Tool major bump** (axe-core 4.x → 5.x, Lighthouse 13 → 14) | `semver.major(state.tools[name]) !== semver.major(current)` |
| **Theory doc updated** | `sha256(references/design-theory.md) !== state.theory_doc_sha` |
| **Staleness** | `Date.now() - Date.parse(state.last_audit_at) > 90 * 86400_000` |
| **Dependency major bump** | New major in `package.json` for React/Next/Tailwind/shadcn |
| **Skill schema bump** | `state.schema_version` older than current |
| **User override** | `--force-full` flag |

---

## 2. Using `git log` for change detection

The primary signal is a commit-range query bounded by `state.git_sha_at_audit..HEAD`. All syntax below is taken from the canonical Git docs at git-scm.com.

### 2.1 The core range query

```bash
git log "$LAST_SHA..HEAD" --name-only --pretty=format:"%H|%s|%an|%aI"
```

`A..B` expands to "reachable from B but not A". The `%H|%s|%an|%aI` placeholders are **commit hash | subject | author name | author date (strict ISO-8601)** — `%aI` (capital I) gives strict ISO-8601 which is unambiguous to parse; `%ai` gives the looser space-separated form. `format:` uses separator semantics; if you want a trailing newline per record, use `tformat:` or plain `--pretty=tformat:...` (unrecognized `%`-strings default to `tformat`). See https://git-scm.com/docs/pretty-formats.

Sample output (name-only appends files per commit, separated by a blank line):

```
a1b2c3d4...|Add login flow|Jane Doe|2026-04-18T14:22:11-07:00
src/auth/login.ts
src/auth/session.ts

9f8e7d6c...|Bump deps|Bot|2026-04-17T02:00:00+00:00
package.json
pnpm-lock.yaml
```

**For machine parsing prefer `-z` NUL-termination** (handles filenames with spaces/newlines per `core.quotePath`).

### 2.2 Magnitude quantification

```bash
git diff --shortstat "$LAST_SHA..HEAD"       # one summary line
git diff --stat      "$LAST_SHA..HEAD"       # per-file bars (human)
git diff --numstat   "$LAST_SHA..HEAD"       # per-file added\tdeleted\tpath (machine)
```

`--numstat` prints binary files as `-\t-\t<path>`; with `-z` it emits renames as `added\tdeleted\t\0oldpath\0newpath\0` (an **extra NUL before the preimage path** distinguishes the rename record without lookahead). See https://git-scm.com/docs/git-diff.

### 2.3 Filtering noise with pathspecs

`git log`/`git diff` accept negative pathspecs to exclude noise. The short form is `:!pattern` (or `:^`); the long form is `:(exclude)pattern`. Magic pathspecs live in `:(magic1,magic2,…)pattern` — most commonly `:(glob)` to make `**` meaningful and `*` not cross `/`, and `:(icase)` for case-insensitive matches. See https://git-scm.com/docs/gitglossary.

```bash
git log "$LAST_SHA..HEAD" \
  --name-only --pretty=format: \
  -- \
  ':(glob)**/*' \
  ':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml' ':!yarn.lock' \
  ':!.github/**' ':!**/*.test.*' ':!**/*.spec.*' \
  ':!**/__mocks__/**' ':!**/*.stories.*' \
  | sort -u
```

The `--` is **required** to separate pathspecs from rev args.

### 2.4 Design-relevance classifier

Classify each changed path into an impact bucket. This is the heart of the delta logic.

| Path pattern | Bucket | Consequence |
|---|---|---|
| `tailwind.config.*`, `**/*.tokens.json`, `styles/theme.css`, `styles/tokens.css`, `@theme` blocks in any CSS | `tokens` | Global — full re-audit |
| `components/**`, `src/components/**`, `app/_components/**` | `components` | Re-audit pages importing changed component (transitive closure) |
| `app/**/page.{tsx,jsx,ts,js,md,mdx}`, `pages/**/*.{tsx,...}`, `src/routes/**/+page.svelte`, `src/pages/**/*.astro`, `app/routes/**/*.tsx` | `routes` | Identify added/modified/deleted routes |
| `public/**`, `src/assets/**` (images, svgs, fonts) | `imagery` | Imagery audit only; no framework inspection |
| `package.json` (dependencies / devDependencies changed) | `deps` | Rerun Lighthouse + axe; check for framework major bump |
| `references/design-theory.md`, `references/market-analysis.md` (inside the skill) | `theory` | Invalidate prior heuristic findings |
| `*.md`, `*.mdx` outside `references/` | `content` | A11y + content checks only |
| `**/*.test.*`, `**/*.spec.*`, `.github/**`, `*.lock`, `**/*.md` in `node_modules` | `ignored` | Skip |

**New-files-only query** for route discovery:

```bash
git log --diff-filter=A --name-only --pretty=format: "$LAST_SHA..HEAD" | sort -u
```

Diff-filter letters: `A` added, `C` copied, `D` deleted, `M` modified, `R` renamed, `T` type-changed (file↔symlink↔submodule), `U` unmerged, `B` pairing broken. Lowercase excludes — `--diff-filter=d` means "everything except deletions." See https://git-scm.com/docs/diff-options.

### 2.5 Merges, cherry-picks, rebases, force-pushes

Trunk-based workflows with PR merges benefit from `--first-parent` to see one entry per merged PR rather than every topic-branch commit. Use `--no-merges` (equivalent to `--max-parents=1`) to exclude merge commits entirely.

**Cherry-picked commits** (backports inside the audit window) can double-count. Strip them with the patch-equivalence flags:

```bash
git log --no-merges --cherry-pick --right-only "$LAST_SHA...HEAD"
```

`A...B` (three dots) is symmetric difference; `--cherry-pick` omits commits that introduce the same change as one on the other side; `--right-only` keeps only the `HEAD` side. See https://git-scm.com/docs/git-log.

**Merge-commit diffs** default to **combined diff** (`--cc`), which **only lists files that differ from all parents**. A file changed on a topic branch but untouched during merge resolution may not appear. Either walk individual commits or use `--diff-merges=first-parent` / `-m`. See https://git-scm.com/docs/diff-format (combined format: `@@@ ... @@@` with `parents+1` `@` characters).

**Force-push / history rewrite survival.** The audit tool must never crash when `$LAST_SHA` is gone. The recovery ladder:

```bash
# 1. Does it exist locally?
git rev-parse --verify --quiet "$LAST_SHA^{commit}" >/dev/null || MISSING=1

# 2. Is it still an ancestor of HEAD?
git merge-base --is-ancestor "$LAST_SHA" HEAD
# exit 0 = ancestor; exit 1 = not ancestor; any other non-zero = error

# 3. If diverged but both exist, find the common base
git merge-base HEAD "$LAST_SHA"

# 4. Shallow clone? Can't see history.
SHALLOW=$(git rev-parse --is-shallow-repository)   # "true" | "false"
# Remedy: git fetch --unshallow

# 5. Last resort: time-based range
git log --since="$LAST_AUDIT_ISO" --name-only
```

Note that `git merge-base --is-ancestor` documents exit codes precisely: 0 ancestor, 1 not ancestor, **non-zero and not 1** on error (typically 128). See https://git-scm.com/docs/git-merge-base.

**Reflog is local-only.** `gc.reflogExpire` defaults to 90 days (reachable) / 30 days (unreachable). Fresh clones and CI runners have no reflog — do not rely on it for cross-machine recovery.

### 2.6 Rename detection

Git does not store renames; it infers them via similarity index. `git log --follow <path>` follows one file across renames but **accepts only a single pathname** — no globs, no directories (documented constraint in `git-log`). Prefer `git log --name-status -M` at the diff layer:

```bash
git diff --name-status -M90% "$LAST_SHA..HEAD"
# R100    old/util.ts      new/util.ts     ← exact rename, no content change
# R095    components/Button.tsx   ui/Button.tsx   ← 95% similar
# M       src/auth/login.ts
```

`-M90%` means "treat a delete/add pair as a rename when ≥90% of the file is unchanged." Default similarity is 50%. See https://git-scm.com/docs/diff-options.

### 2.7 Route discovery from filesystem

After pulling git-level changes, cross-reference with a fresh filesystem scan to find route files that exist today. Framework-specific conventions (all verified from official docs, April 2026):

| Framework | Root | Route-activating files | Dynamic | Excluded |
|---|---|---|---|---|
| Next.js App Router | `app/` or `src/app/` | `page.{js,jsx,ts,tsx}`, `route.{js,ts}` | `[id]`, `[...slug]`, `[[...slug]]` | `_folder/*`, `(group)` stripped, `@slot` parallel, `(.)`/`(..)`/`(...)` intercepting |
| Next.js Pages Router | `pages/` | any `.{js,jsx,ts,tsx,md,mdx}` | `[id].tsx`, `[...slug].tsx`, `[[...slug]].tsx` | `_app`, `_document`, `_error`, `404`, `500`, `api/**` |
| Remix / React Router v7 (fw) | `app/routes/` | flat: `posts.$postId.tsx`; folder: `folder/route.{ext}` | `$param`, `$` splat | `_index`, leading `_` pathless, `[brackets]` escapes |
| Astro | `src/pages/` | `.astro`, `.md`, `.mdx`, `.html`, `.js`, `.ts` | `[id].astro`, `[...slug].astro` | `_*` (private) |
| Nuxt 3/4 | `pages/` or `app/pages/` | `.vue`, `.{j,t}sx?` | `[id].vue`, `[...slug].vue`, `[[id]].vue` | `-prefixed` ignored |
| SvelteKit | `src/routes/` | `+page.svelte`, `+layout.svelte`, `+server.{js,ts}`, `+error.svelte` | `[id]`, `[[id]]`, `[...rest]`, `[p=matcher]` | non-`+` files; `(group)` stripped |
| SolidStart | `src/routes/` | `.{ts,tsx,js,jsx,md,mdx}` | `[id].tsx`, `[...slug].tsx` | `(group)` folders |
| Gatsby | `src/pages/` + `createPages` | `.{js,jsx,ts,tsx,md,mdx}` | `[id].js`, `[...].js` | `_*`, `api/*` functions |
| React Router library | none | `createBrowserRouter`, `<Route path>` | `:param`, `*` | AST required |
| Vue Router library | none | `createRouter({routes})` | `:param`, `:param?`, `:param*` | AST required; `unplugin-vue-router` adds fs |
| Angular | none | `Routes[]` / `provideRouter` / `RouterModule.forRoot` | `:param`, `**` | AST required |

**Framework detection heuristic (check in order):**

```bash
[[ -f next.config.js || -f next.config.ts || -f next.config.mjs ]] && FRAMEWORK=next
[[ -d app/routes && -f remix.config.js ]] && FRAMEWORK=remix
[[ -f svelte.config.js && -d src/routes ]] && FRAMEWORK=sveltekit
[[ -f astro.config.mjs && -d src/pages ]] && FRAMEWORK=astro
[[ -f nuxt.config.ts || -f nuxt.config.js ]] && FRAMEWORK=nuxt
[[ -f app.config.ts && -d src/routes ]] && FRAMEWORK=solid-start
[[ -f gatsby-config.js || -f gatsby-config.ts ]] && FRAMEWORK=gatsby
[[ -f angular.json ]] && FRAMEWORK=angular
```

For Next.js, distinguish App vs Pages by which of `app/` and `pages/` contains a `page` or route file; both can coexist during migration — treat the union.

**Dynamic routes get a representative instance.** For `[id]`, `[...slug]`, `:postId`, etc., don't try to enumerate — pick one canonical fixture (from fixtures file, test data, or the first seed value in `getStaticPaths`) and audit that. Record in state as `"/posts/[id]@example-123"` so the next audit re-uses the same instance.

---

## 3. Page-level change detection via content hashing

Three complementary signals; use all three for rich "what kind of change" semantics.

### 3.1 HTML content hashing

SHA-256 of the page's fully-rendered HTML after network idle. Fastest, crudest signal; any whitespace or inline-script nonce changes it.

```ts
import { createHash } from "node:crypto";

async function htmlHash(page) {
  await page.goto(url, { waitUntil: "networkidle" });
  const html = await page.content();
  const normalized = html.replace(/\s+/g, " ").trim();
  return createHash("sha256").update(normalized).digest("hex");
}
```

**When to use.** Cheap first pass. If HTML hash is unchanged, pixel hash is almost certainly unchanged too — skip screenshot.
**False positives.** Nonces, timestamps, CSRF tokens, SSR hydration markers, Next.js `__NEXT_DATA__` with dynamic data. Strip these before hashing.
**False negatives.** CSS-only changes that don't touch HTML (global token tweak). That's why HTML hashing alone is insufficient.

### 3.2 DOM structure hashing

Walk the DOM, emit a canonical `tag[sortedAttrs]` tree, **strip text content and volatile attributes**, then hash. Captures layout/structure changes while being robust to copy edits.

```ts
async function domStructureHash(page) {
  const serialized = await page.evaluate(() => {
    const VOLATILE = new Set([
      "nonce", "data-timestamp", "data-reactid",
      "data-react-hydration", "data-next-hydrate"
    ]);
    function walk(node) {
      if (node.nodeType !== Node.ELEMENT_NODE) return "";
      const attrs = [...node.attributes]
        .filter(a => !VOLATILE.has(a.name))
        .map(a => `${a.name}=${a.value}`)
        .sort()
        .join(",");
      const children = [...node.childNodes].map(walk).join("");
      return `<${node.tagName.toLowerCase()}[${attrs}]${children}>`;
    }
    return walk(document.documentElement);
  });
  return createHash("sha256").update(serialized).digest("hex");
}
```

For fuzzy similarity use **SimHash** over attribute-token shingles and compare with Hamming distance (same thresholds as perceptual hashes: ≤5 very similar, ≤10 probably similar on 64-bit). Libraries worth knowing: `diff-dom` produces a structural JSON diff (useful as the "why did it change" companion to a hash mismatch), and `hast-util-hash` works well on the unified/rehype HAST tree.

### 3.3 Visual regression hashing

Pixel-level comparison of screenshots, or perceptual hashes (pHash/dHash) for robust "same-ish" detection.

**Pixel-exact with `pixelmatch`** (https://github.com/mapbox/pixelmatch). RGBA buffers in, diff buffer out, returns number of mismatched pixels. Default options per the README and `index.js`:

| Option | Default | Meaning |
|---|---|---|
| `threshold` | `0.1` | Per-pixel acceptance; squared YIQ distance ≤ `35215 * threshold²` passes |
| `includeAA` | `false` | Skip anti-aliased pixels (Vyšniauskas 2009 detector) |
| `alpha` | `0.1` | Blending for unchanged pixels in diff image |
| `aaColor` | `[255,255,0]` | Yellow marker for AA pixels |
| `diffColor` | `[255,0,0]` | Red marker for different pixels |
| `diffMask` | `false` | Transparent background instead of original |

```js
import { PNG } from "pngjs";
import pixelmatch from "pixelmatch";

const a = PNG.sync.read(fs.readFileSync("before.png"));
const b = PNG.sync.read(fs.readFileSync("after.png"));
const diff = new PNG({ width: a.width, height: a.height });
const n = pixelmatch(a.data, b.data, diff.data, a.width, a.height, { threshold: 0.1 });
```

The threshold is **perceptual**: pixelmatch converts color differences to YIQ color space (Kotsarenko & Ramos, 2010), and `maxDelta = 35215 * threshold * threshold` caps squared YIQ distance. 0.1 tolerates AA/compression noise; 0.2 (Playwright's default) absorbs more font noise.

**`odiff`** (https://github.com/dmtrKovalenko/odiff, v4.x, Zig + SIMD). Cross-format input, same YIQ semantics, **roughly 6× faster than pixelmatch** on author-run benchmarks — useful when hashing dozens of pages. CLI and Node API:

```bash
odiff before.png after.png diff.png --threshold=0.1 --antialiasing --fail-on-layout
```

```js
const { compare } = require("odiff-bin");
const { match, diffPercentage, diffCount, reason } = await compare(
  "a.png", "b.png", "diff.png",
  { threshold: 0.1, antialiasing: true, failOnLayoutDiff: false }
);
```

**`resemble.js`** (https://github.com/rsmbl/Resemble.js). Returns a percentage (`misMatchPercentage`), ships richer output styles (`errorType: 'movement'`), and supports `.ignoreAntialiasing()`, `.ignoreColors()`, rectangle masks. **Watch-out**: `outputSettings.largeImageThreshold` defaults to `1200` and **silently downsamples** images larger than that — set to `0` for faithful full-res comparison.

**`looks-same`** (https://github.com/gemini-testing/looks-same). Uses **CIEDE2000** perceptual color difference rather than YIQ, default `tolerance: 2.3` ΔE, `ignoreAntialiasing: true` and `ignoreCaret: true` by default. Best when text-heavy screenshots produce YIQ false positives.

**`BackstopJS`** wraps Resemble with a scenario/reference/test/approve workflow and ships an official Docker image for font consistency. Default `misMatchThreshold: 0.1` (0.1% of pixels).

**Percy** is conceptually different: SDKs capture a **serialized DOM + asset bundle** in your test browser, Percy's cloud re-renders server-side with JS disabled and performs deterministic pixel diffing. Trade-off: no local baseline store in the repo; requires network; auto-handles AA/font noise via their Visual Engine.

**Perceptual hashing (pHash/dHash/aHash).** Use when pixel-exact is too brittle and you want "same-looking" semantics. The foundational reference is Zauner's thesis *Implementation and Benchmarking of Perceptual Image Hash Functions* (2010), available at https://www.phash.org/docs/pubs/thesis_zauner.pdf — DCT-based pHash computes the low-frequency 8×8 DCT coefficients of a 32×32 grayscale downsample and takes a median-threshold bit vector. Neal Krawetz introduced aHash in "Looks Like It" (http://www.hackerfactor.com/blog/?/archives/432-Looks-Like-It.html) and dHash in "Kind of Like That" (http://www.hackerfactor.com/blog/?/archives/529-Kind-of-Like-That.html). **Hamming distance heuristics on 64-bit hashes**: 0 identical, ≤5 near-duplicate, ≤10 probably similar, >10 likely different. Production systems often tighten to ≤2 at scale. Node libraries: `sharp-phash`, `imghash`, `blockhash-core`, `sharp-blockhash`.

### 3.4 Playwright screenshot API — the capture end

Key options (https://playwright.dev/docs/api/class-page, https://playwright.dev/docs/api/class-pageassertions):

```ts
await page.screenshot({
  path: "home.png",
  fullPage: true,
  animations: "disabled",   // fast-forwards finite CSS animations, freezes infinite
  caret: "hide",
  mask: [                   // solid-fill (default #FF00FF) overlay; covers dynamic content
    page.locator(".date"),
    page.locator("[data-dynamic]"),
    page.locator(".ad-banner"),
  ],
  maskColor: "#000000",
  scale: "css",             // one-pixel-per-CSS-pixel; "device" uses DPR
  style: "* { caret-color: transparent !important; }",
});
```

At the **context** level set `reducedMotion: "reduce"` and a fixed `viewport` and `deviceScaleFactor` so screenshots are reproducible. Playwright's built-in `expect(page).toHaveScreenshot()` assertion defaults to `threshold: 0.2` (per-pixel YIQ), `animations: "disabled"`, `caret: "hide"`, and exposes `maxDiffPixels` and `maxDiffPixelRatio`. Baselines are stored per-platform+browser (`hero-chromium-linux.png`) — **don't cross-compare Linux ↔ macOS bitmaps**.

### 3.5 Threshold tuning and dynamic masking

Why **~1% pixel threshold** is the common floor: for a 1280×800 screenshot (1,024,000 px), 1% = 10,240 px, enough headroom for anti-aliasing and sub-pixel text positioning while still catching a moved button or swapped icon.

Font rendering diverges substantially across platforms: Windows uses DirectWrite + ClearType subpixel RGB; macOS uses Core Text grayscale (no subpixel since Mojave); Linux depends on fontconfig and the `--font-render-hinting=none|medium|full` Chromium flag (see cypress-io/cypress#2920). Even within Linux, Debian vs Alpine and glibc vs musl shift glyph advance widths by 1–2 px. **Mitigations**: always baseline in CI (not locally), pin a Docker image (`mcr.microsoft.com/playwright:v1.x.y-jammy` or `backstopjs/backstopjs:<version>`), install a fixed font set (`fonts-liberation`, `fonts-noto`, `fonts-noto-color-emoji`), launch Chromium with `--font-render-hinting=none`, and set `reducedMotion: "reduce"` plus `animations: "disabled"`.

Mask dynamic regions via Playwright locators (preferred) or with `page.addStyleTag({ content: ".timestamp, .avatar { visibility: hidden }" })` injected before snapshot. Standard candidates: timestamps, avatars, A/B variant banners, third-party ads/chat widgets, CSRF-bearing nonce blocks.

---

## 4. Incremental audit scope decision tree

Given the change categories from §2.4 and hashes from §3, decide the scope. Implemented as a cascading decision — the first match wins, highest-impact first.

```
                  ┌─────────────────────────────────────┐
                  │ Did theory_doc_sha change?          │ ─ YES → FULL (reset heuristic findings)
                  └──────────────┬──────────────────────┘
                                 NO
                  ┌──────────────▼──────────────────────┐
                  │ Did any token source change?        │
                  │ (tailwind.config.*, @theme blocks,  │ ─ YES → FULL (tokens are global)
                  │  *.tokens.json, :root --*)          │
                  └──────────────┬──────────────────────┘
                                 NO
                  ┌──────────────▼──────────────────────┐
                  │ Did package.json majors change?     │
                  │ (react/next/tailwind/shadcn/...)    │ ─ YES → FULL + bump tool cache
                  └──────────────┬──────────────────────┘
                                 NO
                  ┌──────────────▼──────────────────────┐
                  │ Did skill_version major change?     │ ─ YES → FULL
                  └──────────────┬──────────────────────┘
                                 NO
                  ┌──────────────▼──────────────────────┐
                  │ Is last_audit_at > 90 days old?     │ ─ YES → FULL (freshness)
                  └──────────────┬──────────────────────┘
                                 NO
                  ┌──────────────▼──────────────────────┐
                  │ Did any components change?          │
                  │ → build importer closure (§8)       │ ─ YES → PARTIAL: {impacted pages}
                  └──────────────┬──────────────────────┘
                  ┌──────────────▼──────────────────────┐
                  │ New route files detected?           │ ─ YES → PARTIAL: {new routes only} (append)
                  └──────────────┬──────────────────────┘
                  ┌──────────────▼──────────────────────┐
                  │ Deleted route files?                │ ─ YES → remove from state, mark findings RESOLVED
                  └──────────────┬──────────────────────┘
                  ┌──────────────▼──────────────────────┐
                  │ Dependency non-major bump?          │ ─ YES → PARTIAL: rerun Lighthouse+axe only
                  └──────────────┬──────────────────────┘
                  ┌──────────────▼──────────────────────┐
                  │ Content-only (.md/mdx, text copy)?  │ ─ YES → PARTIAL: a11y + content checks only
                  └──────────────┬──────────────────────┘
                  ┌──────────────▼──────────────────────┐
                  │ Public images/fonts changed?        │ ─ YES → PARTIAL: imagery audit on touched pages
                  └──────────────┬──────────────────────┘
                                 NO
                            ┌────▼────────────┐
                            │ No audit needed │
                            │ Exit with note. │
                            └─────────────────┘
```

Scope buckets unify as a **set-valued output**: `{ "pages": Set<url>, "agents": Set<"research"|"a11y"|"perf"|"imagery"|"heuristic"> }`. Research agent reruns if `research_at` > 90 days OR `market_analysis.md` changed OR deps changed.

---

## 5. State file schema

The canonical schema lives at `/docs/super-design/.audit-state.json`. **Commit it.** It is small, human-inspectable, merge-friendly JSON, and future skill invocations — including from fresh clones or different machines — need it.

```jsonc
{
  "schema_version": "1.0.0",
  "skill_version": "0.3.1",
  "last_audit_at": "2026-04-19T14:22:11Z",
  "git_sha_at_audit": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
  "git_branch": "main",
  "is_shallow_clone": false,

  "theory_doc_sha":       "sha256:f2a7...",
  "market_analysis_sha":  "sha256:8c91...",

  "tools": {
    "axe-core":         "4.11.2",
    "lighthouse":       "13.1.0",
    "playwright":       "1.59.1",
    "playwright-mcp":   "0.0.70",
    "pa11y":            "9.0.0"
  },

  "framework": {
    "name": "next",
    "router": "app",
    "version": "15.2.0"
  },

  "route_map": [
    "/",
    "/about",
    "/posts/[id]@fixture-123",
    "/dashboard",
    "/dashboard/settings"
  ],

  "pages_audited": [
    {
      "url": "/",
      "route_file": "app/page.tsx",
      "html_hash":           "sha256:b1c2...",
      "dom_structure_hash":  "sha256:4d5e...",
      "viewport_hashes": {
        "mobile_375":  "phash:f884c4d8d1193c07",
        "tablet_768":  "phash:f884c4d8d1193c07",
        "desktop_1280":"phash:e774c4d8d1193c07"
      },
      "last_audited": "2026-04-19T14:22:11Z",
      "findings_ids": ["F-001", "F-014", "F-022"]
    }
  ],

  "components": {
    "src/components/ui/Button.tsx":  "xxh3:8f2a1c...",
    "src/components/ui/Card.tsx":    "xxh3:4b1e9d..."
  },

  "import_graph_sha": "sha256:9a8b...",

  "findings_counts": {
    "blockers": 2, "high": 7, "medium": 15, "nitpicks": 22
  },

  "research_at": "2026-04-01T10:00:00Z",

  "ignored_paths": [
    "*.lock", "package-lock.json", ".github/**", "**/*.test.*"
  ]
}
```

**Tradeoffs vs alternative schemas.**

- **Monolithic JSON (recommended above)** — single source of truth, easy git diff review, trivial to parse. Scales poorly past ~2,000 pages per app.
- **Frontmatter inside `overview.md`** — delightful colocation but YAML frontmatter fights with prose; nested fields get ugly; cannot be validated with JSON Schema tooling easily. **Reject.**
- **Directory of per-page JSON** (`pages/home.json`, `pages/dashboard.json`) — scales to huge sites; enables per-page ownership; adds filesystem walk overhead each run. **Use when `pages_audited.length > 500`.**
- **SQLite / DuckDB file** — best for very large sites with history (per-audit snapshots). Overkill for a first-release skill; consider only if history queries become common.
- **Git notes** (see §6) — survives clones if pushed, but invisible by default and conflicts are painful. Use as a **redundant anchor**, not primary storage.

**Schema evolution.** Bump `schema_version` major on breaking change; skill must read older versions (at least previous major) and either migrate in place or force a full re-audit with a clear note in `overview.md`.

---

## 6. GitHub / Git integration patterns

**Merge base recovery.** Always resolve the effective range start:

```bash
resolve_range_start() {
  local last="$1"
  if ! git rev-parse --verify --quiet "${last}^{commit}" >/dev/null; then
    echo "__MISSING__"; return
  fi
  if git merge-base --is-ancestor "$last" HEAD; then
    echo "$last"
  else
    git merge-base HEAD "$last" 2>/dev/null || echo "__UNRELATED__"
  fi
}
```

**`__MISSING__` fallback ladder** (try in order, stop at first success):

1. `git fetch --unshallow` if `is-shallow-repository` is true.
2. Check local reflog for the SHA: `git reflog | grep -F "$last"` (local-only; often empty on CI).
3. Fetch tags/notes from origin: `git fetch origin 'refs/notes/*:refs/notes/*'` — a prior `super-design` note anchored on that commit might still be retrievable.
4. Fall back to `--since=$last_audit_at` range and warn the user that the anchor was lost.
5. If all fail, treat as first audit; write a changelog note explaining why.

**`git notes` as redundant state anchor.** Notes are object-attached metadata on a specific commit; they survive force-pushes of branch refs because they're keyed by commit SHA, not ref name. Used correctly they let a fresh clone recover the audit history without the committed `.audit-state.json`.

```bash
# Write on every successful audit — idempotent overwrite
git notes --ref=super-design add -f -m "$(jq -c '{audited_at, schema_version, sha: .git_sha_at_audit}' \
  docs/super-design/.audit-state.json)" HEAD

# Push with the notes refspec
git push origin refs/notes/super-design

# Persist auto-fetch of notes for this clone
git config --add remote.origin.fetch '+refs/notes/super-design:refs/notes/super-design'
```

Default ref is `refs/notes/commits`; a custom ref (`refs/notes/super-design`) avoids colliding with other tools. **Limitations**: notes are not fetched or pushed by default, conflicts happen when two branches add notes to the same commit (strategies: `manual`, `ours`, `theirs`, `union`, `cat_sort_uniq`), and if the underlying commit is rewritten the note becomes orphaned. See https://git-scm.com/docs/git-notes.

**Cross-clone state — commit vs gitignore policy.**

| Artifact | Recommended location | Why |
|---|---|---|
| `docs/super-design/overview.md` | **Committed** | It's the audit report; users read this in PRs |
| `docs/super-design/.audit-state.json` | **Committed** | Needed to detect deltas on teammate machines / CI |
| `docs/super-design/findings/*.md` | **Committed** | Per-issue durable record; enables `PERSISTED`/`RESOLVED` tracking |
| `docs/super-design/baseline-screenshots/*.png` | Committed, **Git LFS** | Needed for visual regression continuity |
| `docs/super-design/.cache/screenshots/*.png` (per-run captures) | **.gitignored** | Ephemeral; regeneratable |
| `docs/super-design/.cache/scratch/*` (agent scratch pads) | **.gitignored** | Ephemeral |
| `docs/super-design/.cache/lighthouse/*.json` | **.gitignored** (optional commit on CI) | Large and re-runnable |

Add to `.gitignore`:

```
docs/super-design/.cache/
docs/super-design/baseline-screenshots/*.png.diff
```

---

## 7. Detecting new vs modified vs deleted routes

The state stores `route_map: string[]`. On each run: rescan the filesystem per §2.7, then diff against the stored map.

```ts
const prev = new Set(state.route_map);
const curr = new Set(await discoverRoutes(framework));

const added    = [...curr].filter(r => !prev.has(r));
const removed  = [...prev].filter(r => !curr.has(r));
const kept     = [...curr].filter(r =>  prev.has(r));

// Modified: kept AND the route source file appears in git diff
const changedSources = new Set(
  execSync(`git diff --name-only ${lastSha}..HEAD`).toString().split("\n")
);
const modified = kept.filter(r => changedSources.has(state.pages_audited.find(p => p.url === r)?.route_file));
```

**Dynamic routes.** Store with a `@<fixture>` suffix so identity is stable:

```
/posts/[id]@fixture-post-123
/users/[[...slug]]@fixture-users-alice
```

Pick the fixture deterministically: first key of `getStaticParams`/`generateStaticParams`, first row of a seeds file, or an environment-injected `SUPER_DESIGN_FIXTURES` JSON.

**Renames** (e.g., `pages/old.tsx` → `pages/new.tsx`) surface as `removed + added` unless `git diff -M90%` is used to detect a rename at the file layer. Prefer rename-aware diffs and treat `R100` renames as "no content change — only rename the URL key in state; keep hashes and findings."

**Router-convention migrations** (Pages → App, Remix v1 → v2, Nuxt 3 → 4) are special: the `route_map` shape changes entirely. Detect via `framework.router` mismatch in state vs current; when hit, reset `route_map` and force full re-audit with a "Migration detected" banner.

---

## 8. Component-level change detection

**Hash every component source file.** Glob `src/components/**/*.{tsx,jsx,vue,svelte,astro}` (add your project's variants), hash each with a line-ending-normalized xxh3:

```ts
import { xxh3 } from "@node-rs/xxhash";
import fg from "fast-glob";

const files = await fg([
  "src/components/**/*.{tsx,jsx,ts,js,vue,svelte,astro}",
  "components/**/*.{tsx,jsx,ts,js,vue,svelte,astro}",
  "app/_components/**/*.{tsx,jsx,ts,js}"
], { dot: false });

const components: Record<string, string> = {};
for (const f of files) {
  const raw = await fs.readFile(f, "utf8");
  const normalized = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  components[f] = "xxh3:" + xxh3.xxh128(Buffer.from(normalized)).toString(16);
}
```

**Line-ending normalization is mandatory** — CRLF vs LF on Windows/Unix produces spurious diffs. Stripping a trailing BOM and collapsing trailing whitespace makes the hash semantically stable.

**Diff against state.** `Object.entries(components)` vs `state.components` yields added / modified / deleted component paths.

**Reverse index — which pages import which components.** Build the import graph once per audit.

```bash
npx madge --json src/ > .cache/import-graph.json
```

`madge` supports JS/TS/JSX/TSX (and CSS preprocessors) out of the box and reads `.madgerc` or `package.json#madge` for `tsConfig`, `webpackConfig`, `detectiveOptions`. Output is `{ "file.tsx": ["dep1.tsx", "dep2.tsx"], ... }`. See https://github.com/pahen/madge.

For higher throughput on large monorepos use `oxc-parser` (Rust, ESTree-compatible, 50–100× faster than Babel — https://oxc.rs/docs/guide/usage/parser.html) or `es-module-lexer` (WASM, import-positions only — https://github.com/guybedford/es-module-lexer) as the scanner backend. When you need JSX/type-info richness (Angular `Routes[]`, `<Route>` JSX extraction), fall back to `@babel/parser` or `@typescript-eslint/parser`.

**Propagation.** Build the importer closure up to N hops (default N=3 — stops runaway fanout on utility-component changes, covers 99% of real page impact):

```ts
function importersOf(graph: Record<string, string[]>, file: string): Set<string> {
  const reverse: Record<string, string[]> = {};
  for (const [src, deps] of Object.entries(graph))
    for (const d of deps) (reverse[d] ||= []).push(src);

  const out = new Set<string>();
  const queue = [file];
  let depth = 0;
  while (queue.length && depth < 3) {
    const next: string[] = [];
    for (const f of queue)
      for (const imp of (reverse[f] || []))
        if (!out.has(imp)) { out.add(imp); next.push(imp); }
    queue.length = 0; queue.push(...next); depth++;
  }
  return out;
}

// Pages impacted by a changed component are importers that are route files
const pageImportersOf = (file: string) =>
  [...importersOf(graph, file)].filter(f => isRouteFile(f, framework));
```

If a component is imported by `layout.tsx`, the closure includes every child page — which is correct, and precisely why layout changes feel "global."

---

## 9. Design token change detection

Tokens are global state: a single color or spacing change re-skins every page. Any token mutation is a full re-audit trigger.

### 9.1 Token sources to monitor

| Source | Location | Parser |
|---|---|---|
| Tailwind v3 config | `tailwind.config.{js,ts,mjs,cjs}` | `ts-morph` + `resolveConfig` |
| Tailwind v4 `@theme` | any CSS imported by `styles/globals.css` | PostCSS `walkAtRules('theme')` |
| CSS custom properties | any `:root`, `@layer base`, `[data-theme]` block | PostCSS `walkRules(':root')` |
| DTCG JSON | `**/*.tokens.json`, `**/*.tokens` | `JSON.parse` |
| Style Dictionary | `tokens/**/*.json` (user-configured) | `JSON.parse` + resolve aliases |
| Tokens Studio export | whatever path is configured in `$themes.json` | `JSON.parse` (DTCG-like with extensions) |

### 9.2 Parse → canonicalize → hash

Goal: identical semantic tokens produce identical hashes regardless of formatting, key order, or comments.

**Tailwind v3** — parse AST, resolve, hash:

```ts
import resolveConfig from "tailwindcss/resolveConfig";
import cfg from "../tailwind.config.js";

const resolved = resolveConfig(cfg as any);
const canonical = JSON.stringify(resolved.theme, Object.keys(resolved.theme).sort());
const hash = createHash("sha256").update(canonical).digest("hex");
```

Use `ts-morph` if you want to **avoid executing** the config (side effects from plugins). See https://ts-morph.com — walk the default export's object literal, extract `theme`/`theme.extend`, recursively sort keys, stringify, hash.

**Tailwind v4 and plain CSS custom properties** — PostCSS sweep, one parser handles both:

```ts
import postcss from "postcss";

function extractCssTokens(cssSource: string) {
  const root = postcss.parse(cssSource);
  const tokens: Record<string, string> = {};

  root.walkRules(":root", rule => {
    rule.walkDecls(/^--/, d => { tokens[d.prop] = d.value.trim(); });
  });
  root.walkAtRules("theme", at => {
    at.walkDecls(/^--/, d => { tokens[d.prop] = d.value.trim(); });
  });
  return tokens;
}
```

**DTCG tokens** — the spec (https://tr.designtokens.org/format/) defines `$value`, `$type` on leaves and supports alias references as `"{color.primary}"`. Resolve aliases before hashing so an alias graph reshuffle doesn't change the hash if the final values match:

```ts
function resolveAliases(tokens: any, root = tokens): any {
  return JSON.parse(JSON.stringify(tokens, (_, v) => {
    if (typeof v === "string" && /^\{[^}]+\}$/.test(v)) {
      const path = v.slice(1, -1).split(".");
      let node = root;
      for (const p of path) node = node?.[p];
      return node?.$value ?? v;
    }
    return v;
  }));
}
```

Token types per the current editors draft: `color`, `dimension`, `fontFamily`, `fontWeight`, `duration`, `cubicBezier`, `number`, and composite types `shadow`, `gradient`, `typography`, `strokeStyle`, `border`, `transition`.

### 9.3 Surfacing the specific change

A bare "tokens changed" verdict isn't enough for a good audit narrative. Diff the two token maps:

```ts
function diffTokens(before: Record<string, string>, after: Record<string, string>) {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const added:   string[] = [];
  const removed: string[] = [];
  const modified: Array<[string, string, string]> = [];
  for (const k of keys) {
    if (!(k in before)) added.push(k);
    else if (!(k in after)) removed.push(k);
    else if (before[k] !== after[k]) modified.push([k, before[k], after[k]]);
  }
  return { added, removed, modified };
}
```

The report's changelog section then says "**`--color-primary`** changed from `#0066ff` to `#6600ff`" rather than a meaningless "tailwind.config.ts was modified."

---

## 10. User-triggered full re-audit

The user's entry command supports explicit override:

```
/super-design                  # normal (incremental if state valid)
/super-design --force-full     # ignore state, full re-audit
/super-design --refresh-research  # partial: rerun only research agent
/super-design --scope=/posts/[id]  # manual scope override
/super-design --dry-run        # print what would be audited; write nothing
```

**Automatic full-audit triggers** (any one):

| Trigger | Source |
|---|---|
| State file missing or corrupt | §1 presence check |
| `schema_version` major older than current | Skill startup |
| `--force-full` passed | User flag |
| `theory_doc_sha` mismatch | §9.1 |
| `skill_version` major bump | Compare package.json vs state |
| `last_audit_at` > 180 days | Staleness override of the 90-day soft threshold |
| Framework migration detected | §7 |
| Token source changed | §9 |

At every full audit, the skill prepends a banner to `overview.md` explaining why: "Full re-audit triggered by: theory doc updated (sha f2a7 → 8c91)." This makes the behavior inspectable and builds user trust.

---

## 11. Reporting incremental audits

Transparency is the single most valuable UX property of this skill. Every `overview.md` rewrite leads with a delta summary.

**Top-of-file changelog section:**

```markdown
# Design audit overview

> **Incremental audit — 2026-04-19 14:22 UTC**
> Since last audit on 2026-04-01 (`a1b2c3d`):
> - 4 commits, 12 files changed
> - 2 components modified: `Button.tsx`, `Card.tsx`
> - 1 new route: `/dashboard/settings`
> - Tokens unchanged; research unchanged (refreshed 2026-04-01)
> - Re-audited: 3 pages (home, pricing, dashboard/settings)
> - Skipped: 17 pages (unchanged per HTML+DOM hashes)
```

**Per-finding provenance.** Every finding carries an explicit status tag:

```markdown
## F-014 · Insufficient color contrast on primary button · **PERSISTED** (since 2026-04-01)
## F-029 · Missing aria-label on icon button · **NEW** (this audit)
## F-022 · Layout shift on pricing table ~~**RESOLVED**~~ (since last audit — commit b8c4e2d)
```

Persistence model: each finding has a stable `id` (content-addressed hash of rule + selector + URL). On re-audit, the skill intersects the new findings set with the prior set:

- `new` = in current ∖ prior
- `persisted` = in current ∩ prior (preserve `first_seen_at`)
- `resolved` = in prior ∖ current (don't delete; move to "Resolved" section)

**Separate append-only history** at `/docs/super-design/audit-history.md`:

```markdown
## 2026-04-19 · a1b2c3d
- 2 components changed, 1 route added
- +2 blockers, -1 high, -3 nitpicks
- Full re-audit? No

## 2026-04-01 · 9f8e7d6
- Initial audit
- 2 blockers, 7 high, 15 medium, 22 nitpicks
- Full re-audit? Yes (first run)
```

---

## 12. Performance optimizations

**Skip the browser entirely when possible.** The single biggest speedup: if git diff shows zero design-relevant changes and token hashes match, don't launch Playwright at all. Report "No design-relevant changes since <date> (<sha>)" and exit in under a second.

**Use xxh3 for cache keys.** `@node-rs/xxhash` for native speed or `xxhash-wasm` for portable. 10–30× faster than SHA-256 for the per-file hashing loop (https://xxhash.com/). Reserve SHA-256 for cross-system integrity anchors (state file entries that are compared across machines) and use xxh3 for hot-path internal caches.

**Parallel hashing** with a bounded worker pool (`p-limit` or `Promise.all` with concurrency control — default concurrency = `os.cpus().length`). Component hashing a 500-file codebase drops from ~400 ms serial to ~50 ms at concurrency 8.

**Screenshot cache by hash.** Store screenshots under `.cache/screenshots/<sha256-of-url+viewport+dom_structure_hash>.png`. When the DOM structure hash matches the stored one, short-circuit capture and reuse the cached PNG.

**Lazy research.** Skip the research agent entirely when:
- `market-analysis.md` exists, and
- `package.json`, `README.md`, and `references/market-analysis.md` haven't changed since `research_at`, and
- `research_at` is within 90 days.

**`odiff` over `pixelmatch` for diff throughput.** Author-reported ~6× speedup on typical screenshots; important when diffing 20+ pages × 3 viewports = 60 comparisons per audit.

**Shallow-clone guardrail.** If `git rev-parse --is-shallow-repository` is `true`, skip long-history queries and fall back to filesystem-only hashes — don't spend two minutes fetching unshallowed history when you'll re-audit everything anyway.

---

## 13. Edge cases and failure modes

The skill must handle every row of this table gracefully.

| Edge case | Detection | Response |
|---|---|---|
| State exists, overview missing | fs stat | Rebuild overview from `findings/` using stored hashes; no re-audit |
| Overview exists, state corrupt | JSON parse / Zod validation fails | Rename to `.corrupt-<ts>`, do full audit, warn user |
| Git history rewritten, SHA gone | `git rev-parse --verify` fails | Recovery ladder §6; fall back to `--since=last_audit_at`, then full audit |
| Pages→App migration | `framework.router` changed; `app/page.tsx` exists and state says `pages` | Reset `route_map` + `pages_audited`, full audit, banner explains |
| Repo is shallow clone | `git rev-parse --is-shallow-repository` = true | Either `git fetch --unshallow` if CI permits, or force full audit with warning |
| No git at all | `git rev-parse --git-dir` exits non-zero | Fall back to filesystem mtime-based heuristic: re-audit files with `stat.mtime > state.last_audit_at` |
| Detached HEAD | `git symbolic-ref --quiet HEAD` exits 1 | Audit normally using commit SHA; leave `git_branch: null` in state |
| Empty repo (no commits) | `git rev-list -n1 --all` empty | Diff against empty tree SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` (SHA-1 repos); first audit |
| Fresh clone, no local screenshot cache | `.cache/screenshots/` absent | Regenerate screenshots only for pages whose hash changed or are new; old pages reuse `baseline-screenshots/` |
| Monorepo with multiple apps | Multiple `package.json` files with distinct `name` under `apps/*` or `packages/*` | **Prefer state per app**: `apps/web/docs/super-design/.audit-state.json`, `apps/admin/docs/super-design/.audit-state.json`. Unified state only if apps share tokens and components; in that case keep one state at root with an `apps: { "web": {...}, "admin": {...} }` sub-key |
| Very large route count (>500) | `route_map.length > 500` | Switch to directory-of-per-page-JSON schema (§5 alt); parallelize audits in batches |
| Race condition: state written during audit | N/A in a single-process skill, but a concurrent run could corrupt | Write-then-rename (atomic): `.audit-state.json.tmp` → `.audit-state.json` |
| Playwright fails to launch (no browsers) | Exception | `npx playwright install chromium`; if still failing, degrade to static audit (no screenshots, no Lighthouse) and flag in overview |
| Lighthouse tool version differs majorly from state | semver compare | Full re-audit; update `tools.lighthouse`; note in changelog |

---

## 14. Orchestrator entry flow pseudocode

```python
def super_design_entry(flags, cwd):
    skill = load_skill_metadata()
    state_path    = f"{cwd}/docs/super-design/.audit-state.json"
    overview_path = f"{cwd}/docs/super-design/overview.md"

    # ── 0. Preflight ───────────────────────────────────────────────
    has_git = run_ok("git rev-parse --git-dir")
    is_shallow = has_git and run("git rev-parse --is-shallow-repository") == "true"
    framework, router, fw_version = detect_framework(cwd)

    # ── 1. Presence and schema validation ─────────────────────────
    if flags.force_full or not exists(state_path):
        return full_audit(reason="missing-state" if not exists(state_path) else "--force-full")

    try:
        state = validate_state(read_json(state_path))
    except StateCorrupt as e:
        move(state_path, f"{state_path}.corrupt-{now_iso()}")
        log_warn(f"State file corrupt: {e}. Treating as first audit.")
        return full_audit(reason="corrupt-state")

    if semver_major(state.schema_version) < CURRENT_SCHEMA_MAJOR:
        return full_audit(reason="schema-bump")

    # ── 2. Invalidation checks (§1 + §10) ─────────────────────────
    now = utcnow()
    age_days = (now - parse_iso(state.last_audit_at)).days

    if age_days > 180:
        return full_audit(reason="stale-180-days")

    theory_sha_now = sha256_of("references/design-theory.md")
    if theory_sha_now != state.theory_doc_sha:
        return full_audit(reason="theory-doc-changed")

    current_tools = probe_tool_versions()   # axe-core, lighthouse, playwright
    if any(semver_major(current_tools[t]) != semver_major(state.tools.get(t, "0.0.0"))
           for t in current_tools):
        return full_audit(reason="tool-major-bump")

    if router != state.framework.router or framework != state.framework.name:
        return full_audit(reason="framework-migration",
                          note=f"{state.framework.name}/{state.framework.router} → {framework}/{router}")

    # ── 3. Git range resolution (§2, §6) ───────────────────────────
    last_sha = state.git_sha_at_audit
    range_start = resolve_range_start(last_sha)   # §6

    if range_start == "__MISSING__":
        if is_shallow and ci_allows_unshallow():
            run("git fetch --unshallow")
            range_start = resolve_range_start(last_sha)
        if range_start == "__MISSING__":
            since = state.last_audit_at
            commits = git_log_since(since)
            if not commits:
                return no_op(reason="no-commits-since-last-audit-by-time")
            log_warn(f"Lost anchor SHA {last_sha}; falling back to --since={since}")
            changed_files = git_diff_since_time(since)
        else:
            changed_files = git_diff_range(range_start)
    else:
        changed_files = git_diff_range(range_start)

    # ── 4. Classify changes (§2.4) ─────────────────────────────────
    changes = classify(changed_files)
    # {tokens, components, routes, imagery, deps, content, theory, ignored}

    # ── 5. Token diff — global signal (§9) ─────────────────────────
    token_hash_now = compute_token_hash(framework, cwd)
    token_hash_prev = state.get("token_hash")
    if token_hash_now != token_hash_prev:
        return full_audit(reason="tokens-changed",
                          token_diff=diff_tokens(load_tokens_prev(), load_tokens_now()))

    # ── 6. Dep major bump ──────────────────────────────────────────
    if any_major_dep_bump(changes.deps, state.framework):
        return full_audit(reason="framework-major-bump")

    # ── 7. Component hashing + import graph (§8) ───────────────────
    components_now = hash_components(cwd)
    component_diff = diff_maps(state.components or {}, components_now)
    import_graph = load_or_build_import_graph(cwd)

    impacted_pages = set()
    for ch in component_diff.modified + component_diff.removed + component_diff.added:
        impacted_pages |= page_importers_of(import_graph, ch, max_hops=3)

    # ── 8. Route diff (§7) ─────────────────────────────────────────
    route_map_now = discover_routes(framework, cwd)
    route_diff = diff_sets(set(state.route_map), set(route_map_now))
    impacted_pages |= set(route_diff.added)
    for url in route_diff.modified:
        impacted_pages.add(url)

    # ── 9. Content/imagery only changes ────────────────────────────
    impacted_pages |= pages_touched_by_content_files(changes.content, import_graph)
    impacted_pages |= pages_touched_by_imagery(changes.imagery)

    # ── 10. If nothing impacted, exit cleanly ──────────────────────
    if (not impacted_pages
        and not component_diff.any()
        and not route_diff.any()
        and not changes.deps
        and age_days <= 90):
        append_history(no_op=True, last_audit_at=state.last_audit_at)
        return no_op(reason="no-design-relevant-changes")

    # ── 11. Decide agent set ───────────────────────────────────────
    agents = set()
    if impacted_pages:
        agents.update({"a11y", "perf", "heuristic", "imagery"})
    if changes.deps:
        agents.update({"a11y", "perf"})
    research_stale = (age_days > 90 or
                      state.market_analysis_sha != sha256_of("references/market-analysis.md") or
                      flags.refresh_research)
    if research_stale:
        agents.add("research")

    # ── 12. Run incremental audit ──────────────────────────────────
    new_findings = incremental_audit(
        pages=impacted_pages,
        agents=agents,
        cache_dir=f"{cwd}/docs/super-design/.cache",
        prev_state=state
    )

    # ── 13. Merge findings with prior (§11 provenance) ─────────────
    merged = merge_findings(state_findings=load_findings(state),
                            new_findings=new_findings,
                            touched_pages=impacted_pages)

    # ── 14. Write outputs ──────────────────────────────────────────
    write_findings(merged)
    write_overview_with_changelog(
        impacted_pages=impacted_pages,
        component_diff=component_diff,
        route_diff=route_diff,
        token_diff=None,
        range_start=range_start,
        last_sha=last_sha
    )
    append_history(diff_summary=summary(impacted_pages, component_diff, route_diff))

    # ── 15. Persist new state atomically ───────────────────────────
    new_state = build_state(
        prev=state, framework=framework, router=router,
        components=components_now, route_map=route_map_now,
        pages=page_hashes_now, token_hash=token_hash_now,
        research_at=now if research_stale else state.research_at
    )
    atomic_write_json(state_path, new_state)

    # ── 16. Git notes anchor (§6) ──────────────────────────────────
    try:
        run(f'git notes --ref=super-design add -f -m {json_note(new_state)!r} HEAD')
    except Exception as e:
        log_warn(f"git notes write failed ({e}); continuing without notes anchor")

    return success(impacted_pages=impacted_pages, agents=agents)
```

Key error-handling properties: every `run(...)` is wrapped to surface non-zero exits; any unexpected failure **degrades** rather than crashes (e.g., if `madge` fails, skip component-impact propagation and audit every page as a conservative fallback); every full-audit path records its `reason` in the changelog so the user can see why.

---

## 15. Helper scripts

All scripts shipped at `skills/super-design/scripts/`. Use `set -euo pipefail` uniformly; trap ERR for friendly diagnostics.

### 15.1 `scripts/detect-changes.sh`

```bash
#!/usr/bin/env bash
# Usage: detect-changes.sh <last_sha> [<state_last_iso>]
# Emits JSON: { range_start, commits, changed_files: {tokens,components,routes,content,imagery,deps,ignored} }
set -euo pipefail

LAST_SHA="${1:-}"
LAST_ISO="${2:-}"

if [[ -z "$LAST_SHA" ]]; then
  echo '{"error":"missing last_sha"}'; exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"error":"not-a-git-repo"}'; exit 3
fi

# Resolve range start
if git rev-parse --verify --quiet "${LAST_SHA}^{commit}" >/dev/null; then
  if git merge-base --is-ancestor "$LAST_SHA" HEAD; then
    RANGE_START="$LAST_SHA"
  else
    RANGE_START="$(git merge-base HEAD "$LAST_SHA" 2>/dev/null || echo "")"
  fi
else
  RANGE_START=""
fi

if [[ -z "$RANGE_START" ]]; then
  if [[ -n "$LAST_ISO" ]]; then
    FILES="$(git log --since="$LAST_ISO" --name-only --pretty=format: 2>/dev/null | sort -u | sed '/^$/d' || true)"
    COMMITS="$(git log --since="$LAST_ISO" --pretty=format:'%H|%s|%an|%aI' 2>/dev/null || true)"
    MODE="since-time"
  else
    echo '{"error":"lost-anchor-no-fallback-time"}'; exit 4
  fi
else
  FILES="$(git diff --name-only "${RANGE_START}..HEAD" \
    -- ':!*.lock' ':!package-lock.json' ':!pnpm-lock.yaml' ':!yarn.lock' \
       ':!.github/**' ':!**/*.test.*' ':!**/*.spec.*' ':!**/*.stories.*' \
    | sort -u)"
  COMMITS="$(git log --no-merges --pretty=format:'%H|%s|%an|%aI' "${RANGE_START}..HEAD" 2>/dev/null || true)"
  MODE="sha-range"
fi

# Classify
classify() {
  local p="$1"
  case "$p" in
    tailwind.config.*|*.tokens.json|styles/tokens.css|styles/theme.css) echo tokens ;;
    components/*|src/components/*|app/_components/*)                     echo components ;;
    app/*/page.*|app/page.*|app/*/route.*|app/route.*|pages/*|src/pages/*|app/routes/*|src/routes/*) echo routes ;;
    public/*|src/assets/*|assets/*)                                      echo imagery ;;
    package.json)                                                        echo deps ;;
    references/design-theory.md|references/market-analysis.md)           echo theory ;;
    *.md|*.mdx)                                                          echo content ;;
    *)                                                                   echo other ;;
  esac
}

jq -Rn --arg mode "$MODE" --arg range_start "$RANGE_START" --arg last_iso "$LAST_ISO" \
  --argjson files "$(printf '%s\n' "$FILES" | jq -R . | jq -s .)" \
  --argjson commits "$(printf '%s\n' "$COMMITS" | jq -R . | jq -s .)" '
  {mode:$mode, range_start:$range_start, since_iso:$last_iso,
   commits:$commits, files:$files,
   classified: ($files | map({(.): "_"}) | add // {})
  }'
```

Example output (truncated):

```json
{
  "mode": "sha-range",
  "range_start": "a1b2c3d4...",
  "commits": ["9f8e7d6c...|Bump deps|Bot|2026-04-17T02:00:00+00:00", "..."],
  "files": ["src/components/ui/Button.tsx", "tailwind.config.ts", "app/about/page.tsx"]
}
```

### 15.2 `scripts/hash-pages.sh`

```bash
#!/usr/bin/env bash
# Usage: hash-pages.sh <urls_file>
# Reads one URL per line; uses Node + Playwright to capture HTML, DOM-structure, screenshot hashes.
set -euo pipefail

URLS="$1"
OUT_DIR="${OUT_DIR:-docs/super-design/.cache/hashes}"
mkdir -p "$OUT_DIR"

node --experimental-vm-modules <<'JS'
import { chromium } from "playwright";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const urls = readFileSync(process.env.URLS || process.argv[2], "utf8")
  .split("\n").map(s => s.trim()).filter(Boolean);

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 1280, height: 800 },
  reducedMotion: "reduce",
  deviceScaleFactor: 1,
});
const page = await ctx.newPage();
const sha = s => createHash("sha256").update(s).digest("hex");

const results = [];
for (const url of urls) {
  await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
  const html = (await page.content()).replace(/\s+/g, " ").trim();
  const dom = await page.evaluate(() => {
    const V = new Set(["nonce","data-timestamp","data-reactid"]);
    const walk = n => n.nodeType !== 1 ? "" :
      `<${n.tagName.toLowerCase()}[${
        [...n.attributes].filter(a=>!V.has(a.name))
          .map(a=>`${a.name}=${a.value}`).sort().join(",")
      }]${[...n.childNodes].map(walk).join("")}>`;
    return walk(document.documentElement);
  });
  const buf = await page.screenshot({ fullPage: true, animations: "disabled", caret: "hide" });
  results.push({
    url,
    html_hash: "sha256:" + sha(html),
    dom_structure_hash: "sha256:" + sha(dom),
    screenshot_hash: "sha256:" + sha(buf),
  });
}
writeFileSync(process.env.OUT_DIR + "/hashes.json", JSON.stringify(results, null, 2));
await browser.close();
JS
```

Example output file:

```json
[
  { "url":"/", "html_hash":"sha256:b1c2...", "dom_structure_hash":"sha256:4d5e...",
    "screenshot_hash":"sha256:77ab..." }
]
```

### 15.3 `scripts/diff-tokens.sh`

```bash
#!/usr/bin/env bash
# Usage: diff-tokens.sh <previous_tokens.json> <current_tokens.json>
# Emits a JSON diff: { added, removed, modified: [{key, before, after}] }
set -euo pipefail

PREV="$1"; CURR="$2"

jq -n --slurpfile a "$PREV" --slurpfile b "$CURR" '
  ($a[0]  // {}) as $before |
  ($b[0]  // {}) as $after  |
  {
    added:   [$after  | to_entries[] | select(.key as $k | ($before | has($k)) | not) | .key],
    removed: [$before | to_entries[] | select(.key as $k | ($after  | has($k)) | not) | .key],
    modified: [
      $after | to_entries[] |
      select(.key as $k | ($before | has($k)) and (.value != $before[$k])) |
      { key: .key, before: $before[.key], after: .value }
    ]
  }
'
```

Prior step: produce `previous_tokens.json` / `current_tokens.json` by invoking a Node script that walks `tailwind.config.*` via `ts-morph` + `resolveConfig` and `@theme` blocks via PostCSS (§9.2). Ship that as a companion `scripts/extract-tokens.mjs`.

### 15.4 `scripts/discover-routes.sh`

```bash
#!/usr/bin/env bash
# Usage: discover-routes.sh
# Prints a JSON array of detected route URLs based on framework conventions.
set -euo pipefail

detect_framework() {
  if   [[ -f next.config.js || -f next.config.ts || -f next.config.mjs ]]; then echo "next"
  elif [[ -f remix.config.js || -d app/routes ]]; then echo "remix"
  elif [[ -f svelte.config.js && -d src/routes ]]; then echo "sveltekit"
  elif [[ -f astro.config.mjs || -f astro.config.ts ]]; then echo "astro"
  elif [[ -f nuxt.config.ts || -f nuxt.config.js ]]; then echo "nuxt"
  elif [[ -f app.config.ts && -d src/routes ]]; then echo "solid-start"
  elif [[ -f gatsby-config.js || -f gatsby-config.ts ]]; then echo "gatsby"
  elif [[ -f angular.json ]]; then echo "angular"
  else echo "unknown"
  fi
}

FW="$(detect_framework)"
case "$FW" in
  next)
    # App router: folders containing page.{ext} or route.{ext}
    APP_ROUTES="$(find app src/app -type f \( -name 'page.tsx' -o -name 'page.ts' \
      -o -name 'page.jsx' -o -name 'page.js' -o -name 'page.md' -o -name 'page.mdx' \
      -o -name 'route.ts' -o -name 'route.js' \) 2>/dev/null \
      | sed -E 's|(^|/)(app|src/app)/||; s|/page\.[a-z]+$||; s|/route\.[a-z]+$||; s|^$|/|' \
      | sed -E 's|\([^)]+\)/||g; /(^|\/)_/d' \
      | sort -u || true)"
    # Pages router
    PG_ROUTES="$(find pages src/pages -type f \( -name '*.tsx' -o -name '*.ts' \
      -o -name '*.jsx' -o -name '*.js' -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | grep -vE '(^|/)(pages|src/pages)/(_app|_document|_error|404|500|api/)' \
      | sed -E 's|(^|/)(pages|src/pages)/||; s|\.(tsx|ts|jsx|js|md|mdx)$||; s|index$||' \
      | sort -u || true)"
    printf '%s\n%s\n' "$APP_ROUTES" "$PG_ROUTES" | awk 'NF' | jq -Rn '[inputs | sub("^"; "/")]' ;;

  sveltekit)
    find src/routes -type f -name '+page.svelte' 2>/dev/null \
      | sed -E 's|^src/routes||; s|/\+page\.svelte$||; s|\([^)]+\)/||g' \
      | awk 'NF==0 {print "/"; next} {print}' | sort -u | jq -Rn '[inputs]' ;;

  astro)
    find src/pages -type f \( -name '*.astro' -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | sed -E 's|^src/pages||; s|\.(astro|md|mdx)$||; s|/index$||' | sort -u | jq -Rn '[inputs]' ;;

  nuxt)
    find pages app/pages -type f -name '*.vue' 2>/dev/null \
      | sed -E 's|^(app/)?pages||; s|\.vue$||; s|/index$||' | sort -u | jq -Rn '[inputs]' ;;

  remix)
    find app/routes -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' \
      -o -name '*.md' -o -name '*.mdx' \) 2>/dev/null \
      | sed -E 's|^app/routes/||; s|\.(tsx|ts|jsx|js|md|mdx)$||; s|\.|/|g; s|_index$||; s|^_|/|; s|^|/|' \
      | sort -u | jq -Rn '[inputs]' ;;

  solid-start)
    find src/routes -type f \( -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' \) 2>/dev/null \
      | sed -E 's|^src/routes||; s|\.(tsx|ts|jsx|js)$||; s|/index$||; s|\([^)]+\)/||g' \
      | sort -u | jq -Rn '[inputs]' ;;

  *) echo '[]' ;;
esac
```

Example output for a Next.js App Router app:

```json
["/", "/about", "/posts/[id]", "/dashboard", "/dashboard/settings"]
```

### 15.5 `scripts/validate-state.sh`

```bash
#!/usr/bin/env bash
# Usage: validate-state.sh [path]
# Exits 0 if valid and fresh, 1 if stale, 2 if missing/corrupt.
set -euo pipefail

STATE="${1:-docs/super-design/.audit-state.json}"

if [[ ! -f "$STATE" ]]; then
  echo '{"status":"missing"}'; exit 2
fi

jq -e '
  (.schema_version | type == "string") and
  (.last_audit_at  | fromdateiso8601 | . > 0) and
  (.git_sha_at_audit | test("^[0-9a-f]{7,64}$")) and
  (.skill_version  | type == "string") and
  (.tools          | type == "object")
' "$STATE" >/dev/null 2>&1 || { echo '{"status":"corrupt"}'; exit 2; }

AGE_DAYS=$(( ( $(date -u +%s) - $(jq -r '.last_audit_at | fromdateiso8601' "$STATE") ) / 86400 ))
if   (( AGE_DAYS > 180 )); then echo "{\"status\":\"stale-force-full\",\"age_days\":$AGE_DAYS}"; exit 1
elif (( AGE_DAYS > 90  )); then echo "{\"status\":\"stale-refresh-research\",\"age_days\":$AGE_DAYS}"; exit 1
else echo "{\"status\":\"fresh\",\"age_days\":$AGE_DAYS}"; exit 0
fi
```

---

## 16. Bonus — visual regression integration

When the user opts in, super-design doubles as a visual regression tool. The baselines are committed under `docs/super-design/baseline-screenshots/` with Git LFS (PNGs are large, binary, and would bloat pack files). Config extends the state file:

```jsonc
{
  "visual_regression": {
    "enabled": true,
    "engine": "odiff",             // "pixelmatch" | "odiff" | "resemble" | "looks-same"
    "threshold": 0.1,               // per-pixel YIQ (pixelmatch/odiff) or ΔE (looks-same uses 2.3 default)
    "max_diff_pixel_ratio": 0.01,   // 1% of pixels allowed
    "antialiasing": true,
    "viewports": [
      { "label": "mobile",  "width": 375,  "height": 812 },
      { "label": "tablet",  "width": 768,  "height": 1024 },
      { "label": "desktop", "width": 1280, "height": 800 }
    ],
    "mask_selectors": [
      ".timestamp", "[data-dynamic]", ".avatar",
      ".ad-banner", "[data-testid=session-id]"
    ],
    "docker_image": "mcr.microsoft.com/playwright:v1.59.1-jammy"
  }
}
```

**Baseline workflow.**

1. `super-design --update-baselines` — capture new screenshots, save to `baseline-screenshots/<url>-<viewport>.png`, commit via LFS.
2. `super-design` — capture current screenshots to `.cache/screenshots/`, diff against baselines using the configured engine.
3. Findings with `visual-regression` rule ID list diffing pages with above-threshold pixel diffs; the diff PNG is stored at `.cache/screenshots/<url>-<viewport>.diff.png` and linked from `overview.md`.

**CI-friendly exit codes.**

```bash
super-design --ci \
  && echo "OK" \
  || { echo "Visual diffs exceed threshold"; exit 1; }
```

In `--ci` mode the skill writes a JUnit XML report and exits non-zero when any visual regression exceeds `max_diff_pixel_ratio`.

**Masking implementation** — Playwright's `mask` option is the right primitive. Each locator in `mask_selectors` is converted to `page.locator(sel)` and passed to `page.screenshot({ mask: [...] })`; Playwright overlays a solid-color box (default `#FF00FF`, configurable via `maskColor`) over each matched element before snapshotting. Prefer a neutral mask color (black or white depending on theme) so the masked area doesn't dominate the diff output.

**Threshold guidance by engine.**

| Engine | Default threshold | Tighter for UI-heavy sites | Looser for text-heavy sites |
|---|---|---|---|
| pixelmatch | `threshold: 0.1` | `0.05` | `0.15` |
| odiff | `--threshold=0.1` | `0.05` | `0.15` |
| Playwright `toHaveScreenshot` | `threshold: 0.2` | `0.1` + `maxDiffPixels: 200` | default + `maxDiffPixelRatio: 0.01` |
| looks-same (CIEDE2000 ΔE) | `2.3` | `1.0` | `3.5` |
| BackstopJS (Resemble %) | `misMatchThreshold: 0.1` | `0.05` | `0.3` |

**Known gotchas to document for users.**

- Resemble silently downsamples images wider than 1200px unless `largeImageThreshold: 0`.
- Playwright 1.42.1 didn't honor `maxDiffPixelRatio`; require 1.43+ (confirmed fixed in microsoft/playwright#30112).
- Baselines are **per platform + browser**: regenerate when upgrading the Docker image, not on a dev laptop.
- `animations: "disabled"` only fast-forwards finite animations — infinite loops reset to initial state and may still flake if the capture lands mid-keyframe; combine with `reducedMotion: "reduce"` and explicit `waitFor` on a content-ready selector.

---

## Conclusion

The durable insight: **delta detection for design audits is a cascade of hashes, not a single git query.** Git tells you what files changed; it can't tell you whether the rendered page actually looks different. You need four complementary signals — commit range (what files), token hash (global redraws), component hash + import graph (local blast radius), and page-level HTML/DOM/pixel hashes (reality check) — each answering a different question.

Three anti-patterns are fatal and bear repeating: **never assume the last SHA still exists** (force-pushes and squash-merges will bite); **never skip token detection** (a single changed CSS variable invalidates every page); and **never trust HTML hashing alone** (CSS-only changes leave HTML byte-identical while repainting the world). The decision tree in §4 and the orchestrator flow in §14 encode these failure modes explicitly, and the fallback ladder in §6 makes them recoverable rather than fatal.

What this playbook deliberately doesn't solve: cross-device visual consistency (Windows ClearType vs macOS grayscale font rendering is an ecosystem problem — pin a Docker image and move on), and semantic equivalence of design changes (a 1px padding shift is "the same" to a human but a 40k-pixel diff to a machine — perceptual hashing with Hamming distance ≤5 is the closest practical proxy, not a solution). Both are worth revisiting if the skill ever graduates from "audit the delta" to "evaluate the intent."

The playbook's most underrated leverage point is the **skip path**: an incremental audit that runs in under a second when there are no design-relevant changes teaches users to invoke the skill freely — turning it from a once-a-quarter ritual into a continuous design-quality signal.