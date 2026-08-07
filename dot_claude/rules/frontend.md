---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/*.svelte"
---

# Frontend Component Rules

## Component Design
- Components are small, composable, single-responsibility.
- Separate layout components from content components.
- Loading, error, and empty states are first-class citizens.
- Every form: validation, loading state, error recovery, success feedback.
- Every list: empty state, loading skeleton, error state, overflow handling.

## Naming
- PascalCase for component names.
- camelCase for props, variables, functions.
- Component names describe what the user sees: `PaymentForm`, `OrderSummary`.
- Props describe behavior: `isDisabled`, `errorMessage`, `onConfirm`.

## Accessibility
- Semantic HTML first. Headings follow H1 > H2 > H3.
- All interactive elements keyboard navigable.
- `:focus-visible` on all interactive elements.
- Color must never be the only indicator.
- Font sizes in `rem`, never hardcoded `px`.

## Performance
- No inline function definitions in render (causes re-renders).
- Memoize expensive computations.
- Lazy load heavy components.
