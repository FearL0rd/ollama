# Component, Modal & Flow Discovery Playbook

> How sd-audit systematically exercises EVERY interactive element before
> running heuristics. Without this, the audit only sees static page snaps
> and misses modal contents, flow state, hover/focus/active variants, and
> loading/empty/error states.
>
> This playbook runs as **Step 2.5** in sd-audit, after route discovery
> and before per-viewport heuristic passes.

## Why this matters

Static screenshots of pages show ~30% of what users interact with. The other 70%
lives inside modals, drawers, dropdowns, command palettes, error flows, empty
states, loading states, hover menus, focus rings. A page can score 95/100 on
Lighthouse and be unusable because its "Create" modal is broken — and the
auditor never opened it.

## Discovery phases

### Phase A — Interactive inventory (per page × viewport)

After navigating and dismissing banners:

```js
// browser_evaluate
(() => {
  const roots = [
    '[role="button"]',
    'button',
    'a[href]',
    '[role="link"]',
    '[role="menuitem"]',
    '[role="tab"]',
    '[role="switch"]',
    '[role="checkbox"]',
    '[role="radio"]',
    '[aria-haspopup]',
    '[aria-expanded]',
    '[data-trigger]',
    '[data-state]',
    'input',
    'select',
    'textarea',
    'summary',
  ];
  const items = [];
  roots.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      if (!el.offsetParent && getComputedStyle(el).position !== 'fixed') return;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) return;
      items.push({
        selector: sel,
        tag: el.tagName,
        role: el.getAttribute('role'),
        name: el.getAttribute('aria-label') || el.textContent?.trim().slice(0, 60) || '',
        type: el.getAttribute('type'),
        haspopup: el.getAttribute('aria-haspopup'),
        expanded: el.getAttribute('aria-expanded'),
        disabled: el.disabled || el.getAttribute('aria-disabled') === 'true',
        rect: { x: r.x, y: r.y, w: r.width, h: r.height },
      });
    });
  });
  return items;
})()
```

Save to `.super-design/sessions/<id>/interactive/<slug>_<vp>.json`.

Classify each:
- **navigation** — links, tabs, back buttons
- **action** — primary CTAs, submit, delete, save
- **trigger** — opens modal/drawer/dropdown (`aria-haspopup`, `data-trigger`)
- **input** — form fields
- **state-toggle** — switches, checkboxes, expanders

### Phase B — Modal & overlay discovery

For each trigger from Phase A:

```
1. Pre-click snapshot (already have from Phase 1)
2. browser_click({ ref })   # click the trigger
3. browser_wait_for(text="<expected modal content>") or 500ms
4. browser_snapshot → save as snapshots/<slug>_<vp>_<triggerName>_open.yaml
5. browser_take_screenshot fullPage + element-scoped → screens/components/
6. browser_console_messages(level="error") → record
7. Inside open modal, run Phase A again (nested inventory)
8. Look for [role="dialog"] or [data-state="open"] to confirm it opened
9. Exercise modal internals:
   - Tab through to find focus trap
   - Press Escape to confirm dismiss
   - Resize to mobile — check if it becomes bottom-sheet
10. Close modal (button or Escape)
11. Re-snapshot → confirm background restored, focus returned to trigger
```

**Modals a junior agent misses:**
- Confirmation dialogs (delete confirm, logout confirm)
- Date pickers (calendar popover)
- Color pickers
- Combobox dropdowns (autocomplete search)
- Popover menus (dropdown with options)
- Sheet / drawer (slide-in from right or bottom)
- Command palette (Cmd+K)
- Tooltips (hover-triggered on desktop)
- Toast notifications (programmatic — trigger an action that causes one)
- Error modals (submit invalid form)
- Share sheets
- File upload dialogs (click input[type=file])

### Phase C — Flow exercising

A **flow** is a multi-step user journey. Every app has 3–10 critical flows.
sd-audit must auto-discover and exercise them.

**Auto-discover flows from routes + component names:**

| Route / name hint | Flow |
|---|---|
| `/login`, `/signin`, `/auth` | Login flow (happy + wrong password + locked account) |
| `/register`, `/signup` | Registration flow |
| `/forgot`, `/reset` | Password reset flow |
| `/onboarding`, `/welcome` | First-run flow |
| `/checkout`, `/cart` | Checkout flow (incl. errors: declined card, validation) |
| `/dashboard`, `/home` (authed) | Post-auth landing → primary CTA flow |
| List route (`/users`, `/orders`) | CRUD — create, edit, view, delete, filter, search, paginate |
| Detail route (`/users/:id`) | Edit flow, delete flow, related actions |
| `/settings`, `/profile` | Profile edit, preference toggles, account delete |
| `/support`, `/help`, `/chat` | Messaging flow |

