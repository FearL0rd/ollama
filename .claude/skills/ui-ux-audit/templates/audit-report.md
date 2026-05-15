# UI/UX Audit Report: [Feature/Page Name]

**Date:** YYYY-MM-DD
**Auditor:** [Agent name]
**Audit Type:** [Full/Accessibility/Responsiveness/Performance]
**Status:** [Draft/Review/Final]

---

## Executive Summary

### Overall Score: [#]/100

| Category       | Score   | Status      | Notes     |
| -------------- | ------- | ----------- | --------- |
| Accessibility  | [#]/100 | [Pass/Fail] | [Summary] |
| Responsiveness | [#]/100 | [Pass/Fail] | [Summary] |
| Performance    | [#]/100 | [Pass/Fail] | [Summary] |
| Usability      | [#]/100 | [Pass/Fail] | [Summary] |
| Design System  | [#]/100 | [Pass/Fail] | [Summary] |

### Critical Issues: [#]

### High Priority Issues: [#]

### Medium Priority Issues: [#]

### Low Priority Issues: [#]

---

## Scope

### Audited Components

- [Component 1]
- [Component 2]
- [Component 3]

### Audited Pages

- [Page 1] - [URL]
- [Page 2] - [URL]
- [Page 3] - [URL]

### Browsers Tested

- [ ] Chrome [version]
- [ ] Firefox [version]
- [ ] Safari [version]
- [ ] Edge [version]
- [ ] Mobile Safari (iOS [version])
- [ ] Chrome Mobile (Android [version])

### Devices Tested

- [ ] Desktop (1920x1080)
- [ ] Laptop (1280x800)
- [ ] Tablet (768x1024)
- [ ] Mobile (375x667)

---

## Accessibility Audit (WCAG 2.1)

### Level A Compliance

#### Perceivable

**1.1 Text Alternatives**

- [ ] **PASS** All images have alt text
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1 - location, description, severity]
2. [Issue 2 - location, description, severity]

**1.3 Adaptable**

- [ ] **PASS** Semantic HTML structure
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

**1.4 Distinguishable**

- [ ] **PASS** Color contrast (4.5:1 minimum)
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

**Contrast Analysis:**

| Element   | Foreground | Background | Ratio | Status      | Location |
| --------- | ---------- | ---------- | ----- | ----------- | -------- |
| [Element] | [#color]   | [#color]   | [#]:1 | [Pass/Fail] | [Where]  |

#### Operable

**2.1 Keyboard Accessible**

- [ ] **PASS** All interactive elements keyboard accessible
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

**Keyboard Navigation Test:**

| Element   | Tab | Enter | Space | Arrows | Status      |
| --------- | --- | ----- | ----- | ------ | ----------- |
| [Element] | [✓] | [✓]   | [✓]   | [✓]    | [Pass/Fail] |

**2.4 Navigable**

- [ ] **PASS** Skip links present
- [ ] **PASS** Focus visible
- [ ] **PASS** Logical focus order
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

**2.5 Input Modalities**

- [ ] **PASS** Touch targets minimum 44x44px
- [ ] **FAIL** [Issue description]

**Touch Target Analysis:**

| Element   | Width x Height | Status      | Location |
| --------- | -------------- | ----------- | -------- |
| [Element] | [#]x[#]px      | [Pass/Fail] | [Where]  |

#### Understandable

**3.1 Readable**

- [ ] **PASS** Language declared
- [ ] **PASS** Clear labels

**Issues Found:**

1. [Issue 1]

**3.2 Predictable**

- [ ] **PASS** Consistent navigation
- [ ] **PASS** No unexpected changes

**Issues Found:**

1. [Issue 1]

**3.3 Input Assistance**

- [ ] **PASS** Error identification
- [ ] **PASS** Labels or instructions
- [ ] **PASS** Error suggestions

**Issues Found:**

1. [Issue 1]

#### Robust

**4.1 Compatible**

- [ ] **PASS** Valid HTML
- [ ] **PASS** ARIA used correctly

**Issues Found:**

1. [Issue 1]

**ARIA Analysis:**

| Element   | ARIA Attributes | Status      | Notes      |
| --------- | --------------- | ----------- | ---------- |
| [Element] | [role, aria-*]  | [Pass/Fail] | [Comments] |

### Level AA Compliance

- [ ] **PASS** Enhanced contrast (7:1 for graphics)
- [ ] **PASS** Text resize up to 200%
- [ ] **PASS** Reflow at 320px

**Issues Found:**

1. [Issue 1]

### Screen Reader Testing

**Tested with:** [NVDA/JAWS/VoiceOver]

| Page/Component | Announces Correctly | Navigation Works | Status      |
| -------------- | ------------------- | ---------------- | ----------- |
| [Name]         | [Yes/No]            | [Yes/No]         | [Pass/Fail] |

**Issues Found:**

1. [Issue 1 - what's announced wrong, where]

---

## Responsiveness Audit

### Mobile (375px)

**Score:** [#]/100

#### Layout

- [ ] **PASS** Single column layout
- [ ] **PASS** No horizontal scroll
- [ ] **PASS** Content readable without zoom
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1 - screenshot, description]

#### Touch Interactions

- [ ] **PASS** Touch targets 44x44px minimum
- [ ] **PASS** Swipe gestures work
- [ ] **PASS** Tap targets spaced appropriately

**Issues Found:**

1. [Issue 1]

#### Navigation

- [ ] **PASS** Mobile menu works
- [ ] **PASS** Bottom nav (if applicable)
- [ ] **PASS** Breadcrumbs hidden/collapsed

**Issues Found:**

1. [Issue 1]

### Tablet (768px)

**Score:** [#]/100

- [ ] **PASS** Appropriate layout
- [ ] **PASS** No horizontal scroll
- [ ] **PASS** Touch/mouse hybrid works

**Issues Found:**

1. [Issue 1]

### Desktop (1280px)

**Score:** [#]/100

- [ ] **PASS** Full features visible
- [ ] **PASS** Sidebars displayed
- [ ] **PASS** Hover states work
- [ ] **PASS** Multi-column layouts

**Issues Found:**

1. [Issue 1]

### FullHD (1920px)

**Score:** [#]/100

- [ ] **PASS** No horizontal overflow
- [ ] **PASS** Content centered/constrained
- [ ] **PASS** No excessive whitespace

**Issues Found:**

1. [Issue 1]

### Breakpoint Analysis

| Breakpoint | Min Width | Max Width | Issues Found | Status      |
| ---------- | --------- | --------- | ------------ | ----------- |
| xs         | 0         | 639px     | [#]          | [Pass/Fail] |
| sm         | 640px     | 767px     | [#]          | [Pass/Fail] |
| md         | 768px     | 1023px    | [#]          | [Pass/Fail] |
| lg         | 1024px    | 1279px    | [#]          | [Pass/Fail] |
| xl         | 1280px    | 1919px    | [#]          | [Pass/Fail] |
| 2xl        | 1920px+   | -         | [#]          | [Pass/Fail] |

---

## Performance Audit

### Core Web Vitals

| Metric | Mobile | Desktop | Target  | Status      |
| ------ | ------ | ------- | ------- | ----------- |
| LCP    | [#]s   | [#]s    | < 2.5s  | [Pass/Fail] |
| FID    | [#]ms  | [#]ms   | < 100ms | [Pass/Fail] |
| CLS    | [#]    | [#]     | < 0.1   | [Pass/Fail] |

### Load Performance

| Metric                 | Value | Target  | Status      |
| ---------------------- | ----- | ------- | ----------- |
| Time to Interactive    | [#]s  | < 3.8s  | [Pass/Fail] |
| First Contentful Paint | [#]s  | < 1.8s  | [Pass/Fail] |
| Speed Index            | [#]s  | < 3.4s  | [Pass/Fail] |
| Total Bundle Size      | [#]KB | < 500KB | [Pass/Fail] |

### Performance Issues

1. **[Issue 1]**
    - Impact: [High/Medium/Low]
    - Description: [What's slow]
    - Recommendation: [How to fix]

2. **[Issue 2]**
    - Impact: [High/Medium/Low]
    - Description: [What's slow]
    - Recommendation: [How to fix]

### Animation Performance

- [ ] **PASS** 60fps maintained
- [ ] **PASS** Respects prefers-reduced-motion
- [ ] **PASS** GPU acceleration used

**Issues Found:**

1. [Issue 1]

---

## Usability Audit

### Navigation

**Score:** [#]/100

- [ ] **PASS** Clear hierarchy
- [ ] **PASS** Consistent placement
- [ ] **PASS** Active state visible
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

### Forms

**Score:** [#]/100

- [ ] **PASS** Clear labels
- [ ] **PASS** Inline validation
- [ ] **PASS** Error messages helpful
- [ ] **PASS** Required fields marked
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

### Feedback & States

**Score:** [#]/100

- [ ] **PASS** Loading states clear
- [ ] **PASS** Success feedback visible
- [ ] **PASS** Error handling graceful
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

### Content

**Score:** [#]/100

- [ ] **PASS** Clear hierarchy
- [ ] **PASS** Scannable
- [ ] **PASS** Appropriate tone
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

---

## Design System Compliance

### Colors

**Score:** [#]/100

- [ ] **PASS** Uses design system colors
- [ ] **PASS** Consistent color usage
- [ ] **FAIL** [Issue description]

**Inconsistencies Found:**

1. [Color used] instead of [design system token]

### Typography

**Score:** [#]/100

- [ ] **PASS** Uses system fonts
- [ ] **PASS** Consistent sizing
- [ ] **PASS** Proper hierarchy
- [ ] **FAIL** [Issue description]

**Inconsistencies Found:**

1. [Issue 1]

### Spacing

**Score:** [#]/100

- [ ] **PASS** Uses 4px scale
- [ ] **PASS** Consistent spacing
- [ ] **FAIL** [Issue description]

**Inconsistencies Found:**

1. [Issue 1]

### Components

**Score:** [#]/100

- [ ] **PASS** Uses shadcn/ui components
- [ ] **PASS** No component duplication
- [ ] **FAIL** [Issue description]

**Issues Found:**

1. [Issue 1]

---

## Issues Summary

### Critical Issues (Block Launch)

1. **[Issue Title]**
    - **Category:** [Accessibility/Responsiveness/Performance]
    - **Location:** [Where]
    - **Description:** [What's wrong]
    - **Impact:** [User impact]
    - **Fix Required:** [What needs to be done]
    - **Effort:** [Hours/Days]

### High Priority (Fix Before Launch)

1. **[Issue Title]**
    - **Category:** [Category]
    - **Location:** [Where]
    - **Description:** [What's wrong]
    - **Impact:** [User impact]
    - **Fix Required:** [What needs to be done]
    - **Effort:** [Hours/Days]

### Medium Priority (Fix Soon)

1. **[Issue Title]**
    - **Category:** [Category]
    - **Location:** [Where]
    - **Description:** [What's wrong]
    - **Impact:** [User impact]
    - **Fix Required:** [What needs to be done]
    - **Effort:** [Hours/Days]

### Low Priority (Nice to Have)

1. **[Issue Title]**
    - **Category:** [Category]
    - **Location:** [Where]
    - **Description:** [What's wrong]
    - **Impact:** [User impact]
    - **Fix Required:** [What needs to be done]
    - **Effort:** [Hours/Days]

---

## Recommendations

### Quick Wins (< 1 day)

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

### Short Term (1-3 days)

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

### Long Term (> 3 days)

1. [Recommendation 1]
2. [Recommendation 2]
3. [Recommendation 3]

---

## Action Items

### For Developers

- [ ] [Action 1]
- [ ] [Action 2]
- [ ] [Action 3]

### For Designers

- [ ] [Action 1]
- [ ] [Action 2]
- [ ] [Action 3]

### For Product

- [ ] [Action 1]
- [ ] [Action 2]
- [ ] [Action 3]

---

## Re-Audit Criteria

### Definition of Done

- [ ] All critical issues resolved
- [ ] All high priority issues resolved
- [ ] Accessibility score > 90
- [ ] Responsiveness score > 95
- [ ] Performance score > 80
- [ ] Re-tested on all browsers
- [ ] Re-tested on all devices

### Re-Audit Date

**Scheduled:** YYYY-MM-DD

---

## Appendix

### Screenshots

[Links to screenshot folder]

### Test Data

[Test data used during audit]

### Tools Used

- [ ] Chrome DevTools
- [ ] Lighthouse
- [ ] WAVE
- [ ] axe DevTools
- [ ] Screen reader ([which])
- [ ] Responsive design mode
- [ ] Performance profiler

### References

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Web.dev Vitals](https://web.dev/vitals/)
- [Design system documentation]

---

**Audit Version:** 1.0.0
**Auditor:** [Name]
**Date:** YYYY-MM-DD
**Status:** [Draft/Final]
