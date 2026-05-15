# Playwright MCP inside Claude Code: A production reference for UX-audit subagents

Microsoft's **`@playwright/mcp`** is the right choice for design/UX audit subagents in Claude Code (terminal, v2.1+), but only if you pin a known-good version, say "Playwright MCP" explicitly in the first turn, and enforce a SHOW-YOUR-WORK evidence protocol. This reference consolidates verified behavior from the official README, npm registry, GitHub issue #1359, Simon Willison's TIL, Playwright's device registry, and three real community subagent examples. The dominant pitfalls are not API gaps — they are **per-snapshot ref churn**, **inline screenshot token explosions (4× more than CLI)**, and Claude Code's tendency to reach for Bash instead of the MCP tools when the prompt is vague. Everything below is structured so you can copy-paste into a shipping skill.

Verified state as of **April 18, 2026**: `@playwright/mcp@0.0.70` is current on npm (306 versions published); issue #1359 — the notorious "No such tool available: mcp__playwright__browser_navigate" bug — is **closed**, with `0.0.41` as the validated fallback pin. Claude Code 2.0.1 through 2.1.22 are all compatible with a correctly pinned server.

---

## 1. Installation and configuration for Claude Code

### Canonical install (straight from the Microsoft README)

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

Node 18+ required. This works because `claude mcp add` reads `npx` as the command and `@playwright/mcp@latest` as its first arg. When you start passing flags that could be confused with `claude mcp add`'s own flags, use the `--` separator:

```bash
# With flags passed through to the MCP server:
claude mcp add playwright -- npx @playwright/mcp@latest --headless --viewport-size "1440x900"
claude mcp add playwright -- npx @playwright/mcp@latest --device "iPhone 15"
claude mcp add playwright -- npx @playwright/mcp@latest --isolated --storage-state ./auth/storage.json
```

**Windows**: wrap with `cmd /c` — `claude mcp add playwright -- cmd /c npx @playwright/mcp@latest`.

### Scopes: local vs project vs user

| Scope | Flag | Storage | Shared? | Use for |
|---|---|---|---|---|
| **local** (default) | `--scope local` | `~/.claude.json` under `projects["<cwd>"].mcpServers` | Private, per-directory | Experiments, personal tokens |
| **project** | `--scope project` | **`.mcp.json` at repo root** | Yes — commit to git | Team-shared tooling |
| **user** | `--scope user` | `~/.claude.json` top-level `mcpServers` | Private, all your projects | Personal global tools |

Precedence when multiple scopes define the same server: **local > project > user**. Historical note: older Claude Code called `local` → `project` and `user` → `global`.

### The `.mcp.json` schema (project scope)

Lives at the project root and should be committed. Minimal form:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