**Per flow:**

```
1. Plan steps (list of expected screens + actions)
2. Execute step-by-step:
   - Navigate / click to advance
   - Per step: snapshot + screenshot + console
   - Test error path (invalid input, network error via DevTools)
   - Test back button preserves state
3. Capture final success state (confirmation page, toast, redirect)
4. If flow depends on creating test data, use burner account
```

Save per-flow artifacts under `.super-design/sessions/<id>/flows/<flow_name>/step_NN_<action>.png`.

### Phase D — State matrix per component

For each UI component class (Button, Input, Card, ListRow, Modal, NavItem…),
capture:

| State | How to trigger |
|---|---|
| default | Initial render |
| hover | `browser_hover` (desktop only, gate `@media hover`) |
| focus | Tab to element via `browser_press_key(Tab)` until focused |
| focus-visible | Same as focus (most systems collapse them now) |
| active | `browser_press_key` Enter/Space while focused |
| disabled | Find a disabled example (e.g., form before valid) |
| loading | Submit form → catch transient state; OR throttle network via DevTools |
| error | Invalid input + submit |
| empty | Navigate to route with no data (burner account OR delete all) |
| success | Complete a flow successfully |
| selected | Click tab / radio / checkbox that shows selected variant |

Save per component class:
```
.super-design/sessions/<id>/components/
  Button/
    default.png
    hover.png
    focus.png
    active.png
    disabled.png
    loading.png
  Input/...
  Modal/...
```

Output `.super-design/sessions/<id>/component-state-matrix.json`:

```json
{
  "Button": {
    "states_captured": ["default", "hover", "focus", "active", "disabled", "loading"],
    "states_missing": ["error"],
    "evidence": { "default": "components/Button/default.png", "..." }
  },
  "...": {}
}
```

**Missing states → finding.**

### Phase E — Form state coverage

Per form discovered, test:
1. Empty submit → validation messages
2. Each field invalid individually → per-field error
3. All valid → success state
4. Server error (simulate 500) → error recovery
5. Network offline → offline handling
6. Paste into password field → paste NOT blocked
7. Autocomplete tokens on login fields (`username`, `current-password`, `one-time-code`)
8. Tab order matches visual order
9. Submit via Enter key works
10. Mobile viewport — input zoom behavior (iOS Safari `font-size < 16px`?)

Save: `.super-design/sessions/<id>/forms/<formId>_<scenario>.png`

## Orchestration summary

sd-audit adds this between Step 2 and Step 3:

```
Step 2.5 — Discovery
  For each (page, viewport):
    A. Interactive inventory
    B. Modal/overlay enumeration (click every trigger)
    C. Flow exercising (login, CRUD, checkout if applicable)
    D. Component state matrix
    E. Form state coverage
```

This takes 3–5× longer than static-only audit but produces ~3× the findings,
each with real evidence of failure conditions (not just hypothetical WCAG
violations on static markup).

## Budget & skipping

For very large apps, scope Phase B/C/D to:
- Top 5 most-clicked triggers per page (ranked by proximity to primary CTA)
- Critical flows only (login + checkout + 1 CRUD)
- 3 component classes minimum (Button, Input, Modal) — rest deferred to full-mode audit

Record what was skipped in `.super-design/sessions/<id>/scope.json` so later
runs can close the gap.

## Error handling

- **Triggered modal doesn't appear within 2s** — record "trigger broken" finding, move on
- **Console error after click** — record verbatim, still capture whatever rendered
- **Focus not trapped** — record a11y violation
- **Modal close fails** — force navigate away, record "close broken" finding

Never let a broken trigger abort the full audit — isolate and continue.

## Hard rules

1. Every Phase A inventory item must be considered for exercising; skips recorded.
2. Every modal opened must be screenshotted OPEN + CLOSED.
3. Every flow must capture at least one error path, not just happy path.
4. Component state matrix must declare which states are MISSING (not just captured).
5. Form state coverage — 10 scenarios per form; partial completion records which.
6. Use ONE Playwright session; reuse across phases; `browser_close` only at end.
7. Sequential, not parallel. Never spawn parallel tabs.
