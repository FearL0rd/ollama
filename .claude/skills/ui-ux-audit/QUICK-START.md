# UI/UX Audit - Quick Start Guide

**For:** Research, UI/UX Reviewer, and Implementer Agents
**Last Updated:** 2025-12-19

---

## Directory Structure

```
.claude/skills/ui-ux-audit/
├── README.md              # Complete overview & design system
├── SKILL.md               # Skill workflow & checklists
├── QUICK-START.md         # This file
├── cache/
│   ├── component-inventory.md    # All 95+ components
│   └── current-state.md          # Current UI/UX analysis
├── research/              # Competitor research (to be filled)
├── audits/                # Audit reports (to be filled)
└── templates/
    ├── competitor-analysis.md
    ├── component-spec.md
    ├── improvement-recommendation.md
    └── audit-report.md
```

---

## For Research Agent

### Your Mission

Research competitors and document UI/UX patterns.

### Steps

1. **Read Templates:**
    - Open `templates/competitor-analysis.md`
    - This is your structure

2. **Research Focus:**
    - Marketplace listing UX
    - Filter/search patterns
    - Trust indicators
    - Escrow flow UX
    - Mobile navigation

3. **Competitors to Analyze:**
    - PlayerAuctions
    - G2G
    - EpicNPC
    - SocialTradia
    - FameSwap

    **Search queries:**
    - "digital account marketplace UI"
    - "social media account trading platform"
    - "escrow marketplace design"
    - "mobile marketplace navigation"

4. **Save Research:**
    - File: `research/[topic]-ux.md`
    - Example: `research/marketplace-listing-ux.md`
    - Use template structure
    - Include screenshots/links

5. **Update Index:**
    - Add to README.md "Research Index"

---

## For UI/UX Reviewer Agent

### Your Mission

Audit existing UI/UX for accessibility, responsiveness, and usability.

### Steps

1. **Read Templates:**
    - Open `templates/audit-report.md`
    - This is your structure

2. **Audit Focus:**
    - WCAG 2.1 compliance
    - Color contrast (4.5:1 minimum)
    - Touch targets (44x44px minimum)
    - Keyboard navigation
    - Screen reader compatibility
    - Responsive design (375px - 1920px)

3. **Tools to Use:**
    - Chrome DevTools
    - Lighthouse
    - WAVE (browser extension)
    - axe DevTools
    - Contrast checker

4. **Save Audits:**
    - File: `audits/[feature]-audit.md`
    - Example: `audits/marketplace-listing-audit.md`
    - Use template structure
    - Include screenshots

5. **Update Index:**
    - Add to README.md "Audit Index"

---

## For Implementer Agents

### Before Implementing UI

**ALWAYS:**

1. **Check Component Inventory:**

    ```
    Read: cache/component-inventory.md
    ```

    - Does the component already exist?
    - Can you reuse an existing component?

2. **Review Design System:**

    ```
    Read: README.md (Design Tokens section)
    ```

    - What colors should I use?
    - What spacing/shadows/animations?

3. **Check Current State:**

    ```
    Read: cache/current-state.md
    ```

    - Are there known issues in this area?
    - What patterns should I follow?

4. **Review Research:**
    ```
    Check: research/ directory
    ```

    - Has this feature been researched?
    - What patterns do competitors use?

### When Creating New Components

1. **Use Template:**

    ```
    Copy: templates/component-spec.md
    Fill out all sections
    ```

2. **Follow Patterns:**
    - File naming: `ComponentName.tsx`
    - Props naming: `ComponentNameProps`
    - Use `cn()` for className merging

3. **Create Skeleton:**
    - Every component needs a loading skeleton
    - File: `ComponentNameSkeleton.tsx`
    - Match final component dimensions

4. **Check Accessibility:**
    - Contrast: 4.5:1 minimum
    - Touch targets: 44x44px
    - Keyboard navigation
    - ARIA labels
    - Screen reader testing

5. **Test Responsiveness:**
    - Mobile (375px)
    - Tablet (768px)
    - Desktop (1280px)
    - FullHD (1920px)
    - No horizontal scroll

---

## Design System Quick Reference

### Colors (CSS Variables)

```tsx
// Use Tailwind classes
bg-primary        // Violet
bg-secondary      // Gray
bg-destructive    // Red
bg-success        // Green
bg-warning        // Yellow
bg-error          // Red
bg-info           // Blue

// Or HSL variables
hsl(var(--primary))
hsl(var(--secondary))
```

### Typography

```tsx
// Font families
font-sans         // Inter (default)
font-display      // Plus Jakarta Sans (headings)
font-mono         // JetBrains Mono (code)

// Sizes (Tailwind default)
text-sm, text-base, text-lg, text-xl, text-2xl...
```

### Spacing

