---
paths:
  - "**/*.css"
  - "**/*.scss"
  - "**/*.sass"
  - "**/tailwind.config.*"
---

# CSS / Style Rules

## Design Tokens
- Zero hardcoded color, spacing, font-size, shadow, or radius values.
- Every value must trace to a design token.
- Arbitrary Tailwind values `[32px]` signal a missing token — add it to config first.

## Tailwind
- Utility-first. Use classes directly in markup.
- `@apply` only when a combination is reused 3+ times across files.
- Class ordering: layout → sizing → spacing → typography → color → border → effects → state.
- Mobile-first responsive: base = mobile, `md:` `lg:` `xl:` build up.
- `extend` in config, never override base scale.

## Browser Compatibility
- Write fallback first, modern feature second.
- `dvh`/`svh`/`lvh` always paired with `vh` fallback.
- Check feature support before using `:has()`, `container queries`, `subgrid`.

## Performance
- Animate only `transform` and `opacity`.
- No `!important` in component styles.
- Keep selector specificity low (max 2 levels nesting).
