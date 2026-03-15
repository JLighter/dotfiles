---
name: review-all
description: Launch ALL four review agents in parallel (code, DDD, UX, CSS). Use when the user wants a comprehensive full review of everything.
---

Launch ALL four review orchestrators in parallel on the current changes. This is a comprehensive review covering code quality, architecture, UX, and CSS.

## Process

### Step 1: Determine scope

If arguments are provided, use them as the scope (file paths or directory).
If no arguments, run `git diff --name-only HEAD` to find modified files.

### Step 2: Launch all 4 orchestrators in parallel

Launch ALL FOUR agents simultaneously in a single message:

1. **code-review** — "Review these files for Code Quality violations: [file list]"
2. **ddd-review** — "Review these files for DDD architecture violations: [file list]"
3. **ux-review** — "Review these frontend files for UX violations: [file list]"
4. **css-review** — "Review these files for CSS/design system violations: [file list]"

IMPORTANT: Launch all four in ONE message. Do NOT launch them sequentially.

### Step 3: Unified report

Once all four agents return, produce a single report:

---

## Full Review Report

**Date:** current date
**Files reviewed:** list

### Critical Issues

All critical findings, numbered, with agent tag: [CODE], [DDD], [UX], [CSS].

### Warnings

All warnings, same format.

### Summary

| Agent | Critical | Warnings |
|-------|----------|----------|
| Code Quality | count | count |
| DDD | count | count |
| UX | count | count |
| CSS | count | count |
| **Total** | **count** | **count** |

### Top 5 priorities

The five most impactful improvements across all domains.

---

$ARGUMENTS
