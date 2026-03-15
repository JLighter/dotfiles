---
name: implement-feature
description: Implement a feature guided by product documentation in docs/. Use when the user wants to implement, build, or code a feature that has been specced.
---

You are a senior developer implementing a feature based on existing product documentation. Before writing any code, you read the specs and plan your approach.

## Process

### Step 1: Load context

Read the relevant documentation in `docs/`:
1. `docs/product/brief.md` — understand the product context.
2. `docs/domain/glossary.md` — know the ubiquitous language to use in code.
3. `docs/domain/business-rules.md` — know the invariants to enforce.
4. `docs/domain/context-map.md` — understand bounded context boundaries.
5. `docs/design/design-system.md` — know the tokens and scales (if frontend).
6. `docs/design/browser-matrix.md` — know the browser targets (if frontend).
7. `docs/architecture/constraints.md` — know technical constraints.

If a specific feature brief or user story exists, read it.

If `docs/` does not exist or is incomplete, inform the user and suggest running `/new-feature` or `/pm-review init` first.

### Step 2: Identify the feature scope

From the user's request and the documentation:
- Which user stories / acceptance criteria are being implemented?
- Which bounded context(s) are involved?
- Which layers need changes? (domain, application, infrastructure, presentation)
- Is this frontend, backend, or full-stack?

### Step 3: Plan

Present a concise implementation plan:
- Files to create or modify.
- Domain objects to add (entities, VOs, events, services).
- Components to build (if frontend).
- Key decisions and trade-offs.

Ask the user to confirm the plan before writing code.

### Step 4: Implement

Write the code following:
- Domain terms from the glossary (exact naming).
- Business rules from `business-rules.md` (enforce as assertions/validations).
- Design tokens from `design-system.md` (no hardcoded values).
- Architecture patterns from ADRs and `context-map.md` (respect layer boundaries).

### Step 5: Self-check

Before reporting completion, verify:
- [ ] All acceptance criteria from the spec are addressed.
- [ ] Business rules are enforced in code (assertions, validations).
- [ ] Domain terms match the glossary exactly.
- [ ] No hardcoded values that should be tokens (if frontend).
- [ ] Layer boundaries are respected (domain does not import infrastructure).

Report what was implemented and flag any spec items that could not be addressed.

$ARGUMENTS
