---
name: mobile-app-patterns
description: >
  Best-in-class mobile UI/UX patterns inspired by Duolingo, Linear, Arc, Raycast,
  Notion Mobile, Superhuman. MUST BE USED when designing, auditing, or fixing
  any mobile viewport (≤768px) — especially dashboards, lists, forms, modals,
  nav. Replaces "responsive-web-on-a-phone" thinking with genuine mobile-native
  patterns. Referenced by sd-audit (design-intelligence rubric), sd-fix
  (M-template fixes), and sd-research (component extraction from competitors).
version: 1.0.0
---

# mobile-app-patterns

## Philosophy

A mobile screen is **not** a shrunken desktop. It is a **thumb-reach device** used in 2–10 second sessions with one hand, often while walking/waiting/scrolling. Every pattern here is derived from apps people actually keep on their home screen.

## Reference apps (study these before designing)

| App | Why | Patterns to extract |
|---|---|---|
| **Duolingo** | Highest D7 retention in learning category | Compact metric rows, streak flames, XP hero, bottom nav with tab bubbles, full-screen lesson flow, celebration animations |
| **Linear Mobile** | Fastest feedback SaaS on mobile | Minimal chrome, swipe-to-action on list rows, bottom sheet for create, command-K style quick switcher |
| **Arc Mobile / Search** | Search-first nav | No bottom tabs — single tap to search/command, gesture stack for back |
| **Raycast iOS** | Power-user density | Compact list rows with inline metadata, command palette, no decorative chrome |
| **Notion Mobile** | Heavy content on small screen | Block-based editor, swipe to nest/unnest, floating action button for quick capture |
| **Superhuman** | Speed as the aesthetic | No loading states visible — optimistic everything, keyboard shortcuts respected on iPad, split-swipe archive/snooze |
| **Cash App** | Financial density without tables | Big number hero, compact transaction rows (avatar + name + amount + relative time), bottom-sheet send/receive |
| **Spotify** | Media density | Horizontal scroll rails (not cards in column), sticky now-playing bar, bottom tab nav |

## Core mobile patterns

### 1. Lists over cards (CRITICAL)

**Rule:** On mobile dashboards, `role=listitem` rows beat `role=region` cards for metrics, entities, and history. Cards waste 40–60% of viewport height on padding+radius+shadow for a single data point.

```tsx
// ANTI-PATTERN (what the beats-market admin dashboard did wrong)
<div className="flex flex-col gap-3">
  <Card><CardHeader>Total Users</CardHeader><CardContent>16</CardContent></Card>
  <Card><CardHeader>Producers</CardHeader><CardContent>5</CardContent></Card>
  <Card><CardHeader>Orders</CardHeader><CardContent>18</CardContent></Card>
  {/* 10+ cards = endless scroll, no density */}
</div>

// GOOD (Duolingo/Linear/Cash App style)
<ul className="divide-y divide-border">
  {metrics.map(m => (
    <li key={m.id} className="flex items-center justify-between py-3 px-4">
      <div className="flex items-center gap-3">
        <Icon name={m.icon} className="size-5 text-muted-foreground" />
        <span className="text-sm text-muted-foreground">{m.label}</span>
      </div>
      <span className="text-base font-semibold tabular-nums">{m.value}</span>
    </li>
  ))}
</ul>

// EVEN BETTER for a hero metric on mobile (Cash App style)
<section className="px-4 pt-6 pb-4">
  <p className="text-sm text-muted-foreground">Total revenue</p>
  <h1 className="text-4xl font-bold tabular-nums">R$1.389</h1>
  <p className="text-xs text-muted-foreground mt-1">+12% vs last month</p>
</section>
<ul className="divide-y">{/* supporting metrics as compact rows */}</ul>
```

**Density target:** A mobile viewport (390×844) should fit **at least 6–8 metrics above the fold**, not 2–3.

### 2. Hero + compact list (dashboard pattern)

