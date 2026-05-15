# UI/UX Audit System - UseFlow Marketplace

## Purpose

This directory contains all UI/UX research, audits, and design documentation for the UseFlow marketplace platform.

---

## Directory Structure

```
ui-ux-audit/
├── README.md              # This file - Index and overview
├── SKILL.md               # Skill definition and workflow
├── research/              # Competitor research and market analysis
├── audits/                # UI/UX audit reports
├── templates/             # Documentation templates
└── cache/                 # Cached research data
```

---

## Current Design System

### Technology Stack

| Component       | Technology                |
| --------------- | ------------------------- |
| Framework       | Next.js 15.2.4 + React 19 |
| Styling         | Tailwind CSS 3.4.17       |
| UI Components   | shadcn/ui (Radix UI)      |
| Animations      | Framer Motion 12.23.26    |
| Icons           | Lucide React 0.454.0      |
| Charts          | Recharts (latest)         |
| Form Management | React Hook Form           |
| Validation      | Zod 3.24.1                |

### Design Tokens

#### Colors

**Primary Palette - Violet (Modern)**

- Primary: `hsl(262, 83%, 58%)` - #8B5CF6
- Primary variants: 50-900 scale
- Warm gray scale for neutrals

**Semantic Colors**

- Success: `#22C55E` (green)
- Warning: `#EAB308` (yellow)
- Error: `#EF4444` (red)
- Info: `#3B82F6` (blue)

**Platform Colors**

- Instagram: `#E1306C` + gradient
- YouTube: `#FF0000` + gradient
- TikTok: `#000000` with cyan/pink accents

#### Typography

**Font Families**

- Sans: Inter (default)
- Display: Plus Jakarta Sans
- Mono: JetBrains Mono

**Scale**

- Uses Tailwind default scale
- Custom spacing: 18, 88, 128

#### Spacing

**System**

- 4px base scale (Tailwind default)
- Container padding: 2rem
- Max width: 1400px (2xl breakpoint)

#### Border Radius

- Default: 0.75rem (12px)
- sm: calc(0.75rem - 4px)
- md: calc(0.75rem - 2px)
- lg: 0.75rem
- xl: 12px
- 2xl: 16px

#### Shadows

- soft: `0 2px 8px -2px rgba(0, 0, 0, 0.1)`
- medium: `0 4px 16px -4px rgba(0, 0, 0, 0.1)`
- large: `0 8px 32px -8px rgba(0, 0, 0, 0.15)`
- glow-primary: `0 0 20px rgba(139, 92, 246, 0.3)`
- glow-pink: `0 0 20px rgba(236, 72, 153, 0.3)`

#### Animations

**Built-in Animations**

- accordion-down/up
- fade-in, fade-in-up
- slide-up, slide-down, slide-in-right, slide-in-left
- scale-in
- spin-slow, pulse-soft
- shimmer, float, gradient-x, bounce-soft

**Custom Keyframes**

- blob, gradient-shift, particles

---

## Component Inventory

### UI Components (shadcn/ui)

**Layout**

- accordion
- card
- collapsible
- resizable
- scroll-area
- separator
- sidebar
- tabs

**Navigation**

- breadcrumb
- command
- context-menu
- dropdown-menu
- menubar
- navigation-menu
- pagination

**Forms**

- button
- checkbox
- form
- input
- input-otp
- label
- radio-group
- select
- slider
- switch
- textarea

**Overlays**

- alert-dialog
- dialog
- drawer
- hover-card
- popover
- sheet
- tooltip

**Feedback**

- alert
- badge
- progress
- skeleton
- sonner (toast)
- toast
- toaster

**Data Display**

- aspect-ratio
- avatar
- calendar
- carousel
- chart
- table

**Utility**

- toggle
- toggle-group
- use-mobile (hook)
- use-toast (hook)

### Magic UI Components (Custom Animations)

- animated-card
- animated-list
- animated-skeleton
- number-ticker
- shimmer-button

### Marketplace Components

**Filter System**

- FilterSidebar (desktop)
- MobileFilters (mobile)

### Feature Components

**Admin**

- AccountsManagement
- AdminStats
- AnalyticsDashboard
- EscrowManagement
- IntentsManagement
- ReportsGenerator
- ReportsManagement
- SystemLogs
- TransactionsManagement
- UsersManagement

**Escrow**

- DeadlineTimer

**Profile**

- ProfileStats
- PurchasesList
- SalesList

**Purchases**

- BuyerEscrowModal
- PurchaseCard
- PurchaseStatsCards

**Sales**

