# The super-design audit reference: maximum depth methodology for live website evaluation

This reference consolidates professional web design, UX, and accessibility audit methodology into a single actionable document for the `super-design` Claude Code skill. It covers Nielsen's heuristics with audit-ready checklists, the full WCAG 2.2 AA requirement set plus classical most-failed criteria, Baymard's e-commerce findings, Core Web Vitals measurement code, expert "implicit" criteria senior designers catch, tool capabilities and limits, real-device vs emulation realities, and a synthesized phase-by-phase audit checklist. Every claim is tied to a primary source.

---

## 1. Nielsen's 10 usability heuristics as a practical checklist

**Primary source (canonical summary):** https://www.nngroup.com/articles/ten-usability-heuristics/ — Jakob Nielsen, originally April 24, 1994; wording refined in the 2020 rewrite; article last refreshed Jan 30, 2024. Nielsen: *"While we slightly refined the language of the definitions, the 10 heuristics themselves have remained relevant and unchanged since 1994."*

### 1.1 Visibility of system status
**Verbatim:** *"The design should always keep users informed about what is going on, through appropriate feedback within a reasonable amount of time."* **NN/g article:** https://www.nngroup.com/articles/visibility-system-status/

**Audit questions (live-site):** (1) After every click/submit/drag, does UI acknowledge within ~1s (Nielsen's 0.1 / 1 / 10s limits)? (2) For >1s operations, is a determinate progress indicator or skeleton shown? For >10s, ETA? (3) Is user's IA location always visible (breadcrumbs, active nav, step X of Y)? (4) Do controls show persistent state (selected, focused, disabled, loading, error)? (5) After async actions is there a success/failure confirmation?

**Failures in the wild:** "Place Order" button with no feedback for 3s causes double-submit duplicate orders; 500MB upload showing an indeterminate spinner with no % / ETA; multi-step wizard with no "Step 2 of 5" indicator; toggle flips instantly but persist takes 2s with no "Saving…/Saved".

**Severity examples (0–4):** 0 = branded pulse vs standard spinner (evaluator disagrees). 1 = toast uses slightly inconsistent icon size. 2 = "Saved" confirmation disappears in 800ms. 3 = async button gives no feedback for 3s allowing duplicate submission. 4 = background sync fails silently causing repeated data loss.

### 1.2 Match between system and the real world
**Verbatim:** *"The design should speak the users' language. Use words, phrases, and concepts familiar to the user, rather than internal jargon. Follow real-world conventions, making information appear in a natural and logical order."* **Article:** https://www.nngroup.com/articles/match-system-real-world/

**Audit questions:** (1) Do labels/errors use domain vocabulary, not engineering terms (SKU, entity, null, 404, transaction_id)? (2) Do metaphorical icons match real-world expectations and carry text labels? (3) Are dates/times/currency/units localized? (4) Does information order match mental models (cart → shipping → payment → review)? (5) Do controls map spatially/directionally (up=louder, left=back)?

**Failures:** "Exception: FK constraint violated on table user_orders_v2" shown to end user; banking labels "ACH Pull" instead of "Transfer from another bank"; UK site showing USD + MM/DD/YYYY; unlabeled abstract seat-map icons for lavatory/galley/exit row.

**Severity examples:** 0 = "dashboard" vs "home" (disagree). 1 = "utilize" instead of "use" in tooltip. 2 = "SKU" / "GTIN" in a consumer filter. 3 = "Payment gateway 402 declined — code PG_INS_FUNDS" at checkout. 4 = medication tool uses raw DB column names causing dosing errors.

### 1.3 User control and freedom
**Verbatim:** *"Users often perform actions by mistake. They need a clearly marked 'emergency exit' to leave the unwanted action without having to go through an extended process."* **Article:** https://www.nngroup.com/articles/user-control-and-freedom/

**Audit questions:** (1) Can every destructive action be undone (Gmail-style Undo toast, trash recovery)? (2) Does every modal/wizard have a discoverable Cancel/Close that doesn't submit data? (3) Does browser Back work without losing state or showing "confirm resubmission"? (4) Can users exit autoplay / full-screen takeovers without completing them? (5) In multi-step flows, can users navigate backward without losing entered data?

**Failures:** Email client with no Undo Send; signup modal with X grayed out until all fields complete; cookie banner with hidden "Reject"; checkout clearing cart on Back; 15s unskippable ad.

**Severity:** 0 = 24×24 close hit target. 1 = Cancel button uses faded secondary style. 2 = Undo toast visible only 3s. 3 = "Delete account" with no confirmation and no undo. 4 = Financial transfer with no cancel once Send pressed.

### 1.4 Consistency and standards
**Verbatim:** *"Users should not have to wonder whether different words, situations, or actions mean the same thing. Follow platform and industry conventions."* **Article:** https://www.nngroup.com/articles/consistency-and-standards/

**Audit questions:** (1) Is the same action labeled identically everywhere? (2) Are primary buttons, icons, colors, typography visually consistent? (3) Do industry standards hold (logo top-left, cart top-right, search magnifier, required *)? (4) Are interaction patterns consistent (same drag handle, same hover, same error style)? (5) Do OS/platform conventions hold (iOS share sheet, Android back gesture, Cmd+C on Mac)?

**Failures:** "Submit" / "Send" / "Save" used interchangeably for the same confirm action; primary CTA green on product, blue at checkout, orange on account; search top-right on desktop but hidden in mobile hamburger; modals dismissing inconsistently (ESC / X / only via form completion).

**Severity:** 0 = intentional brand variation across sections. 1 = 4px vs 6px shadows on cards. 2 = "Log out" labeled "Sign out" on mobile. 3 = primary/secondary buttons reversed at checkout inflating drop-off. 4 = Delete button styled as primary-blue elsewhere meaning "Save" causing habitual deletes.

### 1.5 Error prevention
**Verbatim:** *"Good error messages are important, but the best designs carefully prevent problems from occurring in the first place. Either eliminate error-prone conditions, or check for them and present users with a confirmation option before they commit to the action."* **Article (canonical deep dive):** https://www.nngroup.com/articles/slips/

**Audit questions:** (1) Do forms validate inline (email, password strength, ZIP length) instead of only after submit? (2) Are destructive actions behind confirmation with clear consequence ("This will permanently delete 47 files")? (3) Do inputs use constrained controls (date pickers, dropdowns, autocomplete) where data is structured? (4) Are good defaults pre-selected (country, currency, quantity=1)? (5) Do inputs prevent invalid content where possible (numeric keypad for phone, card masks, disabled Submit while invalid)?

**Failures:** Password "123" accepted until submit clears the password field; "Delete project" with no confirmation; free-text date accepting 02/30/2026; one-click email unsubscribe triggered by preview tap.

**Severity:** 0 = first-name capitalization (disagree). 1 = no country autocomplete. 2 = quantity=0 accepted; user notices. 3 = CC accepts any 16-digit string; server rejects and clears the field. 4 = hospital dosing form accepts negative/non-numeric values.

### 1.6 Recognition rather than recall
**Verbatim:** *"Minimize the user's memory load by making elements, actions, and options visible. The user should not have to remember information from one part of the interface to another. Information required to use the design (e.g. field labels or menu items) should be visible or easily retrievable when needed."* **Article:** https://www.nngroup.com/articles/recognition-and-recall/

**Audit questions:** (1) Do fields have persistent labels (not placeholder-only)? (2) Does the system autofill/remember/suggest previous values? (3) Are menu items and key actions continuously visible rather than hidden behind gestures? (4) In multi-step flows are previous choices summarized? (5) Does the site require memorized codes/IDs that could be selectable?

**Failures:** Retyping email/shipping/billing on three separate screens; placeholder-only labels vanishing on focus; quote-the-previous-error-code with no back-without-loss; command-palette-only app with no menu.

**Severity:** 0 = product tour uses brief tooltip sequence. 1 = tooltip only on hover, no focus. 2 = Recently Viewed cleared on logout. 3 = selected filters not carried to next page. 4 = user must memorize generated 16-char order ID with no copy button and no carryover.

### 1.7 Flexibility and efficiency of use
**Verbatim:** *"Shortcuts — hidden from novice users — may speed up the interaction for the expert user so that the design can cater to both inexperienced and experienced users. Allow users to tailor frequent actions."* **Article:** https://www.nngroup.com/articles/flexibility-efficiency-heuristic/

**Audit questions:** (1) Keyboard shortcuts for frequent tasks (Cmd+K, "?", ESC)? (2) "Recently used" / favorites / pinned surfaces? (3) Can content/features be personalized (reorder widgets, saved filter sets, default views)? (4) Multiple ways to complete key tasks (drag + button, keyboard + mouse)? (5) Bulk actions for repetitive tasks (select-all, multi-edit, CSV import/export)?

**Failures:** Admin deletes 200 records one at a time with no multi-select; no j/k or Cmd+Enter in email client; search without history memory; project tool with no saved views.

**Severity:** 0 = absent rarely-used shortcut. 1 = "?" help overlay inconsistent symbol casing. 2 = ESC doesn't close modal consistently. 3 = no "Save as template" for 10-step report. 4 = customer-service refund requires 25 clicks with no macro.

### 1.8 Aesthetic and minimalist design
**Verbatim:** *"Interfaces should not contain information that is irrelevant or rarely needed. Every extra unit of information in an interface competes with the relevant units of information and diminishes their relative visibility."* **Article:** https://www.nngroup.com/articles/aesthetic-minimalist-design/

**Audit questions:** (1) On each key screen, is the primary goal the most visually dominant element? (2) Are there redundant CTAs, duplicate nav, decorative images, marketing modules distracting from task? (3) Is visual hierarchy established by size/weight/color/spacing? (4) Do popups/cookie/chat/promos obscure primary content? (5) Is copy scannable and free of jargon?

**Failures:** Checkout with 4 promo modules + chat + upsell + newsletter obscuring "Place Order"; PDP with three equally prominent CTAs; dashboard with 20 metrics competing; blog buried under autoplay video + sticky chrome + sidebar ads + chat bubble + cookie banner.

**Severity:** 0 = decorative hero illustration (disagree). 1 = unused "Coming soon" banner. 2 = three near-duplicate nav links. 3 = upsell carousel pushes "Place Order" below fold on 13" laptops; measurable conversion drop. 4 = login screen with full-screen popup hiding the login form entirely.

### 1.9 Help users recognize, diagnose, and recover from errors
**Verbatim:** *"Error messages should be expressed in plain language (no error codes), precisely indicate the problem, and constructively suggest a solution."* **Article:** https://www.nngroup.com/articles/error-message-guidelines/

**Audit questions:** (1) Do errors state what went wrong + why + a concrete next step — all three? (2) Are errors visually distinguishable (red + icon + text), positioned near the offending field, and announced to AT (`role="alert"` / `aria-live`)? (3) Are raw technical errors (stack traces, HTTP codes) ever shown? (4) On 404/500 pages, are recovery options present (search, home, contact)? (5) Does validation preserve entered data and highlight specific invalid fields?

**Failures:** "Invalid credentials" not saying which is wrong and with no "Reset password" inline; "Error 500: NullReferenceException at line 2847"; 404 "Not found" with no search/home; full-form submit error that clears 20 fields; "Declined" payment with no reason or retry.

**Severity:** 0 = HTTP code alongside plain message (disagree). 1 = slight icon misalignment. 2 = "Please check your input" (vague but recoverable). 3 = "Payment failed" without reason causing repeat retries. 4 = 500 that both wipes form AND exposes stack trace.

### 1.10 Help and documentation
**Verbatim:** *"It's best if the system doesn't need any additional explanation. However, it may be necessary to provide documentation to help users understand how to complete their tasks."* **Article:** https://www.nngroup.com/articles/help-and-documentation/

**Audit questions:** (1) Is help searchable with relevant ranking? (2) Is contextual help at the point of need (tooltips, inline "?"), not only in a separate center? (3) Are articles task-oriented ("How to cancel a subscription") with numbered steps + screenshots? (4) Is the path to human support obvious (not buried 5 clicks deep)? (5) Is documentation current (last-updated date, no old screenshots)?

**Failures:** "API rate limit window" setting with no tooltip; help search returns marketing pages; screenshots from two redesigns ago; "Contact us" behind 4 clicks; 3,000-word essays without numbered steps.

**Severity:** 0 = obvious feature needs no tooltip. 1 = last-updated date at bottom. 2 = search doesn't handle typos. 3 = no in-context help for compliance field. 4 = enterprise admin tool with no docs causing repeated outages.

### 1.11 Nielsen's severity ratings (0–4)
**Primary source:** https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/

**Verbatim formula:** *"The severity of a usability problem is a combination of three factors: The **frequency** with which the problem occurs… The **impact** of the problem if it occurs… The **persistence** of the problem."* Plus **market impact** is considered separately.

**Verbatim scale:** 0 = *"I don't agree that this is a usability problem at all."* 1 = *"Cosmetic problem only: need not be fixed unless extra time is available on project."* 2 = *"Minor usability problem: fixing this should be given low priority."* 3 = *"Major usability problem: important to fix, so should be given high priority."* 4 = *"Usability catastrophe: imperative to fix this before product can be released."*

**Operationalizing for an automated tool:** Nielsen does not publish a numeric multiplication; he describes combining factors into a single rating. A defensible implementation scores each of Frequency / Impact / Persistence on 0–2, sums to a 0–6 pre-score, maps to 0–4, and bumps upward for high market impact. Always aggregate **mean of ≥3 independent evaluators** (or 3+ signals) per Nielsen's reliability guidance. Separate the "find" pass from the "rate" pass.

---

## 2. WCAG 2.2 audit checklist

**Standard:** W3C Recommendation, published **5 October 2023** (updated 12 Dec 2024). ISO/IEC 40500:2025. Adds 9 new SCs, removes 4.1.1 Parsing. Total SC count: 86 (2.1 had 78). Backward-compatible with 2.1 / 2.0.

**Primary sources:** https://www.w3.org/TR/WCAG22/ · https://www.w3.org/WAI/WCAG22/Understanding/ · https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/

### 2.1 New and updated success criteria in WCAG 2.2

**2.4.11 Focus Not Obscured (Minimum) — AA.** *"When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content."* Understanding: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum. Automate: axe-core has experimental rule (only WCAG 2.2 SC with substantial automation per TPGi). Manual: Tab forward AND Shift+Tab backward through all pages at multiple breakpoints; verify focused controls are at least partly visible. **Fail (F110):** sticky footer with `position:fixed; bottom:0; height:120px; z-index:100` covering focused links. **Pass (C43):** `html { scroll-padding-bottom: 120px; scroll-padding-top: 80px; }`.

**2.4.12 Focus Not Obscured (Enhanced) — AAA.** Stronger: *"no part of the component is hidden by author-created content."* No exceptions. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-enhanced

**2.4.13 Focus Appearance — AAA.** Focus indicator must be *"at least as large as the area of a 2 CSS pixel thick perimeter"* AND *"a contrast ratio of at least 3:1 between the same pixels in the focused and unfocused states."* Exceptions: UA-determined or author-unmodified indicator/background. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance. **Fail:** `*:focus { outline: none; }`, `outline: 1px solid #999;`, `outline: 2px solid #eee` on white (1.1:1). **Pass:** `:focus-visible { outline: 2px solid #005fcc; outline-offset: 2px; }`.

**2.5.7 Dragging Movements — AA.** All functionality that uses a dragging movement must be achievable with single-pointer non-dragging alternative unless dragging is essential (signature, drawing) or UA-determined. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements. Keyboard alternative is NOT sufficient (touch-only users). **Fail:** `<li draggable="true">` list with no alternative. **Pass:** up/down buttons per item; sliders with ± steppers or numeric input.

**2.5.8 Target Size (Minimum) — AA.** *"The size of the target for pointer inputs is at least 24 by 24 CSS pixels"* except for five exceptions: **Spacing** (24px-diameter circles centered on targets do not intersect), **Equivalent** (another compliant control exists on same page), **Inline** (target in a sentence / line-height constrained), **User agent control** (unstyled browser widget), **Essential** (size legally or functionally required, e.g., dense map pins). Understanding: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum. CSS pixels do NOT change with zoom — can't satisfy via "user can zoom." Automate: axe `target-size` rule; partial for spacing exception. **Pass patterns:** `button { min-width: 24px; min-height: 24px; padding: 6px; }` or visually smaller icons with padded 24×24 hit area, or 20×20 icons with 4px margin (center-to-center 28px satisfying spacing exception).

**3.2.6 Consistent Help — A.** If help mechanisms (human contact details, contact mechanism, self-help option, fully automated contact) are repeated across pages, they occur in the same relative DOM order unless user initiates a change. Does NOT require providing help — only consistent location if provided. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help

**3.3.7 Redundant Entry — A.** Information previously entered in the same process is either auto-populated or available for selection, except when re-entry is essential (password confirmation), security-related (passwords), or previously entered data is no longer valid. Browser autocomplete is NOT sufficient — the site must provide it. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry. **Pattern:** "Billing same as shipping" checkbox default-checked with editable prefilled fields.

**3.3.8 Accessible Authentication (Minimum) — AA.** No cognitive function test (remember password, transcribe OTP, puzzle, CAPTCHA) unless at least one of: Alternative (different method), Mechanism (paste + password-manager support), Object Recognition, or Personal Content exception. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum. **Fail:** `<input type="password" onpaste="return false;" autocomplete="off">`. **Pass:** proper `autocomplete="username"` / `"current-password"` / `"one-time-code"` tokens, paste allowed, passkey or magic-link alternative.

**3.3.9 Accessible Authentication (Enhanced) — AAA.** Removes Object Recognition and Personal Content exceptions — CAPTCHAs like "select all crosswalks" fail AAA even without alternative. Passkeys, WebAuthn, biometrics, magic links pass. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-enhanced

**Removed: 4.1.1 Parsing** (was A in 2.0/2.1). W3C rationale: *"Assistive technology no longer has any need to directly parse HTML."* Concerns now covered by 4.1.2 (duplicate IDs referenced by ARIA), 1.3.1 (structural issues), 2.1.1 / 2.4.3 (misnested interactive elements). axe-core deprecated `duplicate-id` and `duplicate-id-active`; kept `duplicate-id-aria` under 4.1.2.

### 2.2 Classical most-failed Level A/AA criteria (from WebAIM Million 2026)

The 2026 WebAIM Million report (released ~30 March 2026, https://webaim.org/projects/million/) reveals a **reversal** after 6 years of gradual improvement: 95.9% of home pages have detectable failures (up from 94.8% in 2025), 56.1 average errors/page (up from 51.0), 133.5M ARIA attributes detected (6× 2019). Authors attribute the reversal to rising DOM complexity + AI-assisted "vibe coding" + 3rd-party frameworks. Pages using ARIA average **59.1 errors** vs 42 without.

**Top 6 failures (2026 — constant 7 years):** Low contrast text **83.9%** (1.4.3); missing alt **53.1%** (1.1.1); missing form labels **51.0%** (1.3.1 / 3.3.2 / 4.1.2); empty links **46.3%** (2.4.4 / 4.1.2); empty buttons **30.6%** (4.1.2); missing document language **13.5%** (3.1.1). These 6 issues = 96% of all detected errors.

**1.1.1 Non-text Content (A).** Every `<img>`, `<svg>`, `<canvas>`, CSS background conveying info, `<input type="image">`, icon fonts needs appropriate text alternative: decorative → `alt=""` / `role="presentation"`; informative → equivalent; functional → describe action/destination; complex → short alt + long description. Automated catches presence only. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html. 10.8 missing-alt images per page average; 10.8% of existing alt is questionable (filenames, `"image"`, duplicates).

**1.3.1 Info and Relationships (A).** Structure, labels, table markup, landmarks programmatically determinable. Automated catches structural violations but not semantic appropriateness. Manual: disable CSS — reading order still sensible? Headings hierarchical? `<label for>` associations? `<th scope>` + `<caption>`? `<ul>/<ol>/<li>` not bulleted divs? Fieldsets with legends for radio groups? Understanding: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html. 41.8% pages skip heading levels; 18.1% have multiple h1; only 19% of tables properly marked up.

**1.4.3 Contrast (Minimum) (AA).** 4.5:1 body text, 3:1 for large text (≥18pt / 24px normal OR ≥14pt / 18.66px bold). Exemptions: inactive/decorative/invisible/logos. Automated coverage strong on static text; weaker for: gradient/image/video backgrounds, semi-transparent overlays, runtime CSS custom properties, text in `<canvas>`/`<svg>`. Check all states (hover/focus/active/visited). 30% of all automated issues; avg 34 instances per page. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html

**1.4.10 Reflow (AA).** Content at 320 CSS px without 2D scroll except tables/maps/code. Zero automated coverage. Manual: viewport 320×256 OR 1280px @ 400% zoom. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html

**1.4.11 Non-text Contrast (AA).** 3:1 against adjacent colors for UI component boundaries/states and meaningful graphics. Limited automation (tools can't reliably identify "required to understand"). Check custom input borders (`border: 1px solid #ccc` = 1.6:1 = fail), focus rings, icons without labels, chart bars/lines. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html

**1.4.12 Text Spacing (AA).** Must retain all content/function when user overrides: line-height 1.5×, paragraph spacing 2×, letter 0.12×, word 0.16×. No automation — inject CSS via bookmarklet and inspect. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html

**2.1.1 Keyboard (A) + 2.1.2 No Keyboard Trap.** All functionality operable via keyboard; focus must escape any component it enters. Automation detects trivial tabindex abuse and div-as-button; cannot verify real behavior. Manual: unplug mouse, Tab/Shift-Tab whole page, test custom widgets against WAI-ARIA APG. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html. **Fail:** `<div onclick="submit()">Submit</div>`, `<input tabindex="5">`.

**2.4.3 Focus Order (A).** Sequential focus preserves meaning and operability. Minimal automation (positive tabindex flag). CSS `order:`, `flex-direction: row-reverse`, `grid-area` can decouple DOM from visual order silently — always run Adrian Roselli's reading-order bookmarklet on flex/grid sections. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html

**2.4.4 Link Purpose (In Context) (A).** Purpose determinable from link text + programmatic context. Automation detects empty links and "click here" / "more" (WAVE). Empty links on 46.3% of pages; ambiguous link text on 15.2%. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html

**2.4.7 Focus Visible (AA).** Keyboard focus indicator has a visible mode. Very limited automation. Check for `outline: none` without replacement `:focus-visible`. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html

**3.3.1 Error Identification (A).** Detected input error identified and described in text. Minimal automation (can check `aria-invalid`/`aria-describedby` presence, not message quality). Understanding: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html. **Fail:** red border alone with no text, or generic "Invalid input".

**3.3.2 Labels or Instructions (A).** 51% of pages have unlabeled inputs; 33.1% of form inputs unlabeled. Automation strong on label presence (axe `label`, `form-field-multiple-labels`), weak on instruction adequacy. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html

**4.1.2 Name, Role, Value (A).** One of the best-automated criteria (axe: `button-name`, `link-name`, `input-button-name`, `aria-valid-attr-value`, `aria-allowed-role`, `aria-toggle-field-name`). Custom widgets must announce name + role + state (`aria-checked`, `aria-pressed`, `aria-expanded`, `aria-selected`). Empty buttons on 30.6% of pages. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

**4.1.3 Status Messages (AA).** Polite/assertive live regions announce dynamic updates without moving focus. Very limited automation (presence only). Live region must exist at page load, not created-on-demand. Use `role="status"` / `aria-live="polite"` for non-urgent; `role="alert"` / `aria-live="assertive"` for errors. Understanding: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

### 2.3 Automation coverage: the 57% / 40–70% gap

**Deque's canonical study** (2,000+ audits, 13,000+ pages, ~300,000 issues): **axe-core finds 57.38% of total WCAG issues by volume.** Only 16 of 50 WCAG 2.1 AA SCs have any automated coverage (~32% by SC count), but those account for the lion's share of real-world issues. Combined with Intelligent Guided Testing, ~80%. Sources: https://www.deque.com/automated-accessibility-coverage-report/ · https://accessibility.deque.com/hubfs/Accessibility-Coverage-Report.pdf

**Tool coverage matrix:**

| Tool | Engine | Rules | CI integration | Strength |
|---|---|---|---|---|
| axe-core | Deque | ~96 | npm, Playwright, Puppeteer, WDIO, Cypress, CLI | 57% coverage; zero false-positive focus |
| Lighthouse | axe-core subset | ~57 | DevTools, CLI, LH CI, PSI API | Weighted score, integrated |
| WAVE | WebAIM | ~100+ icons | Extension + stand-alone API | In-context overlay; contrast slider |
| Pa11y | htmlcs + axe runners | variable | pa11y-ci, CI systems | CLI-first CI |
| IBM Equal Access | IBM | ~140 | npm, Cypress, Karma, Selenium, Puppeteer | ACT-rule aligned; baseline diffing |

**What automation CANNOT catch** (the manual 40–70%): keyboard trap detection beyond trivial cases; screen-reader announcement quality; meaningful alt text (tools detect missing, not quality); logical focus order when CSS reorders; error message clarity; appropriate heading structure (presence vs meaning); context-appropriate link text; video caption accuracy/sync; color meaning (1.4.1); reading order under CSS transforms; reflow at 320px (no tool); text-spacing override; focus-indicator quality (2.4.11 / 2.4.13); `prefers-reduced-motion` honoring; target size / spacing (partial); autocomplete correctness; captcha alternatives; content-on-hover persistence (1.4.13); page title descriptiveness; consistent navigation/identification (3.2.3 / 3.2.4).

### 2.5 Tool triangulation for automated a11y (MANDATORY)

axe-core alone catches only ~57% of WCAG issues by volume (Deque's own
coverage study) and ~40% by Success Criterion count. Running a single
engine guarantees blind spots. sd-audit MUST run axe **plus** at least two
more engines and dedupe the merged results by `{rule, selector}`.

**Engines to run in parallel (don't serialize — they're cheap):**

```bash
# 1. axe-core — inject via Playwright MCP (already done in sd-audit Step 2,
#    with `experimental: true` so WCAG 2.2 rules fire).

# 2. Pa11y — runs both htmlcs and axe runners for broader coverage
pa11y "$URL" \
  --standard WCAG2AA \
  --runner axe \
  --runner htmlcs \
  --reporter json \
  > "$SESSION_DIR/a11y/pa11y_<slug>_<vp>.json"

# 3. WAVE API — WebAIM's detector, overlay-oriented, strong on contrast and ARIA
curl -s "https://wave.webaim.org/api/request?key=$WAVE_KEY&url=$(printf %s "$URL" | jq -sRr @uri)&reporttype=4" \
  > "$SESSION_DIR/a11y/wave_<slug>_<vp>.json"

# 4. IBM Equal Access Accessibility Checker — ACT-rule aligned, ~140 rules
achecker "$URL" \
  --reportLevel violation,potentialviolation \
  --outputFormat json \
  --outputFolder "$SESSION_DIR/a11y/achecker_<slug>_<vp>/"
```

**Dedup and severity normalization:**

```js
// Pseudocode — run in sd-audit Step 3a after parsing all engine outputs.
const key = (f) => `${f.rule}::${f.selector}`;
const bucket = new Map();
for (const engine of ['axe', 'pa11y', 'wave', 'achecker']) {
  for (const f of findings[engine]) {
    const k = key(f);
    if (!bucket.has(k)) bucket.set(k, { ...f, engines: [] });
    bucket.get(k).engines.push(engine);
  }
}
// Confidence ladder:
//   engines.length === 1 → single-source, keep but tag "unverified"
//   engines.length >= 2 → triangulated, high confidence
//   engines.length >= 3 → near-certain, promote severity +1 step
```

**Why each engine is non-redundant:**
- **axe-core** — strongest on `4.1.2`, `1.4.3`, `1.1.1`, `1.3.1` subsets; experimental flag gates 2.2.
- **Pa11y** — htmlcs runner catches rule shapes axe doesn't ship; dual-runner mode is unique.
- **WAVE** — contrast slider tool + in-context overlay; different heuristics for ARIA landmarks; never marks a page "passed" (useful bias — never false-clean).
- **IBM Equal Access** — ACT-Rules aligned (different normative base than axe); baseline-file regression; severity categories (`violation / potentialviolation / recommendation / manual`) map onto Nielsen 0–4.

Record per-finding `source_engines: [...]` so sd-synthesis can promote
triangulated issues and down-weight single-engine noise.

### 2.4 Regulatory context

**European Accessibility Act** (Directive (EU) 2019/882) enforceable **28 June 2025** for new products/services; 28 June 2030 deadline for pre-existing. References **EN 301 549** (currently WCAG 2.1 AA baseline; being updated to 2.2). Extraterritorial.

**ADA Title II DOJ Final Rule** (24 April 2024; effective 24 June 2024): WCAG 2.1 AA for US state/local government websites, mobile apps, digital content. Deadlines: 24 April 2026 (≥50,000 population); 26 April 2027 (<50,000 + special districts).

**WCAG 3.0 ("Silver")** is W3C Working Draft, not backwards compatible; new structure (guidelines → outcomes → methods → tests), bronze/silver/gold conformance. Not expected as Recommendation until after 2028. WCAG 2.2 remains in force. Per W3C: 2.2 "culminates the final edition in the WCAG 2 line of normative requirements."

---

## 3. Baymard Institute e-commerce UX findings

Baymard (Copenhagen, founded ~2009) is used by 71% of Fortune 500 e-commerce companies. Research: 54 rounds of benchmarking, 327 top-grossing US/EU sites, 275,000+ manually assigned UX performance scores, 200,000+ research hours. Methodology page: https://baymard.com/research/methodology. Headline finding: the average large e-commerce site can gain **+35.26% conversion** through better checkout design — **$260B** in recoverable US+EU orders.

### 3.0 Baymard sub-rule enumeration (finding code prefixes)

The single blanket "Baymard" verdict is too coarse for a structured audit.
Baymard organises findings by **surface** (checkout, PDP, search, etc.) and
each surface has a bounded, enumerable set of sub-rules. Every Baymard
finding raised by sd-audit MUST use one of the prefixes below so
sd-synthesis can group them and so the fix-playbook can route to the right
U-template. Rules that do not yet have an official Baymard number are
prefixed by count only (e.g. `baymard-cc-01` … `baymard-cc-14`) with the
source section cited.

| Surface | Prefix | Count | Source (methodology §) |
|---|---|---|---|
| Credit card form | `baymard-cc-<NN>` | 14 rules | §3.3 + https://baymard.com/checkout-usability/credit-card-patterns |
| Address form | `baymard-addr-<NN>` | 8 rules | §3.4 + https://baymard.com/blog/address-line-2 + https://baymard.com/blog/automatic-address-lookup |
| Search | `baymard-search-<NN>` | 12 rules | §3.6 + https://baymard.com/ecommerce-design-examples/34-autocomplete-suggestions |
| Filter | `baymard-filter-<NN>` | 10 rules | §3.6 + https://baymard.com/blog/promoting-product-filters + https://baymard.com/blog/have-filters-for-list-item-info |
| Breadcrumbs | `baymard-bread-<NN>` | 6 rules | §3.7 + https://baymard.com/blog/ecommerce-breadcrumbs |
| PDP / Product Detail | `baymard-pdp-<NN>` | 18 rules | §3.8 + https://baymard.com/research/product-page |

**`baymard-cc-*` — Credit card form (14 rules, §3.3):**
1. `baymard-cc-01` auto-format spaces per card brand (4-4-4-4 / 4-6-5 AMEX / 4-4-4-4-3 19-digit)
2. `baymard-cc-02` auto-detect card type via IIN ranges (adapt length limit, CVV help, spacing)
3. `baymard-cc-03` expiration as single MM/YY field with auto-inserted slash (NOT YYYY, NOT two dropdowns)
4. `baymard-cc-04` CVV field with adaptive help image (3-digit back for Visa/MC, 4-digit front for AMEX)
5. `baymard-cc-05` autocomplete tokens present: `cc-number`, `cc-name`, `cc-exp`, `cc-exp-month`, `cc-exp-year`, `cc-csc`
6. `baymard-cc-06` `inputmode="numeric"` (never `type="number"`) on card number, expiration, CVV
7. `baymard-cc-07` never clear CC number/CVV on validation error (preserve entered data)
8. `baymard-cc-08` stored-card edit uses "fake editing" (delete + re-add) per PCI; clear messaging
9. `baymard-cc-09` inline validation with 5%-abandonment guardrail (no vague "Card declined" without reason)
10. `baymard-cc-10` fallback entry path when wallet (Apple Pay / Google Pay) fails
11. `baymard-cc-11` accept pasted numbers; strip spaces/dashes server+client
12. `baymard-cc-12` surface accepted card brands near the input (logo strip) before submit
13. `baymard-cc-13` billing-address reuse: "Billing same as shipping" default-checked with editable prefill
14. `baymard-cc-14` error messages identify which field failed + how to fix (not "Payment failed")

> Source: §3.3 bullets + https://baymard.com/checkout-usability/credit-card-patterns. Rules 10–14 derived from §3.3 narrative; number them in this table and supersede with Baymard's official IDs when available.

**`baymard-addr-*` — Address form (8 rules, §3.4):**
1. `baymard-addr-01` country selector FIRST (drives all subsequent field formats/validation)
2. `baymard-addr-02` single "Address Line 1" + optional "Address Line 2" labeled "Apt, Suite — optional" (never omit Line 2)
3. `baymard-addr-03` automatic address autocomplete preferred (9% manual-entry typo rate without it)
4. `baymard-addr-04` postal-code autodetect of city/state (28% mobile sites fail)
5. `baymard-addr-05` US state as dropdown (not free text); UK optional county; hide for countries without subdivisions
6. `baymard-addr-06` autocomplete tokens: `street-address`, `address-line1`, `address-line2`, `address-level1/2`, `postal-code`, `country`
7. `baymard-addr-07` "Billing same as shipping" default-checked with editable prefilled fields (also WCAG 3.3.7 Redundant Entry)
8. `baymard-addr-08` name inputs accept Unicode, hyphens, apostrophes, single-name users, >20 chars

> Source: §3.4.

**`baymard-search-*` — Search (12 rules, §3.6):**
1. `baymard-search-01` persist search query in the field after submission
2. `baymard-search-02` autocomplete list capped at 10 items desktop, 4–8 mobile
3. `baymard-search-03` style category-scope suggestions distinctly within autocomplete
4. `baymard-search-04` highlight the predictive (un-typed) portion of autocomplete suggestions
5. `baymard-search-05` copy active autocomplete suggestion into the field on keyboard navigation
6. `baymard-search-06` support misspellings in autocomplete (spell-tolerant suggestions)
7. `baymard-search-07` autodirect exact category-match queries to the category page
8. `baymard-search-08` support synonym and alternate-term searches
9. `baymard-search-09` support abbreviation and symbol searches
10. `baymard-search-10` allow "search within" current category on mobile
11. `baymard-search-11` support non-product queries (return policy, order status, FAQ)
12. `baymard-search-12` provide 5 proven no-results recovery paths (spelling fix, broaden, contact, etc.)

> Source: §3.6 bullets + https://baymard.com/ecommerce-design-examples/34-autocomplete-suggestions + per-rule URLs in `/docs/research/baymard-public-rules.md` (B-S-01…B-S-12).

**`baymard-filter-*` — Filter (10 rules, §3.6):**
1. `baymard-filter-01` provide the 5 essential filter types (category, price, rating, brand, user-relevant attribute)
2. `baymard-filter-02` have filters for every attribute displayed in list items
3. `baymard-filter-03` display applied filters in a visible overview area, individually removable
4. `baymard-filter-04` use OR logic within a facet, AND logic across facets
5. `baymard-filter-05` show product counts per filter value and update them dynamically
6. `baymard-filter-06` collapse long facet lists to top 4–6 values with a "Show more" link
7. `baymard-filter-07` explain industry-specific or jargon filter labels
8. `baymard-filter-08` promote important filters above the product grid / above the fold
9. `baymard-filter-09` provide 4 essential sort options (featured, price asc/desc, rating, newest)
10. `baymard-filter-10` persist filter state when user returns from a product detail page

> Source: §3.6 bullets + https://baymard.com/blog/promoting-product-filters + https://baymard.com/blog/have-filters-for-list-item-info + per-rule URLs in `/docs/research/baymard-public-rules.md` (B-F-01…B-F-10).

**`baymard-bread-*` — Breadcrumbs (6 rules, §3.7):**
1. `baymard-bread-01` provide both hierarchy-based AND history-based breadcrumbs
2. `baymard-bread-02` include the full category hierarchy in the breadcrumb trail
3. `baymard-bread-03` suppress homepage and current product page layers from the trail
4. `baymard-bread-04` make breadcrumbs swipeable on mobile for long paths
5. `baymard-bread-05` use clear tappability cues on mobile breadcrumbs (size, underline, chevron)
6. `baymard-bread-06` expose `BreadcrumbList` structured-data markup for SEO and assistive tech

> Rules 01–05 from verified public research (B-B-01…B-B-05). Rule 06 enumerated from §3.7 narrative; supersede when Baymard Premium IDs become available.
> Source: §3.7 + https://baymard.com/blog/ecommerce-breadcrumbs + per-rule URLs in `/docs/research/baymard-public-rules.md`.

**`baymard-pdp-*` — PDP / Product Detail (18 rules, §3.8):**
1. `baymard-pdp-01` use button-style size selectors (swatches), not dropdowns
2. `baymard-pdp-02` provide at least one in-scale product image (size/context reference)
3. `baymard-pdp-03` show product on a human model for worn or carried items
4. `baymard-pdp-04` provide sufficient image resolution and zoom on desktop and mobile
5. `baymard-pdp-05` support both pinch and double-tap zoom gestures on mobile
6. `baymard-pdp-06` allow guest users to save / wishlist items without account creation
7. `baymard-pdp-07` display a return-policy link or summary directly on the product page
8. `baymard-pdp-08` show the lowest shipping-cost estimate (and ETA) on the product page
9. `baymard-pdp-09` allow carousel navigation across reviewer-submitted images (UGC)
10. `baymard-pdp-10` respond publicly to negative reviews to demonstrate accountability
11. `baymard-pdp-11` display price-per-unit for multi-quantity or weight-priced products
12. `baymard-pdp-12` synchronize product data (price, stock, images) across variation selections
13. `baymard-pdp-13` include descriptive text or graphics on key product images (annotations)
14. `baymard-pdp-14` single dominant Add-to-Cart CTA — not 3–6 competing colorful buttons
15. `baymard-pdp-15` prefer accordion over horizontal tabs for PDP detail sections
16. `baymard-pdp-16` show out-of-stock variants as visible-but-disabled (never remove from UI)
17. `baymard-pdp-17` offer a "notify me when back in stock" flow for OOS variants
18. `baymard-pdp-18` surface size-guide inline on the PDP — not hidden behind a separate page

> Rules 01–13 from verified public research (B-P-01…B-P-13). Rules 14–18 enumerated from §3.8 narrative; supersede when Baymard Premium IDs become available.
> Source: §3.8 + https://baymard.com/research/product-page + per-rule URLs in `/docs/research/baymard-public-rules.md`.

### 3.1 Cart abandonment
**70.19% average abandonment** across 49 studies 2006–2023, range 55–84.27% (https://baymard.com/lists/cart-abandonment-rate). By device: mobile 77.06%, tablet 66.39%, desktop 70.01%. **Reasons** (excluding 43% "just browsing"): extra costs 48%; forced account creation 24%; slow delivery 19%; distrust with CC 18–19%; too long/complicated 17–18%; couldn't see total up front 16%; errors/crashes 13%; returns policy 12%; declined CC 9%; limited payment methods 7%.

### 3.2 Checkout flow
**Average 5.1 steps / 11.3 fields** (2024, down from 14.88 fields in 2016). Ideal: 6–8 guest-checkout fields, ~12 total elements. **92%** of top 100 desktop sites have inadequate form-field label descriptions (https://baymard.com/blog/descriptions-in-checkout). **60%** struggle to identify guest-checkout option. **15%** ask same info multiple times (Amazon Pay report). **50%** pre-check newsletter opt-in; another third force-subscribe silently. **28%** mobile sites don't autodetect city/state from ZIP. **16%** mobile sites mis-implement "use shipping as billing." Hub: https://baymard.com/checkout-usability

### 3.3 Credit card form
- **Auto-format spaces every 4 digits** — historically 80% non-compliance, 50% in 2019, 15% now (https://baymard.com/blog/credit-card-field-auto-format-spaces). Use 4-4-4-4 (Visa/MC), 4-6-5 (AMEX 15 digits), 4-4-4-4-3 (19-digit cards).
- **5% of users abandon due to CC validation errors.**
- **Auto card-type detection via IIN ranges** adapts length limits, CVV help, spacing (https://baymard.com/checkout-usability/credit-card-patterns).
- **Expiration format:** **72% of sites** fail to match physical-card format. Use MM/YY single field with auto-inserted slash, not YYYY (https://baymard.com/blog/how-to-format-expiration-date-fields).
- **Autocomplete tokens:** `cc-number`, `cc-name`, `cc-exp`, `cc-exp-month`, `cc-exp-year`, `cc-csc`. Full mobile spec at https://baymard.com/labs/touch-keyboard-types.
- **Never clear CC details on error.** **84% of sites** mis-handle editing stored cards (https://baymard.com/blog/editing-credit-card-ux-research) — PCI requires "fake editing" (delete + re-add) with clear messaging.

### 3.4 Address forms
- **Country selector FIRST** — drives all subsequent field formats/validation.
- Single "Address Line 1" + optional "Address Line 2" (never omit; label explicitly "Apt, Suite — optional"). https://baymard.com/blog/address-line-2
- **9% manual-entry typo rate** — fully automatic address autocomplete outperforms; postal-code autodetection is second best (https://baymard.com/blog/automatic-address-lookup).
- **28% mobile sites** don't autodetect city/state from postal code.
- US state: dropdown (not free text). UK: optional county. Hide for countries without subdivisions.

### 3.5 Mobile checkout
- **81% mobile sites** score "mediocre or worse" overall (https://baymard.com/blog/mobile-ux-ecommerce).
- **Touch keyboard covers ~50–80% of screen.** **60% of top 50 mobile sites** fail ≥2 of 5 keyboard optimizations.
- Numeric fields: `<input type="text" inputmode="numeric" pattern="[0-9]*" autocomplete="…" autocorrect="off" novalidate>` — NOT `type="number"`.
- Name fields: `autocapitalize="words"`; email: `autocorrect="off" autocapitalize="off"`.
- Sticky bottom CTA ≥44×44 pt (iOS) / 48×48 dp (Android). Reported 5–12% conversion lift when made sticky.
- Surface Apple Pay / Google Pay / PayPal / Shop Pay / Amazon Pay **before** manual CC form (Amazon Pay: +11.4% repeat purchase vs other methods).

### 3.6 Product listing / search / filters
- **90%** of major sites use autocomplete (https://baymard.com/ecommerce-design-examples/34-autocomplete-suggestions). Value isn't typing speed — it's teaching terminology and suggesting scopes.
- **62%** fail to include scope suggestions in autocomplete; **94% mobile sites** don't support "search within current category" (https://baymard.com/blog/search-within-current-category); **46%** fail to autodirect when query matches a category.
- **88% mobile sites** have context-free "no results" pages.
- **61%** don't promote important filters at top of product list (https://baymard.com/blog/promoting-product-filters); expand/collapse icons right-aligned; truncate lists >10 with styled "More" link.
- **38%** don't provide filters for attributes displayed in list-item info (https://baymard.com/blog/have-filters-for-list-item-info).
- **46%** display too-little or poorly chosen content in list items.
- Category-specific filters are mandatory (megapixels for cameras, temperature rating for sleeping bags).

### 3.7 Homepage / category
- **68% top 50 sites** have sub-par breadcrumbs (https://baymard.com/blog/ecommerce-breadcrumbs); **45%** use only hierarchy type, **23%** have none. **65% mobile sites** show no breadcrumbs. Implement BOTH hierarchy-based AND history-based breadcrumbs.
- **>50% of sites** suffer from "overcategorization." **38% mobile sites** have too-deep/shallow/overlapping hierarchies.
- **30% of sites** use auto-rotating carousels on mobile despite documented issues (https://baymard.com/blog/homepage-carousel).

### 3.8 PDP mistakes
- **51%** deliver "mediocre or worse" PDP UX (2025 benchmark, https://baymard.com/research/product-page). No site achieves "State of the Art" overall.
- **28%** use horizontal tabs (worst-performing template); 67% of accordion users mis-implement.
- Primary "Add to Cart" must be visually dominant; warn against 3–6 competing colorful buttons.
- **64% of users** look for shipping on PDP; **24%** abandon when total isn't visible before checkout.
- **67% of sites lack UGC visuals** on PDPs; minimum 3–5 images, support zoom + variants driving imagery.
- Variants as swatches not dropdowns; out-of-stock variants visible-but-disabled (not removed).
- Star ratings above the fold + verified badges: up to +18% conversion (Baymard 2024).

---

## 4. Core Web Vitals and performance proxies

**Core Web Vitals** are measured at p75 over a 28-day rolling CrUX window. A page passes only if ALL three meet "good."

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS | ≤ 0.1 | ≤ 0.25 | > 0.25 |
| FCP | ≤ 1.8s | ≤ 3.0s | > 3.0s |
| TTFB | ≤ 0.8s | ≤ 1.8s | > 1.8s |
| TBT | ≤ 200ms | ≤ 600ms | > 600ms |

### 4.1 LCP (Largest Contentful Paint)
Time to render the largest eligible element in the viewport. Eligible: `<img>`, `<image>` in SVG, `<video>` poster/first frame, elements with CSS `background-image: url()` (not gradients), block-level text. Excluded: opacity 0, full-viewport backgrounds, placeholders. Four contributing phases: TTFB, resource load delay, resource load duration, element render delay. Fixes: `<link rel="preload" as="image" fetchpriority="high">`, `<img fetchpriority="high">` (Google Flights: −700ms), AVIF/WebP, CDN, critical CSS, SSR > CSR above-fold, 103 Early Hints. Source: https://web.dev/articles/lcp · https://web.dev/articles/optimize-lcp

### 4.2 INP (Interaction to Next Paint)
Replaced FID **12 March 2024**. Worst-case latency across ALL interactions (click, tap, keydown) over page lifetime. Three phases: input delay + processing + presentation. Interactions >50 uses 98th percentile. Scroll/hover NOT counted. FID only measured first input delay, input phase only. Causes: long JS tasks >50ms, DOM >1,500 nodes, heavy handlers, layout thrashing, third-party scripts (chat/tag managers add 100–400ms each). Fixes: `await scheduler.yield()` (Chrome 129+), `useTransition`/`useDeferredValue`, `requestIdleCallback`, debounce, `content-visibility: auto`, partial hydration, defer/async third parties. Source: https://web.dev/articles/inp

### 4.3 CLS (Cumulative Layout Shift)
`layout shift score = impact fraction × distance fraction`. Session windows: start at first shift, end after 1s gap, cap 5s max. Final CLS = **maximum** session-window sum (not total). Shifts within 500ms after user input have `hadRecentInput=true` and are excluded. Causes: images/iframes without width/height, ads without reserved space, cookie banners injected above content, FOIT/FOUT with differing metrics, animations on layout properties, dynamically injected above-fold DOM. Fixes: `width`/`height` attributes (browser infers `aspect-ratio`), `aspect-ratio: 16/9`, skeleton placeholders, `font-display: optional` + `size-adjust`, animate only `transform`/`opacity`, sticky overlays not layout-inserts. Source: https://web.dev/articles/cls

### 4.4 Supporting metrics
**FCP:** first contentful pixel. **TTFB:** network response. **TBT:** sum of `(task.duration − 50)` for long tasks between FCP and TTI; lab proxy for INP, 30% of Lighthouse Performance score. **Speed Index:** visual progress from filmstrip. **TTI:** deprecated in Lighthouse 10 (Jan 2023); replaced in weights by TBT.

### 4.5 Programmatic measurement

**PerformanceObserver API — canonical snippets:**
```js
// LCP
new PerformanceObserver(l => {
  const last = l.getEntries().at(-1);
  window.__vitals.LCP = last.startTime;
}).observe({ type: 'largest-contentful-paint', buffered: true });

// CLS (with session windows)
let clsValue = 0, sessionValue = 0, sessionEntries = [];
new PerformanceObserver(l => {
  for (const e of l.getEntries()) {
    if (e.hadRecentInput) continue;
    const first = sessionEntries[0], last = sessionEntries.at(-1);
    if (sessionEntries.length &&
        e.startTime - last.startTime < 1000 &&
        e.startTime - first.startTime < 5000) {
      sessionValue += e.value; sessionEntries.push(e);
    } else { sessionValue = e.value; sessionEntries = [e]; }
    if (sessionValue > clsValue) clsValue = sessionValue;
  }
}).observe({ type: 'layout-shift', buffered: true });

// INP proxy via event timing
let worst = 0;
new PerformanceObserver(l => {
  for (const e of l.getEntries())
    if (e.interactionId) worst = Math.max(worst, e.duration);
}).observe({ type: 'event', buffered: true, durationThreshold: 40 });

// TBT
let tbt = 0;
new PerformanceObserver(l => {
  for (const e of l.getEntries()) tbt += Math.max(0, e.duration - 50);
}).observe({ type: 'longtask', buffered: true });
```

**Navigation Timing:** `const [nav] = performance.getEntriesByType('navigation'); const ttfb = nav.responseStart − nav.startTime;`

**Preferred library:** `web-vitals@5` (`npm i web-vitals`). Use attribution build for root-cause: `import { onLCP, onINP, onCLS } from 'web-vitals/attribution'`. Metrics return `{ name, value, delta, id, rating, entries, navigationType, attribution }`.

**Playwright integration:** use `page.addInitScript()` to inject observers before page scripts; for most accurate INP/LCP, inject the web-vitals IIFE via `page.addScriptTag({ url: 'https://unpkg.com/web-vitals@5/dist/web-vitals.iife.js' })` and poll `window.__metrics`. LCP requires interaction or page hide to finalize — dispatch synthetic click or hide page. CLS needs page-lifetime observation; `networkidle` alone misses post-load shifts. Throttle via CDP: `Network.emulateNetworkConditions`, `Emulation.setCPUThrottlingRate`. Export traces via `page.tracing.start({ screenshots: true, snapshots: true })`.

**Lab vs field:** Lab (Lighthouse, WebPageTest, Playwright) is deterministic but INP is NOT measurable synthetically — use TBT as proxy. Field (CrUX, RUM) is used for Google ranking; 28-day p75 aggregation. Lab can score 95 while field is "Poor" due to real-device diversity.

### 4.6 Doherty threshold
Walter Doherty & Arvind Thadhani, *"The Economic Value of Rapid Response Time,"* IBM Corp 1982 (IBM Systems Journal). Productivity accelerates when response drops **below 400ms** — overturning the prior 2-second assumption. *"When a computer and its users interact at a pace that ensures that neither has to wait on the other, productivity soars."* Modern UX rule: user actions should feel instant under 400ms. INP's 200ms "good" is stricter — passing INP automatically satisfies Doherty. Archive: https://jlelliotton.blogspot.com/p/the-economic-value-of-rapid-response.html

### 4.7 RAIL model
Paul Lewis / Google 2015 (web.dev article deprecated 2024 in favor of CWV; MDN still lists). **R**esponse ≤100ms to acknowledge input. **A**nimation ≤16ms/frame (60fps; effectively ~10ms app budget). **I**dle ≤50ms batched chunks. **L**oad ≤1000ms initial, ≤2000ms subsequent. Source: https://developer.mozilla.org/en-US/docs/Glossary/RAIL

### 4.8 Nielsen response-time limits
https://www.nngroup.com/articles/response-times-3-important-limits/. **0.1s** — feels instantaneous, no feedback needed. **1s** — flow maintained, cursor state sufficient. **10s** — attention limit, requires determinate progress + cancel. Beyond 10s: move to background with return-later notification.

**Progress-feedback rules:** <100ms nothing; 100–400ms state change only; 400ms–1s spinner; 1–10s skeleton or indeterminate bar; >10s determinate bar + ETA + cancel; >1 min background + notification + email fallback. Skeletons outperform spinners on content-heavy pages (perceived speed).

---

## 5. Expert "implicit" criteria junior reviewers miss

For each: WHAT / HOW / WHY+source / FAIL. Compressed to ~3–5 lines each for density.

**Interaction states.** (1) **Focus order matches visual order** — tab with no mouse; run Adrian Roselli's reading-order bookmarklet; CSS `order`/`flex-direction: row-reverse`/`grid-area` can break DOM-visual parity. *Flex spec: "Authors must not use `order` as a substitute for correct source ordering."* (2) **Hover states on all interactives** gated behind `@media (hover: hover) and (pointer: fine)` so iOS doesn't get "sticky hover." (3) **Empty states** have four kinds: first-run (onboarding), filtered-empty ("clear filters?"), error-empty, permission-empty — never conflate. (4) **Loading states sized to duration** per NN/g 0.1/1/10s. (5) **Error states** at three levels: field, form, page — each with live region, focus moved, preserved data. (6) **Disabled vs loading vs error** — prefer `aria-disabled` over `disabled` so SR users can still discover and learn why; `aria-busy="true"` on loading; label updates ("Saving…"). Source: Kitty Giraudel, *On disabled and aria-disabled*. (7) **Reversibility > confirmation** — Aza Raskin, *Never Use a Warning When You Mean Undo* (A List Apart 2007): prefer execute + 5–30s Undo toast; reserve modal confirm for irreversible. (8) **Disabled state contrast** — exempt from 1.4.3 technically, but disabled-until-valid buttons must remain legible; ensure forced-colors styling survives.

**Modal / focus.** (9) Focus trap cycles inside modal with Tab/Shift-Tab, releases on close. (10) Focus restores to trigger on close. (11) Esc dismisses. (12) `role="dialog"` + `aria-modal="true"` + `aria-labelledby` referencing visible heading (native `<dialog>.showModal()` handles this). (13) Background scroll lock with position preservation on close. (14) `inert` attribute (not just `aria-hidden`) on siblings — `aria-modal` announces inertness but doesn't enforce it for SR virtual cursor. Source: WAI-ARIA APG Dialog pattern.

**Live regions.** (15) Polite vs assertive — polite for confirmations, assertive only for errors needing immediate attention. (16) Pre-rendered at page load, NOT created-on-demand — AT registration needs milliseconds. Source: Sara Soueidan, Tetralogical. (17) `role="status"` (polite, atomic) for saves/counts; `role="alert"` (assertive, atomic) for errors; `role="log"` for chat; `role="alertdialog"` when response required. (18) SPA route-change announcements — move focus to new view's `<h1 tabindex="-1">`, update `document.title`, inject polite announcement. Source: Marcy Sutton, *What we learned from user testing of accessible client-side routing techniques* (2019).

**Password / auth.** (19) Show/hide toggle (`aria-pressed`), caps-lock warning, real strength via zxcvbn, **paste allowed** — NIST SP 800-63B Rev. 4: *"Verifiers SHALL allow the use of password managers and autofill… SHOULD permit paste."* Blocking paste forces weaker passwords. (20) Full autocomplete inventory: `username`, `current-password`, `new-password`, `one-time-code`, `email`, `tel`, `given-name`, `family-name`, `name`, `street-address`, `address-line1/2/3`, `address-level1/2`, `postal-code`, `country`, `country-name`, `cc-name`, `cc-number`, `cc-exp`, `cc-exp-month`, `cc-exp-year`, `cc-csc`, `bday`, `organization`, `webauthn` (passkey conditional UI — must be LAST token). (21) Never split OTP into 6 separate inputs without `autocomplete="one-time-code"` on the first — iOS SMS autofill puts entire code in first box only.

**Touch / mobile.** (22) Sizes: WCAG 2.5.8 AA 24×24, Apple HIG 44×44 pt, Material 48×48 dp, WCAG AAA 2.5.5 44×44. (23) Spacing: ≥24px center-to-center for undersized targets (WCAG spacing exception); practically 8px gap. (24) 300ms tap delay gone with proper viewport meta; use `touch-action: manipulation` to suppress double-tap zoom; passive listeners for scroll/touchmove. (25) Prefer Pointer Events (`pointerdown/move/up` with `pointerType`) — unifies mouse/touch/pen; Safari support since 13. (26) Gate hover-only affordances with `@media (hover: hover)`; provide tap alternative.

**Form labels.** (27) Placeholder-as-label is a NN/g anti-pattern, *"Placeholders in Form Fields Are Harmful"* (Sherwin 2014/2018): memory strain, hurts autofill verification, low contrast, AT-hostile. (28) Floating labels: label shrinks too small post-float for low-vision, collides with autofill chrome (NN/g *Floating Labels Are a Bad Idea*). (29) Required indicators: `*` alone is ambiguous; use inline "(required)" text or mark optional fields if majority required.

**SPA / routing.** (30) Deep link every major state — filters, sort, pagination, open modals, selected tabs in URL. Test: reload restores; share URL reproduces view. (31) pushState for new navigations, replaceState for non-navigational tweaks. (32) `history.scrollRestoration = "manual"` if app manages; restore scroll on back, reset on forward. (33) Focus management on route change (see 18). (34) `document.title` per route — format "Page – Section – Site" (WCAG 2.4.2).

**Form robustness.** (35) Copy-paste tolerance — strip spaces/dashes from cards, phones, IBANs, ZIPs server and client side. (36) `autocapitalize="off"` on email/username/codes; `autocorrect="off"` on names/addresses/codes; `spellcheck="false"` on names/codes/passwords. (37) IME composition — suppress validation between `compositionstart`/`compositionend` for CJK/Korean/Vietnamese. (38) **Avoid `type="number"`** for digit-strings (Brad Frost, *You probably don't need input type="number"*): scroll-wheel value changes, leading-zero loss, locale decimal issues. Use `<input type="text" inputmode="numeric" pattern="[0-9]*">`.

**Network / errors.** (39) Distinct UX for timeout / offline / 5xx / 429 / CORS. (40) `navigator.onLine` unreliable (MDN: *"browsers have implemented this property differently… may give false positives"*); detect via actual request failures. (41) Session expiration warn N minutes before with keep-alive, preserve state after re-auth. (42) `BroadcastChannel('auth')` or `storage` events for cross-tab logout/login/cart propagation. (43) Optimistic UI requires rollback with toast; pessimistic needs skeleton. (44) Double-submit prevention: disable + show loading + `Idempotency-Key` UUID header (Stripe/PayPal pattern). (45) Form auto-save to localStorage; restore-draft prompt.

**i18n.** (46) RTL: `dir="rtl"`, logical CSS properties (`margin-inline-start`), mirror directional icons but NOT play button / video timeline / clock / numerals / logos. (47) Long German: `overflow-wrap: break-word; hyphens: auto` + correct `lang` for hyphenation dictionary. (48) CJK: `word-break: normal` (NOT `break-all`), `line-break: strict` for Japanese kinsoku. (49) `Intl.DateTimeFormat`, `Intl.NumberFormat`, `Intl.RelativeTimeFormat`, `Intl.ListFormat`, `Intl.PluralRules` — never hand-format. (50) Name fields: accept Unicode, spaces, hyphens, apostrophes, single-name users, >20 chars — Patrick McKenzie, *Falsehoods Programmers Believe About Names* (Kalzumeus 2010). (51) Address i18n: country drives all subsequent fields; Google libaddressinput covers 200+ variations. (52) `<html lang>` per page; `<span lang>` for embedded foreign phrases (WCAG 3.1.1 / 3.1.2).

**Accessibility edges.** (53) Reflow to 320 CSS px (WCAG 1.4.10) — test at viewport 320×256 or 1280 @ 400% zoom. (54) `prefers-reduced-motion: reduce` — disable parallax, autoplay carousels; emulatable in DevTools Rendering panel. (55) `prefers-color-scheme` dark mode via CSS tokens; test embedded SVG/chart backgrounds don't remain blinding white. (56) `prefers-contrast: more`, `forced-colors: active` (Windows High Contrast Mode) — use system color keywords (`CanvasText`, `LinkText`, `ButtonText`, `GrayText`); `forced-color-adjust` only when essential; custom checkboxes built from background-images vanish in HCM. Source: Adrian Roselli.

**Other.** (57) Print stylesheet `@media print` — hide nav/ads, force black-on-white, expand URLs after links, page-break-inside: avoid. (58) Skip link first focusable, visible on focus, target `tabindex="-1"` on `<main>`. (59) Landmarks: one `<main>`, named `<nav>`/`<aside>` if multiple. (60) One h1, no skipped levels. (61) Unique `<title>` per page. (62) Meta description, viewport, OG tags (`og:image` ≥1200×630), canonical. (63) Favicons (SVG + apple-touch-icon 180×180 + manifest). (64) HTTPS + no mixed content; set `Content-Security-Policy: upgrade-insecure-requests`.

---

## 6. Content vs design vs UX audits

**Content audit** — inventory + qualitative evaluation of every content asset. Scope: URL inventory, page-type, owner, word-count, traffic, reading level (Flesch-Kincaid, Hemingway), SEO (titles/meta/H1/internal links), freshness, ROT (Redundant/Outdated/Trivial), duplicates, gap vs user/keyword needs. Tools: Screaming Frog, Sitebulb, Ahrefs, SEMrush. Artifact: inventory spreadsheet + KEEP/UPDATE/MERGE/DELETE decisions + remediation roadmap + governance plan. 2–6 weeks typical. Run on: redesign, CMS migration, rebrand, SEO decline. Sources: Kristina Halvorson *Content Strategy for the Web*; NN/g https://www.nngroup.com/articles/content-audits/; Verizon case study eliminated 50% of HR content via audit.

**Design audit** — visual/design-system layer. Scope: type scale, color tokens, spacing, radius, shadows, DS adherence/detachment, brand alignment, dark-mode parity, icon consistency. Methodology: Brad Frost's **Interface Inventory** (https://atomicdesign.bradfrost.com/chapter-4/) — *"screenshotting and categorizing all the unique UI patterns."* Tools: Figma library analytics, Design Lint plugins, Chromatic visual regression, Nathan Curtis's component "doneness matrix" (docs, a11y, i18n/RTL, responsive, variants, versioning). Qwilr case study: 10 people, 17 UI categories, 3 weeks (Kaleidoscope). Run on: DS launches, rebrand, dark-mode rollout.

**UX audit** (heuristic evaluation + analytics). Scope: Nielsen's 10 heuristics, task success, funnel/heatmap/session-recording analytics, user research, a11y scan, performance. Methodology: **3–5 evaluators independently**, two passes each, affinity-diagrammed aggregation (Nielsen & Molich 1990). NN/g data: single evaluator finds major issues 42% of the time, minor 32%. Artifacts: issue log with 0–4 severity, annotated screenshots, heuristic scorecard, executive deck. NN/g workbook: https://media.nngroup.com/media/articles/attachments/Heuristic_Evaluation_Workbook_1_Fillable.pdf. Run on: pre-launch, conversion plateau, pre-redesign, annual health check.

**Sequencing rule.** Content-heavy (marketing, publishers, docs): content → UX → design (can't restyle pages you'll delete). App-like (SaaS): UX → design → content/microcopy (Karri Saarinen's Airbnb DLS origin: *"We started by auditing and printing out many of our designs… where and how the experiences were breaking."*). Run accessibility and SEO audits in parallel, feeding both tracks.

**Accessibility audit (fourth type).** WCAG 2.2 AA combining axe/Lighthouse/WAVE/IBM Equal Access + manual keyboard + AT testing (NVDA/JAWS/VoiceOver/TalkBack) + ARIA review. Produces VPAT/ACR for procurement.

---

## 7. How top product teams audit their own products

**Figma** — Weekly design crits are deliberately distinct from product reviews. VP Design Noah Levin: *"They are not about making major product decisions… Rather, they're designed to leverage the collective skills and knowledge… to help unblock designers on tricky projects, elevate quality across the team, encourage consistency."* Six crit methods: traditional presentation, pair design, silent critique (async Figma annotation), breakouts, sticky-note exercises, async Slack. Cadence: Wed 9:30–10:30am PT (EU-friendly) + Fri 2–3pm PT, two 30-min topics each. Career ladder has explicit **Craft** axis alongside Strategy/Collaboration/Impact. Rasmus Andersson's UI2 DS principles (https://rsms.me/work/figma/): draft-file daily work → staging file for broader audience. Sources: https://www.figma.com/blog/design-critiques-at-figma/ and /inside-figma-the-product-design-teams-process/

**Linear** — Karri Saarinen's *"Why is quality so rare?"* (Config 2025 keynote, https://linear.app/now/why-is-quality-so-rare): *"We replaced purpose with metrics. If it didn't move a metric, it didn't matter. Even we, as designers, stopped asking 'Does this feel right?'"* Principles: *"We started with quality… people actually noticed, because it's a rare approach."* *"For quality, you need a team that views the spec as the baseline, not the finish line."* *"There's no 'handoff to dev.' You're never off the hook."* Practice: 2-week cycles including bugs, short specs ("more likely to be read"), no rotating teams on a surface. Published as **The Linear Method** https://linear.app/method.

**Vercel** — Design Engineering collapses the handoff (https://vercel.com/blog/design-engineering-at-vercel): *"Design Engineers work closely with designers to implement designs, skipping the traditional handoff process. Instead of handing off a completed design, a Designer sketches the start and iterates with a Design Engineer in Figma or code."* Internal DS: **Geist**. **Vercel Toolbar** (https://vercel.com/docs/vercel-toolbar) ships built-in WCAG 2 AA contrast + list-structure checks + layout-shift detection + commenting on preview deployments. Guillermo Rauch quality bar: *"None of them met the quality bar of the giants of the web. It has to be Google or Amazon quality."* Every PR = preview deployment with audit affordances. Principle: *"Iterate to Greatness… balance business goals with craft."*

**Stripe** — Written-narrative culture as audit infrastructure. Michael Siliski (Ken Norton interview): *"Stripe runs on written long-form documents in a way that I haven't seen before… somebody can go deep, like all the way down, and then distill it back out to everybody else."* Dave Nunez: CEO Patrick Collison's emails *"literally had footnotes… structured his emails to be like research papers."* Benjamin De Cock: *"We have weekly design critiques at Stripe where we're encouraged to share our work."* Public artifact bar: Increment magazine, Stripe Press. Default to memos over slide decks.

**GitHub** — Multi-layered a11y program (https://accessibility.github.com/): Primer design system ("most powerful lever for implementing accessibility at scale"), **GitHub Fundamentals** scorecards with accountability, embedded a11y designers + Figma annotation toolkit (open-sourced), Accessibility Design Bootcamp + Champions (17 → 52+ engineers, target 100+). **`github/accessibility-scanner`** GitHub Action (https://github.com/github/accessibility-scanner): AI-powered, creates tracked issues, Copilot fixes. "Continuous AI for accessibility": *"Roughly 75–80% of the time, reported issues correspond to something we already know about from internal audits."* Primer color audit: 100+ pairs across 1,000+ use cases automated.

**Airbnb (DLS)** — Origin was an audit. Karri Saarinen, *Building a Visual Language* (https://airbnb.design/building-a-visual-language/): *"We started by auditing and printing out many of our designs, both old and new. Laying the flows side by side on a board, we could see where and how the experiences were breaking."* DLS as ongoing audit tool: *"Product reviews [can] focus on the actual concepts and experiences of a design, rather than padding, colors and type choices."* Organism-based (not atomic). Contribution gate: prove universality + importance before adding. Primary Text `#222222` (15.9:1 AAA); Secondary `#717171` (4.88:1 AA).

**IBM Carbon** — Compliance-first (https://carbondesignsystem.com/guidelines/accessibility/overview/): *"Carbon components follow the IBM Accessibility Checklist which is based on WCAG AA, Section 508, and European standards."* **IBM Equal Access Accessibility Checker** (Apache-2.0) — browser extension + Cypress/Karma/Node packages; multi-page scans with aggregated reports; baseline-file regression testing; violations/needs-review/recommendations severity categorization; ACT-Rules aligned.

**Common threads:** Quality is a cultural precondition enforced by founders or codified fundamentals; the design system IS the audit tool once enforcement is in tokens; ritualized review (weekly crits) beats episodic audits; written artifacts + annotations make findings durable; automation finds the floor, humans find the ceiling.

---

## 8. Specific tools professionals use

**axe DevTools (Deque).** Browser extension + `@axe-core/playwright` / `@axe-core/puppeteer` / `@axe-core/cli` / `jest-axe` / `cypress-axe`. Intelligent Guided Tests (Pro) walk through manual checks. ~96 rules. Zero-false-positive philosophy. Catches: 57% of WCAG issues by volume, strongest for 4.1.2, 1.4.3, 1.1.1, 1.3.1 subsets. Misses: alt text quality, focus order meaning, screen-reader UX, dynamic states not surfaced. URL: https://www.deque.com/axe/devtools/

**WAVE (WebAIM).** Online tool + Chrome/Firefox/Edge extensions + Stand-alone API (PHP + Node, Puppeteer scripting). ~110 icon overlays directly on rendered page — evaluates post-CSS/JS DOM. Catches: contrast (with slider tool), structural/ARIA/label issues; visual in-context is the differentiator. Misses: dynamic states requiring scripting (unless using Stand-alone with Puppeteer), never marks a page "passed." URL: https://wave.webaim.org/

**Lighthouse.** Performance + Accessibility + Best Practices + SEO (+ PWA removed in LH 12). Performance score weights (LH 10+): FCP 10%, SI 10%, LCP 25%, **TBT 30%**, CLS 25%. Mobile config: 4× CPU throttle, slow 4G simulation; desktop: unthrottled. Integrations: DevTools panel, CLI (`npm i -g lighthouse`), Node module, Lighthouse CI (regression + budgets + PR blocking), PageSpeed Insights API (~25k/day free, surfaces both lab + CrUX field). Accessibility runs a subset of axe-core rules (~57 audits vs ~96 axe rules). Misses: real INP (lab uses TBT), multi-page flows, SPA post-load routes, true device variability. URL: https://developer.chrome.com/docs/lighthouse/

**Pa11y.** CLI-first for CI. Runners pluggable: `htmlcs` (default) + `axe` — can run both simultaneously for broader coverage. `pa11y-ci` with sitemap support, `.pa11yci` JSON config for concurrency/standards/ignore/reporters. Supports `actions` (click, wait, type) for dynamic states. Output: JSON/CSV/CLI; issues have `code` (e.g. `WCAG2AA.Principle4.Guideline4_1.4_1_2.H91.A.NoContent`), context, selector. Limitations: doesn't integrate inside Playwright/Cypress flows (uses its own Puppeteer). URL: https://github.com/pa11y/pa11y

**IBM Equal Access Accessibility Checker.** Browser extensions + `accessibility-checker` npm + `cypress-accessibility-checker` + `karma-accessibility-checker`. ~140 rules aligned to W3C ACT. Severity: violation / potentialviolation / recommendation / manual. Baseline file for regression. Built-in keyboard-checker mode visualizes tab order. URL: https://www.ibm.com/able/toolkit/

**Stark.** Figma/Sketch/Adobe XD plugins + Chrome extension. Contrast checker with library-aware color suggestions; Vision Simulator (4 CVD types + blurred/contrast-loss/ghosting/yellowing); Focus Order; Landmarks; Alt-Text Annotations (AI, 5 languages); Touch Target size; Typography; automated design scan (Sidekick). Design-time only; pair with axe at runtime.

**Polypane.** Chromium-based multi-viewport developer browser. Synchronized panes (mobile → 5K); accessibility panel with 80+ automated tests + 19+ vision/condition simulators (farsightedness, glaucoma, cataracts, dyslexia); horizontal-overflow highlighter; focus-order overview; live contrast/role/name inline; emulates `svh`/`dvh` and device-specific safe-area insets accurately (Polypane 26). Caveat: still Chromium — no real WebKit/Gecko.

**Chrome DevTools.** Performance panel (Web Vitals attribution, flame chart, Performance insights). Coverage tab (dead JS/CSS bytes). Rendering panel emulates: `prefers-color-scheme`, `prefers-reduced-motion`, `prefers-reduced-transparency`, `prefers-contrast`, `forced-colors`, `color-gamut`, print media. Rendering overlays: Paint Flashing, Layout Shift Regions, Scrolling performance issues, Frame Rendering Stats, Core Web Vitals HUD, vision-deficiency simulators.

**Figma plugins.** Stark (full suite); Contrast (quick AA/AAA checks); Able (8-type CVD + % population affected); A11y Color Contrast Checker (scans visible text with live sliders); A11y-Color-Tokens (generates accessible tonal palettes for tokens).

---

## 9. Real devices vs emulation

**Why emulation lies.** Emulators run on host CPU/GPU; they can't reproduce device-specific GPU/driver/font rasterization (iOS San Francisco hinting, Android OEM fonts differ), memory pressure and thermal throttling (low-end devices kill tabs aggressively), real network jitter (synthetic `--throttling` is a flat factor), touch-specific behaviors (latency, multi-touch, palm rejection), IMEs, biometrics, real battery/sensor APIs. Emulating "iPhone" in Chrome DevTools still uses Blink, not WebKit.

**iOS Safari quirks.** `100vh` = largest viewport (URL bar hidden) — overflows when bar visible. Fix: `dvh` (dynamic), `svh` (small — bar visible, use for ~90% of layouts), `lvh` (large). iOS 26 introduced new `dvh` regressions (Apple Dev Forums 803987). Rubber-band overscroll: `overscroll-behavior: none` supported from Safari 16 (WebKit bug #176454); older fallback = `position:fixed; overflow:hidden` on `html,body` + scrollable inner wrapper + `-webkit-overflow-scrolling: touch` (legacy, MDN "non-standard"). Date inputs: always native wheel picker, cannot be fully styled. `position: fixed` + virtual keyboard: fixed elements detach/jump — use `window.visualViewport` API. Autoplay: requires `muted` + `playsinline`; low-power mode disables entirely. `backdrop-filter`: `-webkit-` prefix until Safari 18. PWAs/Add-to-Home-Screen share SW with Safari (iOS 14+) but FB/IG WebView does not; push only iOS 16.4+ for installed PWAs.

**Android.** Chrome (Blink) vs Samsung Internet (Blink fork; auto dark-mode override can invert brand colors — use `<meta name="color-scheme">` and `color-scheme` CSS; built-in ad blocker), Firefox (Gecko), OEM browsers. WebView / In-App Browsers (Facebook, Instagram, TikTok, LinkedIn) lack Service Workers (Firebase #8817), often block `getUserMedia`, WebXR, advanced WebGL; inject tracking JS (Thomas Steiner). Native apps should use **Chrome Custom Tabs** / **`SFSafariViewController`** to share cookies/capabilities; social apps use raw WebView. `<dialog>` element: polyfill older WebViews.

**Touch vs pointer vs mouse.** Prefer **PointerEvent** (`pointerdown/move/up`, `pointerType`, `setPointerCapture()`) — unifies mouse/touch/pen; Safari since 13; inherits from MouseEvent so compat code works. Call `event.preventDefault()` on pointer handlers to prevent compat mouse events firing. MDN: *"prefer PointerEvent for new code."*

**Device farms.** **BrowserStack** — 3,500+ real devices, 19 data centers, Live/App Live/Automate/App Automate, Appium/Espresso/XCUITest/EarlGrey/Selenium/Playwright/Cypress, biometric/SIM/Apple Pay, Local tunnel, Percy visual, Accessibility Testing. **Sauce Labs** — 700+ combos, Sauce Connect, Selenium/Appium. **LambdaTest** — 3,000+ combos, HyperExecute parallelization, SmartUI, OTT (Apple TV/Roku/Fire). **AWS Device Farm** — $0.17/min or $250/mo/device unlimited slots; smaller fleet.

**Real devices are mandatory for:** payment flows (Apple Pay/Google Pay/3DS — tokenization SDKs fail in emulators), touch gestures (pinch, swipe, long-press, palm rejection), media capture (camera, barcode, AR, audio), biometrics (FaceID/TouchID/WebAuthn), Apple ATT, iOS Safari font rendering, push notifications, battery/thermal/memory behavior, low-end performance validation (Moto G Power, Galaxy A14/A24), app-store compliance.

**Emulation suffices for:** layout and responsive design smoke; keyboard testing on desktop; contrast, vision-deficiency, dark-mode, forced-colors, reduced-motion testing; initial automated a11y scans in CI; cross-browser CSS during development; print-media previews.

**Key device-quirk fixes:** `100svh` / `100dvh` with `-webkit-fill-available` fallback; `overscroll-behavior: none` (Safari 16+); `window.visualViewport` for keyboard-aware layouts; `muted playsinline` for autoplay; `-webkit-backdrop-filter` prefix; detect WebView and degrade (PWA/push); `<meta name="color-scheme" content="light dark">` for Samsung Internet; viewport meta + `touch-action` for tap latency; PointerEvents + `preventDefault()`; `overscroll-behavior-y: contain` for pull-to-refresh; `viewport-fit=cover` + `env(safe-area-inset-*)` for notch; `-webkit-text-size-adjust: 100%` for iOS font inflation.

---

## 10. Consolidated phase-by-phase audit checklist

Every item carries a terse HOW / WHAT / WHY. Use this as the `super-design` operational spine.

### Phase 0 — Pre-audit setup
- **HOW:** Create burner account + test data; fetch CrUX data via PageSpeed Insights API; grant crawler permissions; install axe DevTools, WAVE, Polypane, IBM Equal Access, Lighthouse CLI, Pa11y, `web-vitals@5`; configure Playwright with `@axe-core/playwright` and `addInitScript` vitals observers. **WHAT:** Environment, accounts, baseline data. **WHY:** Audits without burner data destroy real records; without field data, lab scores mislead.
- **HOW:** Enumerate pages by crawling sitemap (Screaming Frog / Sitebulb). Classify: homepage, category, PDP, list, detail, form, checkout, auth, dashboard, settings, help. **WHAT:** Page-type inventory. **WHY:** Per-page-type criteria differ; Baymard groups research by type for a reason.

### Phase 1 — Per-page audit
- **Automated scan:** Run Lighthouse (Mobile config) + axe DevTools + WAVE. Log violations to issue tracker with WCAG SC mapped. **WHY:** Establishes floor (Deque: 57% of WCAG by volume).
- **Heuristic pass:** Walk Nielsen's 10 with the audit questions in §1. Score each 0–4 with 3-factor rationale. **WHY:** NN/g reliability requires ≥3 independent signals.
- **Visual hierarchy:** Identify the primary goal; verify it is the most dominant element (aesthetic/minimalist §1.8). **WHY:** Baymard PDP data — 51% mediocre UX due to competing CTAs.
- **Page title, meta, OG tags, canonical, favicon, language attribute:** Check source. **WHY:** WCAG 2.4.2 / 3.1.1, SEO, social previews.
- **Contrast sample:** Spot-check 5+ text samples over images/gradients; measure UI component borders ≥3:1. **WHY:** 83.9% pages fail 1.4.3 (WebAIM Million 2026).
- **Empty / loading / error states:** Render each (simulate no-data, throttled network, 500). **WHY:** Juniors consistently miss these; expert tier per §5.

### Phase 2 — Per-interaction audit
- **HOW:** For every interactive affordance, verify: visible hover state (gated `@media (hover: hover)`), visible focus indicator (2px perimeter, 3:1 contrast, not obscured by sticky chrome), active state, disabled state contrast (for usability, not compliance), loading state (`aria-busy`, label change). **WHAT:** State coverage. **WHY:** WCAG 2.4.7/2.4.11/2.4.13 + NN/g consistency.
- **HOW:** Click/tap every destructive action. Confirm Undo-toast pattern or modal confirm with specific consequence text. **WHY:** Raskin "Never use a warning when you mean undo."
- **HOW:** Inspect touch targets: ≥24×24 CSS px OR 24px center-to-center spacing. **WHY:** WCAG 2.5.8 AA.

### Phase 3 — Per-flow audit (registration, checkout, core task, error recovery)
- **Registration:** Guest option dominant; `autocomplete="email"`/`"new-password"`/`"one-time-code"`; paste allowed; magic-link/passkey alternative. **WHY:** 24% of Baymard respondents abandon forced account creation; WCAG 3.3.8.
- **Checkout:** 11–12 fields max, 6–8 ideal for guest; country-first logic; single Address Line 1 + optional Line 2; postal-code auto-lookup; CC number auto-spaces and auto-detects type; MM/YY expiration; CVV with card-adaptive help; sticky bottom CTA on mobile; Apple/Google Pay surfaced before manual CC; total visible before finalize; "Billing same as shipping" default-checked. **WHY:** Baymard §3.
- **Core product task (search, filter, add-to-cart, save):** Search autocomplete with scope suggestions; scoped category search; helpful "no results" with recovery; applied-filter pills visible; sort vs filter separated; variants as swatches with state; out-of-stock visible-but-disabled. **WHY:** Baymard §3.6–§3.8.
- **Error recovery:** Every server error offers retry + preserves entered data + announces via `role="alert"`; 404/500 pages have search + home + support links. **WHY:** WCAG 3.3.1 + Nielsen H9.
- **Session management:** Expiration warning N-minutes before, preserve form state, BroadcastChannel cross-tab logout propagation, offline detection via request failure (not `navigator.onLine`). **WHY:** Expert tier §5.

### Phase 4 — Per-viewport audit
- **Mobile 375px:** Test at 375×667 (iPhone SE) and 390×844 (iPhone 15). Check sticky CTAs, thumb-zone reachability (Polypane overlay), touch targets, keyboard types (`inputmode`), autocorrect/autocapitalize disabled on emails/codes. **WHY:** Baymard 60% mobile fail keyboard optimization.
- **Tablet 768px:** Verify breakpoint transition; no mid-breakpoint dead zones.
- **Desktop 1440px:** Full-layout smoke.
- **Reflow:** 320×256 OR 1280px @ 400% zoom — no 2D scroll except tables/maps/code. **WHY:** WCAG 1.4.10.
- **Text spacing bookmarklet:** Inject `line-height: 1.5 !important; letter-spacing: 0.12em !important; word-spacing: 0.16em !important; p { margin-bottom: 2em !important; }`. **WHY:** WCAG 1.4.12.

### Phase 5 — Cross-browser smoke tests
- Chrome (primary), Safari (macOS + iOS real device or BrowserStack), Firefox, Samsung Internet (auto dark-mode override check), plus major in-app WebViews if user base includes social referrals. **WHY:** §9 — emulation lies.
- Specific iOS checks: `100vh/svh/dvh` usage, rubber-band overscroll, date picker native, keyboard + fixed position interaction, `backdrop-filter` prefix, autoplay `muted playsinline`.

### Phase 6 — Accessibility pass (automated → manual)
- **Automated:** axe DevTools + Lighthouse Accessibility + WAVE + IBM Equal Access. Aggregate distinct issues. **WHY:** 57% coverage floor.
- **Manual keyboard pass** (30 min): unplug mouse; Tab through; verify every interactive reachable, focus order logical, indicator always visible, Enter/Space behave as expected, Esc closes modals+restores focus, skip link appears, no traps.
- **Manual screen-reader pass** (45 min): at minimum NVDA+Firefox OR VoiceOver+Safari. Verify headings outline, landmarks named, images meaningfully described, form labels + error announcements, custom widgets announce role+state, live regions fire, SPA route changes announced.
- **Visual / zoom pass:** 400% zoom reflow; text-spacing bookmarklet; Windows High Contrast Mode (forced-colors); `prefers-reduced-motion` via DevTools Rendering panel.
- **Forms pass:** empty-submit generates identified errors with linked `aria-describedby` + `role="alert"`; error messages explain + suggest fix; no raw technical errors.

### Phase 7 — Performance pass
- **Field:** Query CrUX/PSI for p75 LCP, INP, CLS over 28 days on both mobile and desktop. **WHY:** Google ranking + real users.
- **Lab:** Lighthouse mobile config (4× CPU, slow 4G). Record TBT as INP proxy. Run Playwright with injected `web-vitals@5` IIFE for attribution.
- **Diagnose slow LCP:** Identify LCP element; check TTFB vs resource-load-delay vs load-duration vs render-delay; verify `fetchpriority="high"` on hero image, preload, `width`/`height` attributes, no render-blocking CSS/JS.
- **Diagnose INP/TBT:** Performance panel → long tasks >50ms; identify third-party scripts (chat, tag managers); check scheduler.yield / `useTransition` usage.
- **Diagnose CLS:** Rendering panel → Layout Shift Regions overlay; scroll whole page + wait 5s post-load (SPA route + lazy-load); verify `aspect-ratio`, skeletons, `font-display` strategy.
- **Doherty check:** User-initiated actions feedback <400ms; Nielsen 0.1/1/10s progress rules followed.

### Phase 8 — Post-audit synthesis
- **Severity triage:** Each issue gets Nielsen 0–4 using Frequency × Impact × Persistence + market-impact lens. Aggregate mean of evaluator/signal ratings.
- **Priority matrix:** 2×2 of severity × effort. Catastrophes (4) ship before release; Majors (3) top of backlog; Minors (2) queued; Cosmetics (1) batched.
- **Report structure:** Executive summary (top 5 issues + estimated business impact) → scorecards by heuristic/WCAG principle → issue log (screenshot, location, severity, WCAG SC if applicable, recommended fix, source citation) → remediation roadmap with owners + dates → appendix of tool outputs.
- **Deliverable formats:** Markdown issue log (for Claude Code ingestion), CSV for PM tooling, annotated Figma/PDF for stakeholders.

---

## Closing synthesis

Three convictions emerge from this corpus. First, **automation is the floor, not the ceiling**: Deque's own data shows axe catches 57% of WCAG issues by volume but only ~32% of SCs — and WebAIM Million 2026 just reversed six years of improvement (errors rising to 56.1/page, 95.9% of pages failing), attributed to AI-assisted coding and DOM complexity. Tools find what's present; humans find what's meaningful. Second, **the design system IS the audit tool** at mature organizations: Vercel's Toolbar ships contrast checks with every preview; IBM Carbon bakes WCAG AA into tokens; Airbnb's DLS was born from an audit and then became one; GitHub's Primer enforces a11y at the component layer. Third, **quality is cultural**: Linear's Karri Saarinen warns that "we replaced purpose with metrics" — every heuristic in this document can be reduced to a checkbox unless a team internalizes that "the spec is the baseline, not the finish line." An automated audit subagent should therefore not aspire to replace human judgment but to expose measurable ground truth — Core Web Vitals from real hardware, WCAG conformance at the SC level, Baymard-documented e-commerce failures, Nielsen heuristics with severity rationale — and leave the craft judgment to the humans it serves.