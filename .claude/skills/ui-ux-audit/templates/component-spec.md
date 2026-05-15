# Component Specification: [Component Name]

**Date:** YYYY-MM-DD
**Author:** [Agent name]
**Status:** [Draft/Review/Approved/Implemented]

---

## Overview

### Purpose

[What problem does this component solve?]

### Context

[Where and when is this component used?]

### User Stories

1. As a [user type], I need to [action] so that [benefit]
2. As a [user type], I need to [action] so that [benefit]
3. As a [user type], I need to [action] so that [benefit]

---

## Visual Design

### Desktop (1280px+)

```
[ASCII mockup or description]
┌─────────────────────────────────────┐
│  [Component layout]                 │
│  ┌──────┐  ┌───────────────────┐   │
│  │ Icon │  │ Content           │   │
│  └──────┘  │                   │   │
│            └───────────────────┘   │
└─────────────────────────────────────┘
```

**Dimensions:**

- Width: [value]
- Height: [value]
- Padding: [value]
- Margin: [value]

### Mobile (375px+)

```
[ASCII mockup or description]
┌───────────────┐
│  [Component]  │
│  [Stacked]    │
│  [Layout]     │
└───────────────┘
```

**Dimensions:**

- Width: [value]
- Height: [value]
- Padding: [value]
- Margin: [value]

### Responsive Breakpoints

| Breakpoint | Width    | Layout Changes |
| ---------- | -------- | -------------- |
| Mobile     | < 640px  | [Description]  |
| Tablet     | 640-1024 | [Description]  |
| Desktop    | > 1024px | [Description]  |

---

## Component API

### Props

```typescript
interface [ComponentName]Props {
  // Required props
  [propName]: [type];  // [Description]

  // Optional props
  [propName]?: [type]; // [Description]

  // Event handlers
  on[Event]?: (data: [type]) => void; // [Description]

  // Styling
  className?: string;  // Additional CSS classes
  style?: React.CSSProperties; // Inline styles
}
```

### Example Usage

```tsx
import { [ComponentName] } from '@/components/[path]';

export default function Example() {
  const handle[Event] = (data: [type]) => {
    // Event handler logic
  };

  return (
    <[ComponentName]
      [prop]="[value]"
      on[Event]={handle[Event]}
      className="[additional classes]"
    />
  );
}
```

---

## States & Variants

### Default State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Hover State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Active/Focus State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Disabled State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Loading State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Error State

[Description and visual representation]

**Styling:**

```css
/* Key classes or styles */
```

### Variants

| Variant Name | Description          | Use Case      |
| ------------ | -------------------- | ------------- |
| [name]       | [Visual description] | [When to use] |

---

## Behavior

### Interactions

1. **[Interaction 1]**
    - Trigger: [What user does]
    - Response: [What component does]
    - Animation: [If applicable]

2. **[Interaction 2]**
    - Trigger: [What user does]
    - Response: [What component does]
    - Animation: [If applicable]

### Animations

| Animation | Trigger | Duration | Easing            |
| --------- | ------- | -------- | ----------------- |
| [name]    | [When]  | [Time]   | [Easing function] |

### Keyboard Navigation

| Key        | Action         |
| ---------- | -------------- |
| Tab        | [What happens] |
| Shift+Tab  | [What happens] |
| Enter      | [What happens] |
| Space      | [What happens] |
| Escape     | [What happens] |
| Arrow keys | [What happens] |

### Touch Gestures

| Gesture    | Action         |
| ---------- | -------------- |
| Tap        | [What happens] |
| Long press | [What happens] |
| Swipe      | [What happens] |
| Pinch      | [What happens] |

---

## Design Tokens

### Colors

```css
/* Component-specific colors */
--component-bg: [value];
--component-text: [value];
--component-border: [value];
--component-hover: [value];
--component-active: [value];
```

**From Design System:**

- Primary: `hsl(var(--primary))`
- Secondary: `hsl(var(--secondary))`
- [etc]

### Typography

```css
/* Text styles */
--component-font-size: [value];
--component-font-weight: [value];
--component-line-height: [value];
--component-letter-spacing: [value];
```

### Spacing

```css
/* Internal spacing */
--component-padding-x: [value];
--component-padding-y: [value];
--component-gap: [value];
```