- AccountCard
- EditAccountModal
- EscrowModal
- FiltersSection
- StatsCards
- TransactionCard

**Wallet**

- DepositModal
- IntentsHistory
- QRCodeModal

**Global**

- AccountStatusModal
- AuthGuard
- ImageUpload
- NotificationBell

### Providers

- DepositModalContext
- ModalContext
- Providers (root provider)
- SessionProvider
- UserContext
- theme-provider

---

## Page Inventory

### Public Pages

- `/` - Homepage/Landing
- `/marketplace` - Marketplace listing
- `/marketplace/[id]` - Account detail
- `/login` - Login
- `/registro` - Registration
- `/forgot-password` - Password recovery
- `/verify-email` - Email verification
- `/termos` - Terms of service
- `/contato` - Contact

### Authenticated Pages

- `/carteira` - Wallet
- `/perfil` - Profile
- `/vender` - Sell account
- `/minhas-vendas` - My sales
- `/minhas-compras` - My purchases
- `/escrow` - Escrow list
- `/escrow/[id]` - Escrow detail
- `/logout` - Logout

### Admin Pages

- `/admin` - Admin dashboard

---

## Current UI/UX Patterns

### Layout Strategy

**Desktop (1280px+)**

- Sidebar navigation
- Multi-column layouts
- Dense information display
- Hover interactions

**Mobile (375px+)**

- Bottom navigation
- Single column stack
- Touch-friendly (44x44px targets)
- Swipe gestures

### Loading States

**Pattern: Skeleton Loading**

- All components have matching skeletons
- Same dimensions as final content
- `animate-pulse` animation
- Maintains layout structure

### Interactive Patterns

**Cards**

- Hover lift effect
- Smooth transitions (0.3s cubic-bezier)
- Shadow on hover
- Optional scale effect

**Buttons**

- Primary: Violet gradient
- Secondary: Muted background
- Disabled: 50% opacity
- Focus ring: 2px primary

**Forms**

- Inline validation
- Error messages below field
- Focus ring on inputs
- Label above input

### Responsive Strategy

**Mobile-First**

- Base styles for mobile
- Progressive enhancement
- Breakpoints: sm (640), md (768), lg (1024), xl (1280), 2xl (1400)

**Overflow Prevention**

- No horizontal scroll allowed
- `min-w-0` on flex children
- `overflow-hidden` on containers
- `flex-shrink-0` on fixed width elements

---

## Research Index

### Completed Research

(None yet - to be added by research agent)

### Pending Research

1. Competitor marketplace analysis
2. Filter/search UX patterns
3. Escrow flow best practices
4. Mobile marketplace navigation
5. Trust indicators and badges

---

## Audit Index

### Completed Audits

(None yet - to be added by ui-ux-reviewer agent)

### Pending Audits

1. WCAG 2.1 compliance
2. Responsive design validation
3. Touch target sizes
4. Color contrast ratios
5. Keyboard navigation

---

## Templates

See `templates/` directory for:

- Competitor analysis template
- Component specification template
- Improvement recommendation template
- Audit report template

---

## Usage Guidelines

### For Research Agent

1. Store competitor research in `research/[topic].md`
2. Use template from `templates/competitor-analysis.md`
3. Include screenshots and URLs
4. Update this README with research index

### For UI/UX Reviewer Agent

1. Store audit reports in `audits/[feature]-audit.md`
2. Use template from `templates/audit-report.md`
3. Include WCAG compliance checklist
4. Update this README with audit index

### For Implementer Agents

1. Check existing research before new features
2. Follow design system tokens
3. Use existing component patterns
4. Create matching skeleton loaders
5. Test all required viewports

---

## Quality Standards

### Accessibility (WCAG 2.1 Level AA)

- [ ] Text contrast: 4.5:1 normal, 3:1 large
- [ ] Touch targets: Minimum 44x44px
- [ ] Keyboard navigation: All interactive elements
- [ ] Screen reader: Semantic HTML + ARIA
- [ ] Alt text: All images
- [ ] Form labels: All inputs

### Responsiveness

- [ ] Mobile (375px): Single column, touch-friendly
- [ ] Tablet (768px): Optimized layout
- [ ] Desktop (1280px): Full features
- [ ] FullHD (1920px): No overflow
- [ ] Zero horizontal scroll

### Performance

- [ ] Skeleton loading states
- [ ] Lazy loading images
- [ ] Code splitting
- [ ] Optimized animations (prefers-reduced-motion)
- [ ] Minimal layout shift

---

## Version

- **v1.0.0** - Initial structure (2025-12-19)
- Created by: Documenter Agent
- Last updated: 2025-12-19
