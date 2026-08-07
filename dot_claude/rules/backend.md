---
paths:
  - "**/*.go"
  - "**/*.rs"
  - "**/*.py"
  - "**/*.java"
  - "**/*.scala"
  - "**/*.kt"
  - "**/*.cs"
  - "**/*.rb"
  - "**/*.ex"
  - "**/*.exs"
  - "**/*.c"
---

# Backend Code Rules

## Hard Limits
- 70 lines max per function. No exceptions.
- 100 columns max per line. No exceptions.
- 2 assertions minimum per function.
- All loops must have a fixed upper bound.

## Control Flow
- Simple explicit control flow only. No recursion.
- Split compound boolean conditions into nested if/else.
- Every if should have a matching else (handled or asserted).
- State invariants positively: `if (index < length)` not `if (index >= length)`.
- Centralize control flow in parent functions, pure logic in helpers.

## Naming
- No abbreviations (except i/j/k in math loops).
- Units/qualifiers last, descending significance: `latency_ms_max`.
- Equal-length related names for alignment: `source`/`target`.

## Comments
- Always explain WHY, not just what.
- Comments are sentences (capital letter, full stop).
- Explain test methodology at top of test files.