```
┌─────────────────────────┐
│ ☰    Dashboard      👤 │  Header (56px fixed)
├─────────────────────────┤
│                         │
│   Total Revenue         │  HERO: 1 big number
│   R$ 1,389.00           │  that matters most
│   +12% this month  ↗    │
│                         │
├─────────────────────────┤
│ 👥  Users          16 │  Compact metric rows
│ 🎵  Producers       5 │  (44px each)
│ 📦  Active Packs   18 │
│ 🛒  Orders         18 │
│ 🔄  Refunds         0 │
│ 📊  Refund Rate  0.0% │
│ 🛡️  DMCA Claims     0 │
│ 💬  Open Tickets    1 │
├─────────────────────────┤
│ [Home][Metrics][Orders] │  Bottom tab nav (56px)
└─────────────────────────┘
```

### 3. Bottom nav (NOT hamburger) for top-level nav

- 3–5 tabs max. More → move to secondary screen via "More" tab.
- Each tab = a destination, not an action.
- Fixed position, 56–64px tall, with safe-area inset.
- Active state: fill icon + label always visible (not hidden).

```tsx
<nav className="fixed inset-x-0 bottom-0 z-40 border-t bg-background pb-[env(safe-area-inset-bottom)]">
  <ul className="flex h-14">
    {tabs.map(t => (
      <li key={t.id} className="flex-1">
        <Link
          href={t.href}
          aria-current={active === t.id ? 'page' : undefined}
          className="flex h-full flex-col items-center justify-center gap-1 text-xs"
        >
          <t.Icon className={cn('size-5', active === t.id ? 'fill-current' : '')} />
          <span className={active === t.id ? 'font-semibold' : 'text-muted-foreground'}>{t.label}</span>
        </Link>
      </li>
    ))}
  </ul>
</nav>
```

### 4. Bottom sheets (NOT centered modals) for actions

- Centered dialog on mobile = thumb cannot reach top-right close button.
- Bottom sheet slides up from the bottom, close via drag-down or button at top.
- Use `<dialog>` or Vaul/Radix + `vaul-drawer` libs.

### 5. Full-screen flows (NOT multi-step modals)

Onboarding, lesson completion, checkout, create-entity — all should be **full-screen pages** that replace the current view, with a close/back in the top-left, not modal overlays.

Duolingo lesson = full-screen. Cash App send = full-screen. Linear create-issue = bottom sheet → expand to full. Never a centered modal trying to cram a form.

### 6. Swipe actions on list rows

Archive / Delete / Snooze / Complete = left or right swipe on the row. Exposes discoverability via slight peek on first render.

Lib: `react-swipeable-list` / custom pointer-events handler. Always provide a long-press or trailing `[…]` button as a11y fallback.

### 7. Pull-to-refresh on scrollable lists

Native iOS/Android pattern. Every list that fetches server data should implement it. Lib: `react-pull-to-refresh` or Framer Motion gestures.

### 8. Typography scale for mobile

- Body: **16px** (never smaller — iOS triggers zoom on focus for <16px inputs)
- Meta / captions: 14px minimum, 13px absolute floor for tabular dense lists
- Headings: 20/24/32/40 — large hero numbers allowed (44–56px)
- Line-height: 1.4 body, 1.2 headings, 1.5 long-form reading

### 9. Touch targets

- **44×44 px minimum** (Apple HIG) or 48dp (Material) — NOT the WCAG 24px floor
- 8px gap between adjacent targets
- Full-width list rows: the whole row is the target, not just the text

### 10. Data tables → convert on mobile

Tables with >3 columns CANNOT fit at 375px. Transform:

| Original desktop | Mobile replacement |
|---|---|
| Users table (name, email, role, status, date, actions) | List of rows with avatar + primary text + compact metadata stack + trailing `[⋯]` menu |
| Orders table (id, buyer, items, total, payment, refund, downloads, actions) | Card per order: buyer + total prominent, metadata as chips, CTA row at bottom |
| Data grid | Virtualized list OR horizontal scroll with sticky first column (only if truly needed) |

## Mobile anti-patterns (auto-flag in audits)

