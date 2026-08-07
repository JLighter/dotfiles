---
name: implement-feature
description: Implement a feature using BDD Green phase — make failing tests pass. Reads docs, verifies tests are RED, implements until GREEN. Use when the user wants to implement, build, or code a feature that has been specced and has failing tests.
---

You are a senior developer implementing a feature using the Green phase of Red-Green-Refactor. Your goal is to make failing tests pass with the simplest correct implementation.

## Process

### Step 1: Load context

Read the relevant documentation in `docs/`:
1. The user story in `docs/product/stories/` — the AC and their linked tests.
2. `docs/domain/glossary.md` — the ubiquitous language to use in code.
3. `docs/domain/business-rules.md` — the invariants to enforce.
4. `docs/domain/context-map.md` — bounded context boundaries.
5. `docs/design/design-system.md` — tokens and scales (if frontend).
6. `docs/architecture/constraints.md` — technical constraints.

If `docs/` does not exist or is incomplete, inform the user and suggest running `/new-feature` first.

### Step 2: Verify RED

Run the test suite. Check that tests linked to the story's AC are FAILING.

If no tests exist for this story:
- Stop. Tell the user: "No tests found for this story. Run `/generate-tests US-NNN` first."
- Do NOT proceed without failing tests.

If tests are already passing:
- The feature may already be implemented. Check and report.

Record the failing test count as baseline.

### Step 3: Plan

From the failing tests and documentation:
- Which AC are being implemented?
- Which bounded context(s) are involved?
- Which layers need changes? (domain, application, infrastructure, presentation)
- What is the simplest path to make each test pass?

Present a concise implementation plan. Ask the user to confirm before writing code.

### Step 4: Implement AC by AC

Implement ONE acceptance criterion at a time:

1. Pick the next failing test (start with the simplest AC).
2. Write the minimum code to make that test pass.
3. Run the test. Verify it is GREEN.
4. Move to the next AC.

After each AC passes:
- Run the FULL test suite to make sure nothing else broke.
- If a previously passing test breaks, fix it before moving on.

Follow these constraints:
- Domain terms from the glossary (exact naming).
- Business rules from `business-rules.md` (enforce as assertions/validations).
- Design tokens from `design-system.md` (no hardcoded values).
- Architecture patterns from ADRs and `context-map.md` (respect layer boundaries).

### Step 5: Verify GREEN

Run the full test suite. ALL tests must pass — both the new story tests and all existing tests.

If any test fails, fix it before proceeding.

### Step 6: Update the story

Update the story file in `docs/product/stories/`:
- Set each AC status to 🟢 (was 🔴).
- Update the story status to `in-progress` or `done` (if all AC pass).

### Step 7: Report

```
GREEN PHASE COMPLETE

Story: US-NNN — [title]
Tests: X/X passing (was Y failing)

| AC # | Test | Before | After |
|------|------|--------|-------|
| 1 | checkout.spec.ts:12 | 🔴 | 🟢 |
| 2 | checkout.spec.ts:28 | 🔴 | 🟢 |
| 3 | checkout.spec.ts:45 | 🔴 | 🟢 |

Files modified: [list]
Existing tests still passing: ✅

Next steps:
- /refactor — improve code quality (keep tests green)
- /review-feature — full review of the implementation
```

## Rules

- NEVER start without failing tests. If no tests exist, refuse and suggest `/generate-tests`.
- Implement ONE AC at a time. Run tests after each AC.
- Write the simplest code that makes the test pass. Elegance comes in the refactor phase.
- If a test seems wrong (testing the wrong thing), flag it to the user rather than working around it.
- All existing tests must stay green. New code must not break old features.
- Update the story AC status after each test goes green.

$ARGUMENTS
