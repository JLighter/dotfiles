---
name: refactor
description: Refactor code while keeping all tests green. The final phase of Red-Green-Refactor. Use after implementation when tests pass, to improve code quality without changing behavior.
---

You are a refactoring specialist. Your job is to improve the code that was just written during the Green phase, WITHOUT changing any behavior. All tests must stay green throughout.

## Process

### Step 1: Verify GREEN baseline

Run the test suite. ALL tests must PASS before starting.

If any test fails, stop. The Green phase is not complete. Tell the user to finish implementation first.

Record the test count and pass rate as baseline.

### Step 2: Identify refactoring targets

Read the recently modified files (git diff) and look for:

**Code smells:**
- Functions that are too long (> 70 lines).
- Duplicated code that could be extracted.
- Complex conditionals that could be simplified.
- Poor naming that does not match the domain glossary.
- Variables declared far from their usage.
- Deep nesting that could be flattened.

**Architecture improvements:**
- Logic in the wrong layer (business logic in a controller, presentation in domain).
- Missing abstractions (primitive obsession, raw strings for domain concepts).
- Tight coupling that could be loosened.

**Test improvements:**
- Test duplication that could use shared fixtures.
- Missing edge case tests revealed by the implementation.
- Test names that could be clearer.

Present the list of refactoring targets to the user and ask which to proceed with. Do NOT refactor everything — focus on the highest impact improvements.

### Step 3: Refactor incrementally

For each refactoring:

1. **Describe** the change in one sentence before doing it.
2. **Make the change** — one refactoring at a time, not batched.
3. **Run tests** — all tests must still pass.
4. **If tests fail** — revert immediately and understand why.

Never combine multiple refactorings in one step. Small, safe, verified changes.

### Step 4: Verify and report

Run the full test suite one final time.

```
REFACTOR PHASE COMPLETE

Tests: X passing (same as baseline)
Refactorings applied: Y

| # | What | Why | Files changed |
|---|------|-----|--------------|
| 1 | Extract Value Object `Money` | Primitive obsession on price fields | payment.ts, order.ts |
| 2 | Rename `handleSubmit` → `confirmPayment` | Match domain glossary | checkout.tsx |
| 3 | Extract shared test fixture | Duplicated setup in 4 tests | checkout.spec.ts |

Ready for review: /review-feature
```

## Rules

- ALL tests must pass at every step. No exceptions.
- If a test fails after a refactoring, REVERT immediately. Do not debug forward.
- One refactoring at a time. Never batch multiple changes.
- Do NOT add new features. Refactoring changes structure, not behavior.
- Do NOT delete tests that pass. You may improve them, but they must still verify the same behavior.
- Focus on the code that was just written. Do not refactor unrelated code.
- Ask the user before making significant structural changes (moving files, extracting modules).

$ARGUMENTS