Extended form with explicit transport type, timeout, and env:

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "timeout": 30,
      "args": ["-y", "@playwright/mcp@0.0.70", "--headless", "--isolated",
               "--output-dir", "./audit/screens", "--image-responses", "omit"],
      "env": {
        "PLAYWRIGHT_MCP_CONSOLE_LEVEL": "warning"
      },
      "disabled": false
    }
  }
}
```

User and local scopes live inside **`~/.claude.json`** rather than a dedicated file — a structure shared with `allowedTools`, `mcpContextUris`, and per-project state.

### Version state and the #1359 tool-name bug

**Latest:** `@playwright/mcp@0.0.70` (published mid-April 2026). **Known-broken:** `0.0.56` and `0.0.61` — both failed against Claude Code 2.0.1 → 2.1.22 with the error:

```
Error: No such tool available: mcp__playwright__browser_navigate
```

Root cause was a **tool-schema registration mismatch**: the MCP server connected successfully but Claude Code's session-stored tool manifest didn't include the `mcp__playwright__browser_*` tools, so the model couldn't see or call them. Not a permissions issue, not a server crash — a plumbing bug between the two. Issue #1359 is **closed**; `@latest` should work again. **Recommended pin for shared configs**: `@playwright/mcp@0.0.41` (the community-validated fallback) or `@playwright/mcp@0.0.70` after you verify it in your environment. Never pin `0.0.56` or `0.0.61`. The pre-release alpha Playwright runtime this package tracks is another reason to pin rather than use `@latest` in `.mcp.json` committed to a team repo.

Resolution pattern:

```bash
claude mcp remove playwright
claude mcp add playwright npx @playwright/mcp@0.0.41   # known-good fallback
```

### Verification

Outside a session: `claude mcp list` shows registered servers and their connection state. Inside a session: the **`/mcp`** slash command opens a panel listing each server's status and its available tools. Simon Willison's first-test prompt:

```
Use playwright mcp to open a browser to example.com
```

You **must** say "playwright mcp" explicitly — otherwise Claude often reaches for Bash or `curl` instead of the MCP tools (see §7).

### Transports: stdio vs HTTP/SSE

**stdio** (default) — Claude Code spawns `npx @playwright/mcp@latest` and talks JSON-RPC over stdin/stdout. Use locally.

**HTTP/SSE** — run the server separately, connect by URL. Use when running headed browser on a display-less host (WSL, remote dev box), Docker, or sharing a server across a team.

```bash
npx @playwright/mcp@latest --port 8931
# --host 0.0.0.0 to bind all interfaces
```

Register:

```bash
claude mcp add --transport http playwright http://localhost:8931/mcp
```

Or in `.mcp.json`:

```json
{ "mcpServers": { "playwright": { "url": "http://localhost:8931/mcp" } } }
```

### Browser binaries and Linux deps

Playwright MCP needs a browser binary. Three paths:

```bash
npx playwright install chromium       # ahead of time
npx playwright install                 # all browsers
npx playwright install-deps            # Linux/Docker system libs (apt packages)
```

Or call the MCP tool `browser_install` after connection — it installs whatever `--browser` the config specifies. Because `@playwright/mcp` often tracks alpha Playwright builds, running `npx playwright install` from a *different* local Playwright version can produce mismatched binaries. The `@latest` suffix on the MCP package fetches a clean copy rather than reusing whatever Playwright lives in your `node_modules`.

Docker (headless chromium only):

```json
{ "mcpServers": { "playwright": {
  "command": "docker",
  "args": ["run", "-i", "--rm", "--init", "--pull=always",
           "mcr.microsoft.com/playwright/mcp"]
}}}
```

### Microsoft vs ExecuteAutomation — pick Microsoft

| Dimension | **Microsoft `@playwright/mcp`** | ExecuteAutomation `@executeautomation/playwright-mcp-server` |
|---|---|---|
| Status | **Official**, Microsoft Playwright team | Community third-party |
| Stars / forks | 31k / 2.5k | 5.4k / 489 |
| Tool prefix | `browser_*` | `playwright_*` |
| Interaction model | **Accessibility-tree-based** (`ref=eNN` identifiers) | DOM/selector + visible-text |
| Vision needed? | No — structured snapshots | Optional (screenshot parsing) |
| Tool count | ~19 core + opt-in caps (vision/pdf/testing/tracing) → 70+ | Smaller, DOM-focused |
| Chrome extension ("attach to my real tab") | Yes (`--extension`) | No |
| Docker image | `mcr.microsoft.com/playwright/mcp` | Community builds only |
| Cadence | 306 versions; weekly releases | Active but slower |

**Pick Microsoft's** for Claude Code audits: the accessibility-tree model gives **deterministic element targeting via stable `ref` IDs**, no vision-model dependency, and tracks Playwright core features as they ship. The Playwright docs explicitly recommend it; Builder.io's guide calls out the namespace collision warning that *"`Playwright MCP server` in search results is often ExecuteAutomation's separate community project — Microsoft's official package is `@playwright/mcp`."*

---

## 2. Complete tool API (@playwright/mcp, current)

All tools expose as `mcp__<server-name>__<tool-name>` to Claude — so `browser_navigate` on a server you registered as `playwright` becomes **`mcp__playwright__browser_navigate`**. Tools are organized by capability. **Core + core-tabs + core-install are always on**. `--caps=vision,pdf,testing,tracing` enable opt-in groups.

### Core automation (always enabled)

**`browser_navigate`** — `url` (string, required). Navigate to a URL.

**`browser_navigate_back`** — no params. Go back one page. ⚠️ `browser_navigate_forward` is **not in the current README** — earlier versions had it; assume absent in 0.0.70.

**`browser_snapshot`** — `filename` (string, optional). Returns the **accessibility tree** as YAML-like text (roles, accessible names, `ref=eNN` identifiers). *"This is better than screenshot"* per the README. Token-cheap and deterministic. See §2.4 for the ref system.

**`browser_take_screenshot`** — `type` (`png`|`jpeg`, default png), `filename` (default `page-{timestamp}.{png|jpeg}`), `element` (string) + `ref` (string) for per-element (must be provided together), `fullPage` (boolean, cannot combine with element). Per README: *"You can't perform actions based on the screenshot — use `browser_snapshot` for actions."*

**`browser_click`** — `element` (required human-readable desc), `ref` (required), `doubleClick` (bool), `button` (`left`|`middle`|`right`), `modifiers` (array).

**`browser_type`** — `element`, `ref`, `text` (all required), `submit` (bool, press Enter after), `slowly` (bool, char-by-char for key handlers).

**`browser_hover`** — `element`, `ref` (both required).

**`browser_fill_form`** — `fields` (array, required). ⚠️ The tool is **`browser_fill_form`**, not `browser_fill`. Inner per-field schema is not itemized in the README prose (it's in the runtime JSON Schema).

**`browser_press_key`** — `key` (string, required): `ArrowLeft`, `Enter`, a single char, etc.

**`browser_select_option`** — `element`, `ref`, `values` (array, single or multiple).

**`browser_drag`** — `startElement`, `startRef`, `endElement`, `endRef` (all required).

**`browser_resize`** — `width` (number), `height` (number), both required. Runtime viewport resize. No `device` or `orientation` param — those are `--device` launch-time only.

**`browser_evaluate`** — `function` (string, required, form `() => { ... }` or `(element) => { ... }`), `element` + `ref` (optional pair). Cannot accept `ref=eNN` as the argument directly; pass a CSS selector inside the function body (see issue #870).

**`browser_run_code`** — `code` (string, required). Full Playwright snippet: `async (page) => { await page.getByRole('button', { name: 'Submit' }).click(); return await page.title(); }`.

**`browser_console_messages`** — `level` (`error`|`warning`|`info`|`debug`, default `info`). Each level includes more severe levels.

**`browser_network_requests`** — `includeStatic` (bool, default false). Static assets like images/fonts/scripts are filtered unless enabled. Failed-request field names are not documented in the README.

**`browser_wait_for`** — mutually exclusive: `text` (appears), `textGone` (disappears), or `time` (seconds). **Prefer `text`** — see §7.

**`browser_handle_dialog`** — `accept` (bool, required), `promptText` (string). For native `alert`/`confirm`/`prompt`, not HTML modals.

**`browser_file_upload`** — `paths` (array of absolute paths). Empty cancels the chooser.

**`browser_close`** — no params.

### Tabs + install (always enabled)

**`browser_tabs`** — `action` (`list`|`new`|`close`|`select`), `index` (number, optional). Unifies what earlier versions had as `browser_tab_new`/`_close`/`_list`/`_select`.

**`browser_install`** — no params. Installs the browser specified in the config. Call this on "browser not installed" errors.

### Opt-in caps

`--caps=vision`:
- **`browser_mouse_click_xy`** — `element`, `x`, `y`
- **`browser_mouse_move_xy`** — `element`, `x`, `y`
- **`browser_mouse_drag_xy`** — `element`, `startX`, `startY`, `endX`, `endY`

`--caps=pdf`:
- **`browser_pdf_save`** — `filename` (default `page-{timestamp}.pdf`).

`--caps=testing`:
- **`browser_generate_locator`** — `element`, `ref`. Generate test-grade locator.
- **`browser_verify_element_visible`** — `role`, `accessibleName`.
- **`browser_verify_text_visible`** — `text`.
- **`browser_verify_list_visible`** — `element`, `ref`, `items` (array).
- **`browser_verify_value`** — `type`, `element`, `ref`, `value` (use `"true"`/`"false"` for checkboxes).

`--caps=tracing`:
- **`browser_start_tracing`** / **`browser_stop_tracing`** — no params.

### The `ref=eNN` accessibility-reference system

`browser_snapshot` returns a structured accessibility tree, **not pixels**. Every interactive node carries a role, accessible name, and a stable ref — **assigned at snapshot time** by walking the tree:

```yaml
- banner:
  - heading "Example Domain" [level=1] [ref=e3]
  - paragraph [ref=e4]: "This domain is for use in illustrative examples..."
  - link "More information..." [ref=e5]:
      /url: https://www.iana.org/domains/example
- textbox "Search" [ref=e12]
- button "Submit" [ref=e13]
```

**Scope and stability** — refs are scoped to a single snapshot. The `e{N}` prefix is the main frame; `s{F}e{N}` is subframe-F element-N. **After any mutation (click, type, navigate), refs go stale**. Call `browser_snapshot` again before the next interaction, or rely on the auto-snapshot that most tools return in their response.

**Why two params (`element` + `ref`)** — every interaction tool takes both. `ref` is the deterministic target; `element` is a human-readable description used for permission prompts and logging. For drag, the pattern doubles into `startElement`/`startRef` + `endElement`/`endRef`:

```json
{ "tool": "mcp__playwright__browser_click",
  "arguments": { "element": "'More information' link in banner", "ref": "e5" } }