| Anti-pattern | Why bad | Fix |
|---|---|---|
| Cards in `flex-col` for metrics | Wastes 40–60% vertical space | Compact list rows with divider |
| Desktop table <768px | Unreadable microtext or horizontal scroll hell | Card-per-row OR list with primary+meta |
| Hamburger menu as only nav | Hides primary destinations behind 1+ tap | Bottom tab bar (3–5 tabs) |
| Centered modal with close in top-right | Unreachable by thumb | Bottom sheet with drag handle |
| Input `font-size < 16px` | iOS Safari zooms in on focus | Use 16px or `font-size: max(16px, 1rem)` |
| Fixed header + fixed footer > 25% height | Leaves <75% for content | Collapse header on scroll (framer shrink) |
| Multi-column layout <600px | Nothing fits | Single column or horizontal rail |
| Hover-only affordances | Touch has no hover | Gate `@media (hover: hover)` + tap equivalent |
| Tiny close buttons (<24×24) | Missed taps | 44×44 hit area even if icon is smaller |
| Toast in top-right | Thumb can't dismiss | Bottom-center toast with swipe-down |
| 100vh anywhere | iOS Safari URL bar breaks it | `100svh` / `100dvh` with `-webkit-fill-available` fallback |
| Pull-to-refresh inside inner scroll | Conflicts with browser pull | `overscroll-behavior: contain` |

## Competitor reference for mobile patterns by domain

| Your app type | Study these on mobile |
|---|---|
| Admin / SaaS dashboard | Linear, Height, Plane, Vercel dashboard |
| Marketplace (buyer) | Instagram Shop, Depop, Vinted, Mercari |
| Marketplace (seller) | Shopify Mobile, Etsy Seller, Depop |
| E-commerce checkout | Shop App, Amazon, Stripe Checkout (in a WebView) |
| Social / community | Discord, Slack, Twitter (X), BlueSky |
| Learning / habit | Duolingo, Brilliant, Finch, Streaks |
| Finance / fintech | Cash App, Revolut, Mercury, Ramp |
| Productivity | Notion, Linear, Raycast, Things 3 |
| Media | Spotify, Apple Music, YouTube |

## How to use this skill

- **sd-audit** references these anti-patterns as M-category findings (M1–M12).
- **sd-fix** applies M-templates with code snippets directly from this skill.
- **sd-research** studies competitors' mobile viewports against this pattern library, not just home pages.
- **frontend-design** plugin cross-references this skill when generating mobile UI.

## Mandatory mobile audit checklist (≤375px viewport)

```
□ Primary nav is bottom tabs (3-5), not hamburger-only
□ Dashboards use hero + compact list, not card stack
□ Tables transformed to card-per-row or compact list
□ No input has font-size < 16px
□ Every interactive target ≥ 44×44 px
□ Modals are bottom sheets or full-screen, not centered
□ No hover-only state; every hover has a tap equivalent
□ Loading states exist for async flows
□ Empty states exist for zero-data cases
□ Error states exist for server failures
□ Safe-area insets respected (iOS notch, home indicator)
□ Text uses 100svh / 100dvh (not 100vh) for full-height
□ Scroll containers use overscroll-behavior: contain
□ Pull-to-refresh implemented on primary list views
□ Swipe actions discoverable (peek on first render)
□ Back gesture (iOS) works via browser history
□ Keyboard does not overlap input (visualViewport API)
□ Touch targets 8px+ apart
□ Long-press fallback for swipe actions
□ Bottom sheet CTAs sticky above safe area
```

## References

- Linear Method — https://linear.app/method
- Vercel Design Engineering — https://vercel.com/blog/design-engineering-at-vercel
- iOS HIG Touch Targets — https://developer.apple.com/design/human-interface-guidelines/layout
- Material 3 Bottom App Bar — https://m3.material.io/components/bottom-app-bar/overview
- NN/g Mobile UX — https://www.nngroup.com/topic/mobile-and-tablet-design/
- Baymard Mobile Checkout — https://baymard.com/checkout-usability
