---
name: css-review
description: Launch CSS/Design System review (tokens, consistency, browser compatibility). Use when the user asks to review CSS, styles, Tailwind, or design system usage.
---

Launch the css-review agent to perform a full CSS/Design System review.

Scope is determined by arguments:
- No arguments: review files changed in the current git diff.
- File path(s): review those specific files or components.
- Directory path: scan the entire directory for all frontend files and review them.

$ARGUMENTS