```

**Snapshot modes** — `--snapshot-mode` (env `PLAYWRIGHT_MCP_SNAPSHOT_MODE`): `incremental` (default, return diff only), `full` (always complete tree), `none` (suppress auto-snapshot; you must call `browser_snapshot` manually). Use `none` on very large pages to avoid context bloat; see §10.

---

## 3. Viewport and device emulation

### Launch-time flags

```
--viewport-size <WxH>    e.g. "1440x900"   env PLAYWRIGHT_MCP_VIEWPORT_SIZE
--device <name>          e.g. "iPhone 15"
--user-agent <string>    override UA       env PLAYWRIGHT_MCP_USER_AGENT
```

Viewport format is **`WIDTHxHEIGHT`** with lowercase `x`. The comma form (`1280,720`) is not documented.

### Runtime resize

`browser_resize(width, height)` calls `page.setViewportSize(...)` under the hood — it changes **viewport dimensions only**. Any `--device`-derived `deviceScaleFactor`, `userAgent`, `isMobile`, or `hasTouch` flags remain intact. There is **no MCP tool to change `--device` mid-session**; to switch device emulation, restart the server.

### Useful device names from Playwright's registry

All names are case-sensitive, from `deviceDescriptorsSource.json`. Each has a `" landscape"` variant.

| `--device` value | Viewport | DPR | Engine |
|---|---|---|---|
| `"iPhone SE"` | 320×568 | 2 | webkit |
| `"iPhone 13"` / `"iPhone 14"` | 390×664 | 3 | webkit |
| `"iPhone 15"` / `"iPhone 15 Pro"` | 393×659 | 3 | webkit |
| `"iPhone 15 Pro Max"` | 430×739 | 3 | webkit |
| `"Pixel 5"` | 393×727 | 2.75 | chromium |
| `"Pixel 7"` | 412×839 | ~2.625 | chromium |
| `"Galaxy S9+"` | 320×658 | 4.5 | chromium |
| `"iPad Mini"` | 768×1024 | 2 | webkit |
| `"iPad Pro 11"` | 834×1194 | 2 | webkit |
| `"Desktop Chrome"` / `"Desktop Safari"` / `"Desktop Edge"` / `"Desktop Firefox"` | 1280×720 | 1 | varies |

### Standard audit breakpoints

The community converges on three: **375×812 mobile**, **768×1024 tablet**, **1440×900 desktop**. For comprehensive sweeps, add **1920×1080** (full HD). For the smallest mobile, test **320×568** (iPhone SE). Use `browser_resize` between pages — don't restart the server.

### Device-pixel-ratio and screenshot bloat

**iPhone 15 at DPR 3** turns a 393×2000 CSS-px full-page shot into **1179×6000 physical pixels** — easily 3–10 MB, and catastrophic if returned inline to the model. Mitigations, in priority order:

1. Run with `--image-responses omit` (env `PLAYWRIGHT_MCP_IMAGE_RESPONSES=omit`) so screenshots go to disk instead of being base64-encoded into the response.
2. Prefer `browser_snapshot` for decisions; use `browser_take_screenshot` only for reviewer evidence.
3. On high-DPR devices, pass `type: "jpeg"` or restrict to element screenshots.
4. Save with descriptive relative filenames into `--output-dir`.

---

## 4. Capture strategies

### Snapshot vs screenshot (know when to use which)

| Need | Tool | Token cost | When |
|---|---|---|---|
| Decide what to do, get refs | `browser_snapshot` | 200–400 tokens on small pages, multi-K on rich apps | **Default**; after every state change |
| Visual evidence for human reviewer | `browser_take_screenshot` | 4–8K inline, ~50 if saved to disk | Only when visuals matter; always save to disk |
| Computed styles (hex, px, ratios) | `browser_evaluate` | Tiny | Required for any WCAG-grade numeric claim |
| Error context | `browser_console_messages` | Small | At top of every page audit |
| Failed resource requests | `browser_network_requests` | Small–medium | When diagnosing 404s, blocked requests |

Playwright's own benchmark shows **~114K tokens via MCP vs ~27K via CLI** on equivalent tasks — a 4× multiplier driven almost entirely by inline images and auto-snapshots. A single content-heavy-page screenshot inline is 5–8K tokens; saved to disk, it's ~50 tokens for the path.

### Full-page and element captures

```json
// Full page
{ "tool": "browser_take_screenshot",
  "arguments": { "fullPage": true, "filename": "home_mobile.png" } }

// Per-element (from a prior snapshot)
{ "tool": "browser_take_screenshot",
  "arguments": { "element": "Primary CTA button",
                 "ref": "e87",
                 "filename": "cta_mobile.png" } }
```

`fullPage: true` and `element`/`ref` are **mutually exclusive**.

### Output env vars (verified from `--help`)

```
--output-dir <path>          env PLAYWRIGHT_MCP_OUTPUT_DIR
--save-session               env PLAYWRIGHT_MCP_SAVE_SESSION
--save-trace                 env PLAYWRIGHT_MCP_SAVE_TRACE
--save-video <WxH>           env PLAYWRIGHT_MCP_SAVE_VIDEO
--image-responses allow|omit env PLAYWRIGHT_MCP_IMAGE_RESPONSES
--snapshot-mode incremental|full|none  env PLAYWRIGHT_MCP_SNAPSHOT_MODE
```

⚠️ **`PLAYWRIGHT_MCP_OUTPUT_MODE` is NOT documented** in the current upstream README. If your notes or third-party guides reference it with values `file`/`stdout`, they're citing a fork or an outdated version. The actual lever for "send images to disk, not into the model" is `--image-responses omit`. The closest match for session-trace persistence is `--save-session` / `PLAYWRIGHT_MCP_SAVE_SESSION`.

### Default output directory

The README does **not** explicitly state the default. Files go to an OS temp directory created at startup when `--output-dir` is omitted. **Always pass `--output-dir` explicitly** for audits so evidence lands in a predictable place. Default auto-generated filenames are `page-{timestamp}.png|jpeg|pdf`.

### File-naming strategy for audit evidence

Deterministic, sortable, and relative. Pass `filename` explicitly for every shot:

```
{route-slug}_{viewport-label}_{state}_{iso-timestamp}.png

home_iphone15_loggedout_2026-04-18T14-32-11Z.png
pricing_1440x900_loggedin_2026-04-18T14-33-02Z.png
checkout-step2_ipadpro_error_2026-04-18T14-35-44Z.png
```

Keep filenames relative (no leading `/`) so they resolve inside `--output-dir`.

---

## 5. Authentication and state

### Persistent profile (default)

Without `--isolated`, Playwright MCP uses a persistent profile. Default locations:

```
Windows: %USERPROFILE%\AppData\Local\ms-playwright\mcp-{channel}-profile
macOS:   ~/Library/Caches/ms-playwright/mcp-{channel}-profile
Linux:   ~/.cache/ms-playwright/mcp-{channel}-profile
```

`{channel}` is `chrome` / `msedge` / `chromium`. Some newer versions use `mcp-{channel}-{workspace-hash}` to give different projects separate profiles — inspect the directory after first run to see which form your version uses.

### The "log in yourself, then continue" pattern

From the README: *"All the logged in information will be stored in the persistent profile; you can delete it between sessions if you'd like to clear the offline state."* Flow:

1. Launch MCP in headed mode (default, don't pass `--headless`) with an explicit `--user-data-dir ./.pw-mcp-profile`.
2. Agent navigates to the login URL via `browser_navigate`.
3. **You log in manually** in the headed browser while the agent pauses or waits on a text signal.
4. Cookies/localStorage persist into the profile directory.
5. Future sessions with the same `--user-data-dir` skip login.

### `--storage-state` for CI

With `--isolated`, every session starts clean — closing the browser discards all state. Pre-seed credentials via Playwright's standard storageState JSON:

```json
{ "mcpServers": { "playwright": {
  "command": "npx",
  "args": ["@playwright/mcp@latest",
           "--isolated",
           "--storage-state=./auth/storage.json"]
}}}
```

Generate the file once with `playwright codegen --save-storage=./auth/storage.json` or from test code.

### The browser-extension approach ("share my real tab")

Install the **Playwright MCP Bridge** extension from github.com/microsoft/playwright-mcp/releases. Load it as unpacked in `chrome://extensions/` with Developer mode on. Then:

```json
{ "mcpServers": { "playwright-extension": {
  "command": "npx",
  "args": ["@playwright/mcp@latest", "--extension"]
}}}
```

On first tool call, the extension opens a tab-picker; you select the running tab the agent attaches to. For headless auto-approval, copy the `PLAYWRIGHT_MCP_EXTENSION_TOKEN` from the extension popup and put it in the server's `env` block. This is the only way to get **real SSO sessions, enterprise policies, and ad-blocker state** without manual reauth — MCP attaches rather than spawning a clean Playwright browser.

---

## 6. Security and scope

### Origin allow/block lists

```
--allowed-origins "https://a.com;https://*.b.com"    env PLAYWRIGHT_MCP_ALLOWED_ORIGINS
--blocked-origins "https://evil.com"                 env PLAYWRIGHT_MCP_BLOCKED_ORIGINS
```

**Semicolon-separated**, not comma. Glob wildcards with `*` are supported (Playwright-style). Blocklist is evaluated first. With only a blocklist, non-matching requests are still allowed.

### File access

`--allow-unrestricted-file-access` / `PLAYWRIGHT_MCP_ALLOW_UNRESTRICTED_FILE_ACCESS` unlocks two defaults:
- File-system access (for upload paths, output paths) is otherwise restricted to the MCP client's workspace roots (or cwd).
- `file://` navigation is otherwise blocked.

### The "not a security boundary" disclaimer (verbatim)

The README — and both origin flag help strings — explicitly state:

> **Playwright MCP is *not* a security boundary. See MCP Security Best Practices for guidance on securing your deployment.**

> "`--allowed-origins` / `--blocked-origins`: Important: *does not* serve as a security boundary and *does not* affect redirects."

> "`allowUnrestrictedFileAccess` acts as a guardrail to prevent the LLM from accidentally wandering outside its intended workspace. It is a convenience defense to catch unintended file access, not a secure boundary; a deliberate attempt to reach other directories can be easily worked around, so always rely on client-level permissions for true security."

Practical implication: origin lists can be bypassed via **DNS rebinding, HTTP redirects, or direct navigation**. Treat them as hygiene controls, not containment. For real isolation, run MCP in a disposable container or VM.

### Data-leakage implications for authenticated audits

Every byte returned by an MCP tool is forwarded to Anthropic's API. Specifically, that includes:

- `browser_snapshot` — all visible text, `aria-label`s, form labels, occasionally form values
- `browser_take_screenshot` — raw pixels (names, emails, dashboards, tokens in URL bars)
- `browser_console_messages` — stack traces frequently containing tokens, debug dumps, API request bodies
- `browser_network_requests` — URLs including query-string session IDs
- `browser_evaluate` — arbitrary JS (`document.cookie`, `localStorage`, DOM secrets)

**Never audit prod with real PII.** Use a staging tenant seeded with synthetic data, pair it with `--image-responses omit` + local human review, and check your Anthropic retention/ZDR tier before running against anything internal.

### Docker and `--no-sandbox`

`--no-sandbox` disables Chromium's sandbox — required inside minimal containers (including `mcr.microsoft.com/playwright/mcp` when running as root without user-namespace capabilities). Fine for a disposable container, bad on a workstation. Example long-lived container from the README:

```bash
docker run -d -i --rm --init --pull=always \
  --entrypoint node --name playwright -p 8931:8931 \
  mcr.microsoft.com/playwright/mcp \
  cli.js --headless --browser chromium --no-sandbox --port 8931
```

---

## 7. Prompting patterns: how to get the tools actually used

### Rule zero: say "Playwright MCP" explicitly

Simon Willison's TIL (til.simonwillison.net/claude-code/playwright-mcp-claude-code) is blunt:

> "I found I needed to explicitly say 'playwright mcp' the first time, otherwise it might try to use Bash to run Playwright instead."

The mechanism is Claude's tool-selection heuristic — "test the login page" semantically matches the general-purpose `Bash` tool more strongly than `mcp__playwright__browser_navigate`, **especially in repos where `playwright` is already a dev dependency**. Writing "Playwright MCP" (or the `mcp__playwright__` prefix) in the first turn aligns the request with the MCP tool descriptions. Canonical kickoff:

```
Using the Playwright MCP server (mcp__playwright__*), open http://localhost:3000
and perform a responsive audit. Do NOT use Bash, curl, or write a Playwright
test file — drive the browser live through the MCP tools.
```

### Standard recon flow

```
browser_navigate(url)
  → browser_wait_for(text="<known copy on loaded page>")   # text, not time
  → browser_console_messages()                              # bail early on JS errors
  → browser_snapshot()                                      # get refs
  → [quote refs verbatim in findings]
  → browser_click({ ref: "e42", element: "Submit button in 'Billing' form" })
  → browser_wait_for(text="<post-action signal>")
  → browser_snapshot()                                      # REFRESH — old refs stale
  → browser_evaluate(...)                                   # numeric evidence
  → browser_take_screenshot({ fullPage: true, filename: "..." })
```

### Viewport loop (responsive audits)

