---
name: ddd-review
description: Launch DDD architecture review (strategic, tactical, layer isolation). Use when the user asks to review architecture, domain model, or bounded contexts.
---

Launch the ddd-review agent to perform a full DDD architecture review.

Scope is determined by arguments:
- No arguments: review files changed in the current git diff.
- File path(s): review those specific files or modules.
- Directory path: scan the entire directory for all source files and review the architecture.

$ARGUMENTS