```tsx
// Use Tailwind 4px scale
p - 1; // 4px
p - 2; // 8px
p - 4; // 16px
p - 6; // 24px
p - 8; // 32px
```

### Border Radius

```tsx
rounded-lg        // 0.75rem (default)
rounded-xl        // 12px
rounded-2xl       // 16px
```

### Shadows

```tsx
shadow - soft; // Subtle
shadow - medium; // Standard
shadow - large; // Emphasis
shadow - glow - primary; // Special
```

### Animations

```tsx
animate-fade-in
animate-slide-up
animate-shimmer
animate-pulse-soft
```

---

## Common Patterns

### Button

```tsx
import { Button } from '@/components/ui/button';

<Button variant="default">Primary</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="outline">Outline</Button>
<Button variant="ghost">Ghost</Button>
```

### Modal

```tsx
import { Dialog, DialogContent, DialogHeader } from '@/components/ui/dialog';

<Dialog open={open} onOpenChange={setOpen}>
	<DialogContent>
		<DialogHeader>
			<DialogTitle>Title</DialogTitle>
		</DialogHeader>
		{/* Content */}
	</DialogContent>
</Dialog>;
```

### Form

```tsx
import { useForm } from 'react-hook-form';
import { Form, FormField, FormItem, FormLabel } from '@/components/ui/form';

const form = useForm();

<Form {...form}>
	<FormField
		control={form.control}
		name="field"
		render={({ field }) => (
			<FormItem>
				<FormLabel>Label</FormLabel>
				<Input {...field} />
			</FormItem>
		)}
	/>
</Form>;
```

### Loading State

```tsx
import { Skeleton } from '@/components/ui/skeleton';

{
	loading ? <Skeleton className="h-10 w-full" /> : <div>Content</div>;
}
```

### Toast

```tsx
import { toast } from 'sonner';

toast.success('Success message');
toast.error('Error message');
toast.info('Info message');
```

---

## Accessibility Checklist

**Before Submitting:**

- [ ] Text contrast: 4.5:1 minimum (use contrast checker)
- [ ] Touch targets: 44x44px minimum
- [ ] Keyboard navigation: Tab through all elements
- [ ] Focus visible: Clear outline on focused elements
- [ ] ARIA labels: All interactive elements labeled
- [ ] Alt text: All images have descriptive alt
- [ ] Screen reader: Test with NVDA/VoiceOver

---

## Responsiveness Checklist

**Test Viewports:**

- [ ] Mobile (375px): Single column, touch-friendly
- [ ] Tablet (768px): Optimized layout
- [ ] Desktop (1280px): Full features
- [ ] FullHD (1920px): No overflow

**No Horizontal Scroll:**

- [ ] Check all viewports
- [ ] Use `overflow-hidden` on containers
- [ ] Use `min-w-0` on flex children

---

## File Locations

### Read Before Implementing

| File                           | What You'll Find            |
| ------------------------------ | --------------------------- |
| `cache/component-inventory.md` | All 95+ existing components |
| `cache/current-state.md`       | Current UI/UX analysis      |
| `README.md`                    | Design system tokens        |
| `SKILL.md`                     | Workflow & checklists       |

### Write When Done

| File                         | What to Write            |
| ---------------------------- | ------------------------ |
| `research/[topic]-ux.md`     | Competitor research      |
| `audits/[feature]-audit.md`  | Audit reports            |
| Component docs (if creating) | Component specifications |

---

## Getting Help

### Questions About...

**Design System:**

- Read: `README.md` (Design Tokens section)
- Check: `cache/current-state.md` (Design System section)

**Existing Components:**

- Read: `cache/component-inventory.md`
- Check: `components/ui/` directory

**Accessibility:**

- Read: `SKILL.md` (Accessibility Checklist)
- Check: `README.md` (Quality Standards section)

**Responsiveness:**

- Read: `SKILL.md` (Responsiveness Checklist)
- Check: `cache/current-state.md` (Responsive Strategy)

---

## Quick Commands

### Analyze Components

```bash
# Count components
ls components/ui/*.tsx | wc -l

# Find component
grep -r "ComponentName" components/
```

### Check Design System

```bash
# View CSS variables
cat app/globals.css | grep "^[[:space:]]*--"

# View Tailwind config
cat tailwind.config.ts
```

### Verify Structure

```bash
# Check ui-ux-audit structure
ls -R .claude/skills/ui-ux-audit/
```

---

## Status Codes

When updating files, use these status markers:

- **[NEW]** - Newly added
- **[UPDATED]** - Modified
- **[DEPRECATED]** - No longer recommended
- **[CRITICAL]** - Important rule/requirement
- **[PENDING]** - Needs attention

---

**Quick Start Version:** 1.0.0
**Last Updated:** 2025-12-19
