---
name: infra-review
description: Launch infrastructure review (security, FinOps, reliability). Use when the user asks to review Terraform, IaC, infrastructure code, or cloud resources.
---

Launch the infra-review agent to perform a full infrastructure review.

Scope is determined by arguments:
- No arguments: review files changed in the current git diff.
- File path(s): review those specific IaC files.
- Directory path: scan the entire directory for all IaC files and review them.

$ARGUMENTS
