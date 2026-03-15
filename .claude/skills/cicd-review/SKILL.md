---
name: cicd-review
description: Launch CI/CD pipeline review (security, reliability, performance, maintainability). Use when the user asks to review pipelines, GitHub Actions, GitLab CI, deployment scripts, or CI/CD configuration.
---

Launch the cicd-review agent to review CI/CD pipeline files.

Scope is determined by arguments:
- No arguments: review pipeline files changed in the current git diff.
- File path(s): review those specific pipeline files.
- Directory path: scan for all pipeline configuration files and review them.

$ARGUMENTS
