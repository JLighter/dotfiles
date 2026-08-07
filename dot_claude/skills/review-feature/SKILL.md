---
name: review-feature
description: Smart review that detects file types and launches the right review agents. Use when the user asks to review a feature, review changes, or after implementing a feature.
---

You are a review coordinator. Your job is to detect what changed and launch the right review agents in parallel.

## Process

### Step 1: Detect scope and file types

Run `git diff --name-only HEAD` to find modified files. If no diff, use the files or scope provided by the user.

Classify files into categories:
- **Domain/backend code:** .ts, .js, .py, .go, .rs, .java, .kt (in domain/, application/, infrastructure/, services/, etc.)
- **Frontend components:** .tsx, .jsx, .vue, .svelte (in components/, pages/, views/, etc.)
- **Style files:** .css, .scss, tailwind.config.*, theme files, token files
- **IaC files:** .tf, .hcl, .tfvars, Dockerfile*, docker-compose.*, Helm charts, Pulumi
- **Pipeline files:** .github/workflows/*.yml, .gitlab-ci.yml, Jenkinsfile, bitbucket-pipelines.yml
- **Documentation:** docs/**

List the files and their categories.

### Step 2: Select review agents

Based on file categories, determine which reviews to run:

| Files detected | Agents to launch |
|---------------|-----------------|
| Domain/backend code | code-review + ddd-review |
| Frontend components | code-review + ux-review |
| Style files | css-review |
| Frontend + styles | code-review + ux-review + css-review |
| Full-stack | code-review + ddd-review + ux-review + css-review |
| IaC files | infra-review |
| Pipeline files | cicd-review |
| IaC + pipelines | infra-review + cicd-review |
| Documentation | pm-review (audit mode) |

**code-review** runs on ALL code changes (backend and frontend).

Announce which agents will be launched and why.

### Step 3: Launch reviews in parallel

Launch all selected review agents simultaneously in a single message, each with the relevant file list.

IMPORTANT: Launch all selected agents in ONE message with multiple Agent tool calls. Do NOT launch them sequentially.

### Step 4: Unified report

Once all agents return, produce a single unified report:

---

## Feature Review Report

**Date:** current date
**Files reviewed:** list
**Agents used:** list

### Critical Issues

All critical findings from all agents, numbered, with:
- Source agent tag: [CODE], [DDD], [UX], [CSS], [PM]
- File and line number
- Issue description
- Fix suggestion

### Warnings

All warnings, same format.

### Summary

| Agent | Critical | Warnings |
|-------|----------|----------|
| Per agent | count | count |
| **Total** | **count** | **count** |

### Top 5 priorities

The five most impactful things to fix, across all agents, prioritized by user and system impact.

---

## Rules

- Always run code-review on code changes. It is never skipped.
- Launch all agents in parallel, never sequentially.
- Deduplicate across agents if the same issue is flagged by multiple reviewers.
- If no files changed, ask the user what to review.

$ARGUMENTS
