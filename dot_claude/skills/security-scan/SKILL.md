---
name: security-scan
description: Deep security audit of the codebase. Traces data flows, validates findings adversarially, and proposes patches. Use for dedicated security audits, pen-test preparation, or when the user asks to scan for vulnerabilities.
---

Launch the code-security agent to perform a deep security audit.

This is a standalone security scan — it runs ONLY the security researcher agent (opus), not the full code-review suite. Use this for dedicated security work.

Scope is determined by arguments:
- No arguments: scan files changed in the current git diff.
- File path(s): scan those specific files, tracing data flows into and out of them.
- Directory path: full security audit of all source files in the directory.
- "full": scan the entire codebase from root.

When scanning a full codebase or directory, instruct the agent to prioritize:
1. Entry points (API routes, controllers, handlers) first.
2. Authentication and authorization logic second.
3. Data access layer (queries, ORM usage) third.
4. Then remaining application code.

$ARGUMENTS