Embed in the subagent system prompt. Run **sequentially** inside one subagent, not as parallel subagents sharing one browser tab (issue #893 — they fight over the same tab and return inconsistent results unless you use `--isolated` + per-agent `browser_tab_new`).

```python
VIEWPORTS = [("mobile", 375, 812), ("tablet", 768, 1024), ("desktop", 1440, 900)]
PAGES = ["/", "/pricing", "/docs", "/signup"]

for page in PAGES:
  for name, w, h in VIEWPORTS:
    browser_resize(width=w, height=h)
    browser_navigate(url=BASE+page)
    browser_wait_for(text=EXPECTED[page])
    browser_console_messages()
    snap = browser_snapshot()          # save to audit/snapshots/{page}_{vp}.yaml
    browser_take_screenshot(fullPage=True,
                            filename=f"audit/screens/{page}_{vp}.png")
    styles = browser_evaluate(function="() => { /* getComputedStyle for h1, CTA, nav */ }")
    append_finding(...)
```

### Waiting strategies — text beats time, always

Playwright itself *"discourages waitFor methods that wait for network connections to be idle"* — modern apps never stop talking (analytics beacons, websockets, polling). `networkidle` is a trap.

Decision tree:
- Just navigated? → `browser_wait_for(text="<known copy>")`
- Clicked something that opens a modal? → `browser_wait_for(text="<modal heading>")`
- Removed a spinner? → `browser_wait_for(textGone="Loading...")`
- No textual signal? → `browser_evaluate` polling `document.readyState` or a specific selector
- Absolutely last resort → `browser_wait_for(time=1)` with a comment explaining why

Also: **auto-wait exists**. `browser_click`/`browser_type` already wait for actionability. Don't stack a redundant `browser_wait_for` before every action — only after navigation and async state changes.

### `browser_evaluate` patterns for WCAG-grade numbers

```js
// Contrast + typography
(el => {
  const s = getComputedStyle(el);
  return { color: s.color, background: s.backgroundColor,
           fontSize: s.fontSize, lineHeight: s.lineHeight,
           fontWeight: s.fontWeight };
})(document.querySelector('h1.hero__title'))

// Touch-target audit (WCAG 2.5.5 — 44×44 CSS px)
[...document.querySelectorAll('button, a, [role=button]')].map(el => {
  const r = el.getBoundingClientRect();
  return { text: el.innerText.slice(0,40), w: r.width, h: r.height,
           ok: r.width >= 44 && r.height >= 44 };
}).filter(x => !x.ok)
```

### Error handling

| Failure | Response |
|---|---|
| `ref=eNN` not found | Page re-rendered. Re-snapshot, re-identify by accessible name, retry with new ref. Don't guess CSS selectors. |
| Click hit wrong element | Two "Submit" buttons — re-snapshot, include parent context in `element`: `"Submit button inside 'Shipping address' form"`, pick the ref nested under that parent in the YAML. |
| `browser_wait_for(text=…)` timeout | 80% of the time: there's a JS error. Dump `browser_console_messages` first, then `browser_snapshot` to see what actually rendered. Retry with different text or `textGone`. |
| "No browser" error | `browser_install` once, then retry. Don't loop blindly. |
| Same step fails twice | **Stop.** Write failure + snapshot + console to findings, surface to orchestrator. Do NOT fabricate success. |

---

## 8. Anti-hallucination and verification

Community reports are consistent: the agent often loses its place around step 12 of a 20-step flow, starts hallucinating selectors, and writes findings for pages it never visited. The antidote is structural, not prompt-hopeful.

### Require a structured JSON findings file

The findings file is the **single source of truth** — nothing the agent *says* in chat counts unless it's in the file:

```json
{
  "id": "f-001",
  "page_url": "https://app.example.com/pricing",
  "viewport": { "name": "mobile", "w": 375, "h": 812 },
  "screenshot_path": "audit/screens/pricing_mobile.png",
  "snapshot_path":   "audit/snapshots/pricing_mobile.yaml",
  "snapshot_quote":  "- button \"Get started\" [ref=e87]",
  "dom_selector":    "main > section.cta > button.primary",
  "computed_style_excerpt": {
    "color": "rgb(255, 255, 255)", "background-color": "rgb(147, 197, 253)",
    "font-size": "14px", "min-height": "36px", "min-width": "88px"
  },
  "wcag_criterion": "2.5.5 Target Size (AAA) / 1.4.3 Contrast",
  "severity": "high",
  "evidence_hex_fg": "#FFFFFF",
  "evidence_hex_bg": "#93C5FD",
  "evidence_contrast_ratio": 1.89,
  "finding": "Primary CTA is 88×36px (fails 44×44) and 1.89:1 contrast (fails 4.5:1)."
}
```

Every field is mandatory. Missing field → orchestrator rejects the run.

### Orchestrator-side verification: stat the paths

The parent agent (or a `SubagentStop` hook) must verify **before** accepting the report:

```bash
# scripts/verify-audit.sh
set -euo pipefail
jq -e 'length > 0' audit/findings.json >/dev/null
jq -r '.[] | .screenshot_path, .snapshot_path' audit/findings.json | while read p; do
  [ -s "$p" ] || { echo "MISSING OR EMPTY: $p"; exit 1; }
done
# Every snapshot_quote must literally appear in the snapshot file it cites
jq -c '.[]' audit/findings.json | while read f; do
  q=$(echo "$f" | jq -r .snapshot_quote)
  s=$(echo "$f" | jq -r .snapshot_path)
  grep -qF "$q" "$s" || { echo "QUOTE NOT IN SNAPSHOT: $s"; exit 1; }
done
```

If verification fails, re-dispatch the subagent with a **SHOW-YOUR-WORK retry prompt** that lists the specific gaps.

### Verbatim accessibility-tree quoting

Playwright MCP snapshots have a fixed format: `- <role> "<name>" [ref=eNN]`. Rule in the subagent prompt:

> For every finding, `snapshot_quote` MUST be a single line copied character-for-character from the snapshot file you saved, containing a `[ref=eNN]` token. If you can't produce a verbatim line, the element wasn't in the a11y tree — say so and switch to a DOM selector with a screenshot crop as evidence.

A hallucinated ref fails `grep -qF` trivially — that's the point.

### Show-your-work discipline

Every finding must cite four things:

- **[SHOT]** — a screenshot file on disk
- **[QUOTE]** — a verbatim line from the snapshot YAML, including `[ref=eNN]`
- **[SEL]** — a CSS selector that resolves
- **[VAL]** — a computed value from `browser_evaluate`

Miss any one → don't file the finding, file the gap instead: *"Component observed in <screenshot> but absent from accessibility tree — likely shadow DOM or canvas."*

### Retry loop

When verification fails:

```
Your previous audit run failed verification. Specific problems:
  - findings.json is missing screenshot_path for 3 entries
  - snapshot_quote "button 'Buy now' [ref=e42]" not found in
    audit/snapshots/pricing_mobile.yaml

Re-run with SHOW-YOUR-WORK discipline:
1. Every finding MUST cite SHOT+QUOTE+SEL+VAL (all four).
2. Do NOT invent findings for elements you did not snapshot.
3. If you can't see an element in the a11y tree, say so.
4. Save screenshots and snapshots to disk BEFORE writing findings.json.
```

### Required summary block

`audit/SUMMARY.md` with fixed headings (grep'd by the verifier for URL count, viewport count, finding row count):

```markdown
# Audit Summary
## Pages visited
- https://app.example.com/
- https://app.example.com/pricing
## Viewports tested
- mobile 375×812
- tablet 768×1024
- desktop 1440×900
## Findings
| id | url | vp | ref | selector | hex_fg | hex_bg | px | severity |
|----|-----|----|-----|----------|--------|--------|----|----------|
```

---

## 9. Integration with Claude Code subagents (.claude/agents/)

### Frontmatter fields (2026)

Required: `name`, `description`. Optional:

| Field | Purpose |
|---|---|
| `tools` | Comma-separated allowlist. Omit → inherits ALL parent tools (including every MCP). |
| `disallowedTools` | Explicit deny list, overrides inherit |
| `model` | `sonnet` / `opus` / `haiku` / full ID / `inherit` |
| `permissionMode` | `default` / `acceptEdits` / `dontAsk` / `bypassPermissions` / `plan` |
| `mcpServers` | List of MCP server names to scope to this subagent (additive, see caveat below) |
| `hooks` | Pre/PostToolUse/Stop hooks scoped to this subagent |
| `skills` | Skills preloaded at startup |
| `memory` | `user` / `project` / `local` |
| `maxTurns` | Hard cap on agentic turns |
| `background` | `true` → concurrent background task |
| `isolation` | `worktree` → run in temp git worktree |
| `color`, `effort` | UI color; effort tier for Opus |

Plugin-installed subagents **cannot** use `hooks`, `mcpServers`, or `permissionMode` (security restriction).

### MCP tool naming

Confirmed pattern: **`mcp__<server-name>__<tool-name>`** (double underscores). A server registered with `claude mcp add playwright ...` exposes `mcp__playwright__browser_navigate`, `mcp__playwright__browser_snapshot`, etc. Wildcards work in allowlists: `mcp__playwright__*` grants all tools from that server. Plugin-scoped servers add a `plugin_<plugin-name>_` prefix.

### Per-subagent MCP scoping: real but imperfect

The `mcpServers:` frontmatter field exists but is **additive, not isolating**. From issue #24054:

> "No isolation: there's no way to make an MCP server available only to a subagent or skill. The `mcpServers` frontmatter field in agent definitions is additive — it selects from globally-configured servers but doesn't hide them from the parent."

And issue #25200 (open): `mcpServers` + MCP tools in `tools:` fails at runtime under deferred tool loading — workaround is to include the Playwright tools in the parent session's allowlist or set `ENABLE_TOOL_SEARCH=off`. Issue #6915 specifically cites Playwright as the motivating example: *"the main chat should be able to give instructions to a subagent to use the tools without polluting the context of the main chat with all of the Playwright MCP tool calls."* That feature is pending.

**Today's practical pattern**: include Playwright in the subagent's tool allowlist; in the parent's CLAUDE.md, instruct *"do not call `mcp__playwright__*` directly; delegate to the `ux-auditor` subagent."* The tool schemas still load into the parent's context — there's no way around that without the pending feature.

### Context-cost concern

Playwright MCP registers **~25 tools**. Simon Willison observed on Mastodon: *"the Playwright one is pretty big, it has 25 tools defined which may be too many for the local LLMs to handle."* Community benchmarks estimate **~500 tokens per tool schema**, i.e. **~12–15K tokens just to load Playwright's schemas** before any action. Combined with auto-snapshots (2–10K tokens each), a 30-action flow routinely burns 100K+ tokens. Playwright's own comparison: 114K MCP vs 27K CLI for equivalent work.

Mitigations, in priority order:
1. **Tool Search** (default in Claude Code late-2025+) loads only tool names at startup; schemas load on demand. Set `ENABLE_TOOL_SEARCH=auto`.
2. Scope Playwright to the audit subagent — even though schemas still load in the parent, the orchestrator won't *invoke* them, so snapshot pollution is avoided.
3. Run the server with `--output-dir` + `--image-responses omit` so images go to disk, not inline into context. Biggest single lever.
4. For long flows (>20 steps), Microsoft themselves recommend the CLI + Skill path: *"Modern coding agents increasingly favor CLI-based workflows exposed as Skills over MCP because CLI invocations are more token-efficient."*

---

## 10. Common pitfalls

**Snapshot churn on dynamic pages.** Refs are indexed per-snapshot, not stable IDs — the same button may be `ref=e87` in one snapshot and `ref=e91` in the next. Official guidance: *"Refs are stable within a single snapshot… after navigation or DOM updates, the tool returns a fresh snapshot with new refs. Most tools also return a snapshot automatically after each action."* Enforce: **treat every `[ref=eNN]` as valid for ONE action only.** Never reuse a ref across actions without a fresh snapshot.

**Accessibility tree vs DOM discrepancies.** Shadow DOM (Lit/Shoelace/Stencil, especially closed shadow roots) can be invisible to the a11y snapshot — Playwright itself can't pierce closed shadow roots at all. Cross-origin iframes are generally opaque. Canvas and custom-rendered charts don't appear in the tree. Detection rule: *"If you see a visual element in a screenshot but no corresponding entry in the YAML snapshot, report it as a high-severity finding: component not exposed to the accessibility tree — screen-reader users can't perceive it."*

**Modal and cookie-banner handling.** HTML modals and cookie banners are real DOM — dismiss via `browser_click` on the ref, **before** snapshotting main content (otherwise "real" content renders but is inert/covered). Native JS dialogs (`alert`, `confirm`, `prompt`) are NOT DOM and require `browser_handle_dialog` separately. A page-load `confirm()` will hang the entire session until handled. Prompt pattern: right after every `browser_navigate`, scan the snapshot for accessible names containing "cookie"/"consent"/"accept"/"GDPR"/"subscribe" and dismiss first.

**JS errors cascade.** One uncaught error during init silently breaks every downstream interaction — clicks "succeed" but state never updates. Call `browser_console_messages` immediately after every navigation; if errors exist, write them to findings and stop auditing that page rather than generating more findings on broken state.

**Duplicate accessible names.** Two buttons named "Submit" means both `element` disambiguation and `ref` matter. Resolution: include parent context in `element` (`"Submit button in 'Shipping address' form"`), pick the ref nested under the right parent in the YAML, or use `data-testid` via `--test-id-attribute`.

**Animation timing.** Screenshots mid-animation look broken (50%-opacity modals, half-slid sidebars). Don't use `networkidle`. Instead wait for text inside the animated component, or **disable animations** via `browser_evaluate` at the start of each page:

```js
() => {
  const s = document.createElement('style');
  s.textContent = '*,*::before,*::after{animation:none!important;transition:none!important;}';
  document.head.appendChild(s);
}
```

**Parallel subagents fighting over one tab** (issue #893). Multiple Claude subagents launched in parallel share the MCP server's browser tab and produce inconsistent results. Run viewport loops **sequentially inside one subagent**, or start the server with `--isolated` and have each agent call `browser_tab_new` first.

**`browser_evaluate` cannot use snapshot refs** (issue #870). The `evaluate` tool doesn't understand `ref=eNN` — you must pass a CSS/XPath selector inside the function body.

**Pages too big for context** (issue #1329). Some pages produce snapshots that exceed the context budget. Set `PLAYWRIGHT_MCP_SNAPSHOT_MODE=none` to suppress auto-snapshots and call `browser_snapshot` manually with the `filename` param so the tree goes to disk.

**Deprecated package warning.** `@modelcontextprotocol/server-playwright` is abandoned — use `@playwright/mcp`. `@executeautomation/playwright-mcp-server` is a different project with a different API; its `browser_resize` accepts `device`/`orientation` params that Microsoft's does not. Don't mix the docs.

---

## 11. A complete, ready-to-paste subagent

Save as `.claude/agents/sd-playwright.md` at your project root. This enforces the evidence protocol from §8, covers mobile/tablet/desktop, and uses Doherty threshold, WCAG 2.2 target size, and touch-target criteria.

````markdown
---
name: sd-playwright
description: >
  Performs responsive + WCAG 2.2 UX audits on a running web app using
  Playwright MCP. Use PROACTIVELY after any frontend change, or when the
  user says "audit", "UX review", "design review", "accessibility check",
  or "responsive test". Produces verified evidence: screenshots, snapshot
  YAML, computed styles, and a JSON findings file.
model: sonnet
permissionMode: acceptEdits
maxTurns: 80
color: cyan
mcpServers:
  - playwright
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - mcp__playwright__browser_navigate
  - mcp__playwright__browser_navigate_back
  - mcp__playwright__browser_resize
  - mcp__playwright__browser_snapshot
  - mcp__playwright__browser_take_screenshot
  - mcp__playwright__browser_evaluate
  - mcp__playwright__browser_click
  - mcp__playwright__browser_type
  - mcp__playwright__browser_hover
  - mcp__playwright__browser_press_key
  - mcp__playwright__browser_select_option
  - mcp__playwright__browser_wait_for
  - mcp__playwright__browser_console_messages
  - mcp__playwright__browser_network_requests
  - mcp__playwright__browser_handle_dialog
  - mcp__playwright__browser_tabs
  - mcp__playwright__browser_install
  - mcp__playwright__browser_close
---

# Role

You are a UX + accessibility auditor. You drive a real browser through the
Playwright MCP server and produce **verifiable evidence** of every finding.
You do NOT run Playwright via Bash, do NOT write a Playwright test file,
do NOT use curl. You use the `mcp__playwright__*` tools exclusively.

# Non-negotiable rules

1. **Say "Playwright MCP" literally** in any sub-invocation you make. Use
   only `mcp__playwright__*` tools for browser work.
2. **Every finding cites four things: [SHOT], [QUOTE], [SEL], [VAL].**
   Missing any one → you do not file the finding. You file the gap.
3. **Snapshots are per-call.** Every `[ref=eNN]` is valid for ONE action.
   Re-snapshot after any click, type, select, navigate, or waitFor.
4. **Save artifacts to disk BEFORE writing findings.json.** No exceptions.
5. **On JS console errors, stop auditing that page.** Record the errors
   verbatim and move to the next page.
6. **Dismiss cookie banners / consent modals FIRST** on every page, before
   you capture the canonical snapshot.
7. **Text waits, never time waits.** Use `browser_wait_for(text=…)` or
   `textGone=…`. Use `time=` only as a documented last resort.
8. **Sequential, not parallel.** Do not spawn parallel flows against the
   same Playwright MCP — tabs will collide.

# Evaluation criteria

## WCAG 2.2 focus points
- **1.4.3 Contrast (Minimum)** — text ≥ 4.5:1, large text ≥ 3:1
- **2.4.7 Focus Visible** — every interactive element has a visible focus ring
- **2.5.5 Target Size (AAA)** — interactive targets ≥ 44×44 CSS px
- **2.5.8 Target Size (Minimum, AA, new in 2.2)** — ≥ 24×24 CSS px
- **3.3.8 Accessible Authentication** — no memory puzzles
- **1.3.1 Info and Relationships** — headings in order; labels tied to inputs

## Performance & interaction
- **Doherty threshold (400 ms)** — any perceived response time over 400 ms
  from click to visible feedback is a finding. Measure with
  `performance.now()` via `browser_evaluate`.
- **Tap target spacing** — 8 px minimum between adjacent targets on mobile.
- **Scroll chaining / viewport overflow** — horizontal scroll at 375 px
  is a blocker.

## Visual polish
- Alignment within 2 px grid
- Consistent spacing scale (4/8/12/16/24/32/48/64)
- Typographic hierarchy (h1 > h2 > h3 size ratios obvious)
- Empty / loading / error states exist for every async view

# Standard flow

For each viewport ∈ [mobile 375×812, tablet 768×1024, desktop 1440×900]:
  For each page in the audit set:

  1. `browser_resize(width, height)` for the viewport.
  2. `browser_navigate(url)`.
  3. `browser_wait_for(text="<known copy on loaded page>")`.
  4. **Disable animations once** via `browser_evaluate` (style override).
  5. **Dismiss cookie banners** by snapshotting and clicking any node with
     role=button whose accessible name contains cookie/consent/accept/GDPR.
  6. `browser_console_messages(level="error")`. If non-empty, record and
     SKIP the rest of this page.
  7. `browser_snapshot({ filename: "audit/snapshots/{page}_{vp}.yaml" })`.
  8. `browser_take_screenshot({ fullPage: true,
        filename: "audit/screens/{page}_{vp}_full.png" })`.
  9. `browser_evaluate(...)` for computed styles of the key elements
     (headings, primary CTA, nav items, form fields). Save to
     `audit/styles/{page}_{vp}.json`.
  10. `browser_network_requests({ includeStatic: false })`. Record any
      failed requests (status ≥ 400) to `audit/network/{page}_{vp}.json`.
  11. For each issue found, append an entry to `audit/findings.json` with
      all four evidence fields.

# Findings schema (strict)

```json
{
  "id": "f-001",
  "page_url": "https://…",
  "viewport": { "name": "mobile", "w": 375, "h": 812 },
  "screenshot_path": "audit/screens/…png",       // SHOT
  "snapshot_path":   "audit/snapshots/…yaml",
  "snapshot_quote":  "- button \"…\" [ref=e87]",  // QUOTE (verbatim)
  "dom_selector":    "main>…",                    // SEL
  "computed_style_excerpt": { "…": "…" },         // VAL
  "wcag_criterion":  "2.5.5 Target Size (AAA)",
  "severity":        "blocker|high|medium|nitpick",
  "evidence_hex_fg": "#FFFFFF",
  "evidence_hex_bg": "#93C5FD",
  "evidence_contrast_ratio": 1.89,
  "evidence_px":     { "w": 88, "h": 36 },
  "finding":         "<one-sentence impact statement>"
}
```

# File outputs (produced BEFORE you return)

```
audit/
  findings.json          # JSON array, append-only
  SUMMARY.md             # Pages visited, viewports tested, findings table
  screens/               # PNG screenshots, one per page × viewport
  snapshots/             # Accessibility-tree YAML, one per page × viewport
  styles/                # Computed-style JSON per page × viewport
  network/               # Failed-request JSON per page × viewport
```

# Error handling

| Failure | Action |
|---|---|
| `ref=eNN` not found | Re-snapshot, re-identify by accessible name, retry. Don't guess selectors. |
| Two elements with same name | Include parent context in `element` parameter; pick ref nested under correct parent. |
| `browser_wait_for(text)` timeout | Dump `browser_console_messages`, then `browser_snapshot`, then retry with different text. |
| "No browser" | `browser_install` once, retry once. If still fails, stop and report. |
| Same step fails twice | **Stop.** Write failure + snapshot + console into findings, hand back to orchestrator. Do NOT fabricate success. |

# Final checks before returning

Run these Bash checks and do not return until they pass:

```bash
# 1. Every screenshot_path and snapshot_path in findings.json exists on disk.
jq -r '.[] | .screenshot_path, .snapshot_path' audit/findings.json | \
  while read p; do [ -s "$p" ] || { echo "MISSING: $p"; exit 1; }; done

# 2. Every snapshot_quote appears verbatim in its cited snapshot file.
jq -c '.[]' audit/findings.json | while read f; do
  q=$(echo "$f" | jq -r .snapshot_quote)
  s=$(echo "$f" | jq -r .snapshot_path)
  grep -qF "$q" "$s" || { echo "QUOTE NOT IN SNAPSHOT: $s"; exit 1; }
done

# 3. Every viewport × page pair produced a screenshot and snapshot.
```

If any check fails, fix the gap and re-verify. Do not return with gaps.
````

Pair this with an `.mcp.json` at project root:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@0.0.70",
               "--isolated",
               "--output-dir", "./audit/screens",
               "--image-responses", "omit",
               "--caps", "vision"]
    }
  }
}
```

And a `scripts/verify-audit.sh` containing the Bash block from §8.

---

## 12. Real working examples from the community

### Example 1 — OneRedOak/claude-code-workflows (the canonical ancestor)

Source: `github.com/OneRedOak/claude-code-workflows/tree/main/design-review`. Patrick Ellis's "elite design review specialist" prompt is the ancestor of essentially every design-review subagent on GitHub. Frontmatter:

```yaml
---
name: design-review
description: |
  Use this agent when you need to conduct a comprehensive design review on
  front-end pull requests or general UI changes. Requires a live preview
  environment and uses Playwright for automated interaction testing.
tools: Grep, LS, Read, Edit, Write, WebFetch, WebSearch, TodoWrite, Bash,
  mcp__playwright__browser_navigate, mcp__playwright__browser_click,
  mcp__playwright__browser_type, mcp__playwright__browser_resize,
  mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot,
  mcp__playwright__browser_console_messages, mcp__playwright__browser_hover,
  mcp__playwright__browser_select_option, mcp__playwright__browser_evaluate
model: sonnet
---
```

Seven-phase methodology: preparation (read PR diff, set 1440×900) → interaction/flow (hover, active, disabled, destructive-confirm) → responsiveness (1440/768/375) → visual polish → WCAG 2.1 AA → robustness (overflow, empty, error) → code health + console. Output is a triaged `### Findings` markdown with `#### Blockers`, `#### High-Priority`, `#### Medium-Priority`, `#### Nitpicks`.

**What it does well:** "Live Environment First" grounds every finding in real rendered behavior. The Blocker/High/Medium/Nitpick triage matrix plus "problems over prescriptions" communication style makes output reviewer-friendly. Always paired with a `/design-review` slash command and a `CLAUDE.md` design-principles block (Stripe/Airbnb/Linear).

**Weakness:** Tool list is very broad — it inherits mutating tools (click, type, file_upload) and Bash, so the subagent can act on the live app, not just audit it. Safe against an ephemeral preview env, risky against anything else.

### Example 2 — EricTechPro/match-me

Source: `github.com/EricTechPro/match-me/blob/main/.claude/agents/design-review-agent.md`. A real project-scoped fork of OneRedOak, with **Context7 MCP added** so the agent can pull framework docs while reviewing. Adds `mcp__context7__resolve-library-id`, `mcp__context7__get-library-docs`, plus the broader Playwright surface (`browser_tab_list`, `browser_tab_new`, `browser_file_upload`, `browser_handle_dialog`, `browser_network_requests`, `browser_press_key`, `browser_navigate_back/forward`, `browser_drag`, `browser_install`).

**Does well:** Context7 integration is a meaningful enrichment — the agent verifies design conventions against *current* framework docs (Next.js, Tailwind, shadcn) rather than its training cutoff. Broader Playwright surface lets it audit multi-tab flows and dialog-triggered paths.

**Weakness:** Essentially a verbatim fork — no domain specialization for the dating-app context. The expanded tool list consumes more context tokens without adding review sophistication.

### Example 3 — claude-code-community-ireland / vibeworks-library

Source: `github.com/claude-code-community-ireland/claude-code-resources/blob/main/plugins/vibeworks-library/agents/design-review.md`. Installable as a Claude Code plugin via the community plugin hub — distributes the OneRedOak prompt with clean tool discipline:

```yaml
---
name: design-review
description: Use this agent when you need to conduct a comprehensive design
  review on front-end pull requests or general UI changes...
model: sonnet
tools: Grep, LS, Read, Edit, MultiEdit, Write, NotebookEdit, WebFetch,
  TodoWrite, WebSearch
---
```

Playwright MCP tools are **not** listed in `tools:`; they're referenced contextually in the prompt body as "Technical Requirements" (`mcp__playwright__browser_navigate/click/type/select_option/take_screenshot/resize/snapshot/console_messages`). The declared surface is narrower, and the plugin packaging means teams install once and get updates without forking markdown.

**Does well:** Cleanest tool discipline of the three — frontmatter only whitelists generic Read/Write/Grep tools, with MCP access narrowed by the plugin runtime. Distributable via plugin hub for consistent team rollout.

**Weakness:** Low adoption (2 stars / 0 forks on parent repo), and prompt content is unchanged from OneRedOak — no plugin-specific value beyond the packaging.

### Cross-cutting observations

Community examples are **far less diverse than they appear** — virtually every `design-review` agent on GitHub traces back to OneRedOak. The fingerprints: "elite design review specialist" phrasing, Stripe/Airbnb/Linear framing, "Live Environment First" philosophy, seven-phase methodology, Blocker/High/Medium/Nitpick triage. Variations are limited to tool-list tweaks and packaging.

Common patterns worth adopting:
- **Three-viewport sweep** (1440 / 768 / 375) is universal and correct.
- **Non-mutating-first tool set**: `browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_resize`, `browser_console_messages` for observation; mutating tools (`click`, `type`, `select_option`) only for interaction testing.
- **Paired-artifact deployment**: subagent + `/design-review` slash command + CLAUDE.md design-principles — the subagent rarely stands alone.
- **`model: sonnet`** is standard (balance of vision reasoning and cost).

What's **missing** from all three — and what your shipping skill can improve on — is the **evidence protocol**. None of them require the four-piece SHOW-YOUR-WORK citation (screenshot + snapshot quote + selector + computed value), none write a machine-verifiable JSON findings file, and none have an orchestrator-side `verify-audit.sh` that stats the paths and greps the quotes. They trust the LLM's word. Your skill doesn't need to.

### Adjacent non-audit references

For test-authoring (not auditing), the `microsoft/playwright` repo itself ships `playwright-test-planner.agent.md`, `-generator.agent.md`, `-healer.agent.md` — these target E2E generation. Anthropic's official `anthropics/frontend-design` and `anthropics/webapp-testing` Skills cover adjacent generative/testing territory. As of April 2026, **no widely-adopted design-audit SKILL.md equivalent exists** — there's a clear opening for a shipping skill that does this properly.

---

## Takeaways: what actually ships

The one-line summary: **say "Playwright MCP" out loud in turn one; snapshot-don't-screenshot; text-waits-not-time-waits; pin a version (not `@latest`) in team configs; demand four pieces of evidence per finding and verify the files exist on disk before trusting the report.** Everything else — viewport tables, tool lists, env vars — is support material for those five moves.

The 2026 inflection is **Tool Search + Skills over MCP for long flows**. Microsoft themselves now recommend CLI-based Skills for coding agents precisely because loading 25 Playwright tool schemas plus inline snapshots blows through 100K tokens on a 30-step audit. For **interactive, ad-hoc UX review**, MCP is still right — the accessibility-tree model gives you deterministic `ref=eNN` targeting that no CLI invocation does. For **long automated runs or CI**, consider swapping MCP for `@playwright/cli` inside a Skill.

And the gap worth closing in your shipping skill: nobody in the community enforces orchestrator-side evidence verification. `scripts/verify-audit.sh` — stat the paths, grep the quotes — is a fifteen-line defense that makes the agent verifiably honest. That's the piece worth investing in.