### Border & Shadow

```css
/* Visual effects */
--component-border-radius: [value];
--component-border-width: [value];
--component-shadow: [value];
```

---

## Accessibility

### WCAG Compliance

- [ ] **Contrast:** Meets 4.5:1 ratio for text
- [ ] **Touch Targets:** Minimum 44x44px
- [ ] **Keyboard:** Full keyboard navigation
- [ ] **Focus:** Visible focus indicator
- [ ] **Labels:** All elements properly labeled
- [ ] **ARIA:** Appropriate ARIA attributes
- [ ] **Screen Reader:** Tested with screen reader

### ARIA Attributes

```tsx
<[ComponentName]
  role="[role]"
  aria-label="[label]"
  aria-labelledby="[id]"
  aria-describedby="[id]"
  aria-expanded="[boolean]"
  aria-controls="[id]"
  aria-live="[off|polite|assertive]"
/>
```

### Screen Reader Announcements

| Event   | Announcement                |
| ------- | --------------------------- |
| [Event] | "[What screen reader says]" |

---

## Performance

### Loading Strategy

- [ ] Lazy loaded
- [ ] Code split
- [ ] Preloaded
- [ ] Eagerly loaded

**Rationale:** [Why this strategy?]

### Bundle Size

- Estimated: [size] KB
- With dependencies: [size] KB

### Optimization

- [ ] Memoized with React.memo
- [ ] Uses useCallback for handlers
- [ ] Uses useMemo for computed values
- [ ] Debounced/throttled where needed
- [ ] Virtualized if list/grid

---

## Dependencies

### External Libraries

| Library | Version | Purpose           |
| ------- | ------- | ----------------- |
| [name]  | [ver]   | [Why it's needed] |

### Internal Dependencies

| Component/Hook | Purpose           |
| -------------- | ----------------- |
| [name]         | [Why it's needed] |

---

## File Structure

```
components/[feature]/[ComponentName]/
├── [ComponentName].tsx           # Main component
├── [ComponentName]Skeleton.tsx   # Loading skeleton
├── [ComponentName].test.tsx      # Unit tests
├── [ComponentName].stories.tsx   # Storybook stories (if used)
└── index.ts                      # Barrel export
```

---

## Testing

### Unit Tests

```typescript
describe('[ComponentName]', () => {
	it('should render with default props', () => {
		// Test
	});

	it('should handle [interaction]', () => {
		// Test
	});

	it('should be accessible', () => {
		// Test
	});
});
```

### E2E Test Scenarios

1. [Scenario 1 - description]
2. [Scenario 2 - description]
3. [Scenario 3 - description]

### Visual Regression

- [ ] Desktop viewport
- [ ] Mobile viewport
- [ ] Dark mode
- [ ] Light mode
- [ ] Hover states
- [ ] Focus states

---

## Edge Cases

### Data Edge Cases

| Case           | Handling Strategy |
| -------------- | ----------------- |
| Empty data     | [How to handle]   |
| Very long text | [How to handle]   |
| Special chars  | [How to handle]   |
| Null/undefined | [How to handle]   |

### UI Edge Cases

| Case            | Handling Strategy |
| --------------- | ----------------- |
| Narrow viewport | [How to handle]   |
| Wide viewport   | [How to handle]   |
| High zoom       | [How to handle]   |
| Slow network    | [How to handle]   |

---

## Related Components

| Component | Relationship      |
| --------- | ----------------- |
| [name]    | [How they relate] |

---

## Migration Guide

### From Previous Version

[If this replaces an existing component]

**Breaking Changes:**

1. [Change 1]
2. [Change 2]

**Migration Steps:**

1. [Step 1]
2. [Step 2]

---

## Future Enhancements

### Planned Features

- [ ] [Feature 1]
- [ ] [Feature 2]
- [ ] [Feature 3]

### Potential Improvements

- [ ] [Improvement 1]
- [ ] [Improvement 2]

---

## References

### Design Inspiration

- [Link to design]
- [Link to similar component]

### Documentation

- [Link to Radix UI docs if using]
- [Link to related article]

### Research

- [Link to competitor analysis]
- [Link to user research]

---

**Specification Version:** 1.0.0
**Last Updated:** YYYY-MM-DD
**Status:** [Draft/Review/Approved/Implemented]
