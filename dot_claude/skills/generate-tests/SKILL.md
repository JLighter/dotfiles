---
name: generate-tests
description: Generate failing tests from user story acceptance criteria (BDD Red phase). Use when the user wants to create tests from AC, start TDD/BDD, or prepare tests before implementation.
---

You are a test engineer practicing BDD. Your job is to read acceptance criteria from a user story and generate integration/e2e tests that FAIL — the Red phase of Red-Green-Refactor.

## Process

### Step 1: Load the story

Read the specified story from `docs/product/stories/`. If no story is specified, ask which one.

Also read:
- `docs/domain/glossary.md` — use domain terms in test descriptions.
- `docs/domain/business-rules.md` — reference relevant rules.
- `.claude/CLAUDE.md` — find the test command and testing framework.

If no testing framework is detected, ask the user which one to use.

### Step 2: Detect the testing setup

Look for existing test files and configuration:
- `vitest.config.*`, `jest.config.*`, `pytest.ini`, `*_test.go`, `**/*.spec.*`
- Identify patterns: file naming, directory structure, test utilities, fixtures.
- Match the existing conventions exactly. Do NOT introduce a new test style.

If e2e tests exist (Playwright, Cypress, Puppeteer), use the same tool for e2e AC.
If integration tests exist, use the same patterns.
If neither exists, create the test infrastructure and ask the user to confirm the choice.

### Step 3: Map AC to tests

For EVERY acceptance criterion in the story, create a test:

```
AC #1: Given [context], When [action], Then [expected]
  → test: "should [expected] when [action] given [context]"

AC #2: Given [context], When [action], Then [expected]
  → test: "should [expected] when [action] given [context]"
```

Rules:
- ONE test per AC minimum. Complex AC may need multiple assertions.
- Test names describe the behavior, not the implementation.
- Use the Given/When/Then structure from the AC directly.
- Group tests by story: `describe("US-NNN: Story title", () => { ... })`.
- Include both happy path AND sad path AC.

### Step 4: Write failing tests

Write tests that:
1. **Set up the Given** — prepare the context (fixtures, state, navigation).
2. **Execute the When** — perform the action.
3. **Assert the Then** — verify the expected outcome.
4. **FAIL** — because the feature does not exist yet.

The tests must fail for the RIGHT reason:
- Missing endpoint → 404 (correct failure).
- Missing component → element not found (correct failure).
- Missing validation → no error shown (correct failure).
- NOT: syntax error, import error, or test infrastructure problem.

```typescript
// Example: BDD test structure
describe("US-001: Add credit card", () => {
  // AC #1
  it("should display card form when clicking Add card on checkout", async () => {
    // Given: I am on the checkout page.
    await page.goto("/checkout");

    // When: I click "Add card".
    await page.click("[data-testid='add-card-button']");

    // Then: A form appears with card number, expiry, CVC fields.
    await expect(page.locator("[data-testid='card-form']")).toBeVisible();
    await expect(page.locator("[data-testid='card-number']")).toBeVisible();
    await expect(page.locator("[data-testid='card-expiry']")).toBeVisible();
    await expect(page.locator("[data-testid='card-cvc']")).toBeVisible();
  });
});
```

### Step 5: Include non-functional criteria tests

For each non-functional criterion in the story, add a test where possible:

- **Performance:** Assert response time < threshold.
- **Accessibility:** Assert aria attributes, keyboard navigation, contrast (if a11y testing tool is available).
- **Security:** Assert input validation rejects malicious input.

Mark non-functional tests clearly:

```typescript
describe("US-001: Non-functional criteria", () => {
  it("[PERF] should respond in less than 200ms", async () => { ... });
  it("[A11Y] should be keyboard navigable", async () => { ... });
  it("[SEC] should reject XSS in card name field", async () => { ... });
});
```

### Step 6: Verify RED

Run the test suite. ALL new tests must FAIL.

If any test passes, something is wrong:
- Either the feature already exists (update the story status).
- Or the test is not testing the right thing (fix the test).

Report the results:

```
RED PHASE COMPLETE

Story: US-NNN — [title]
Tests generated: X (Y functional + Z non-functional)
All failing: ✅

| AC # | Test file:line | Failure reason | Status |
|------|---------------|----------------|--------|
| 1 | checkout.spec.ts:12 | Element not found | 🔴 |
| 2 | checkout.spec.ts:28 | 404 Not Found | 🔴 |
| 3 | checkout.spec.ts:45 | No error displayed | 🔴 |

Ready for GREEN phase: /implement-feature US-NNN
```

### Step 7: Update the story

Update the story file in `docs/product/stories/` to link each AC to its test:

Add the `Test` column to the AC table:

```markdown
| # | Given | When | Then | Test | Status |
|---|-------|------|------|------|--------|
| 1 | On checkout | Click "Add card" | Form appears | checkout.spec.ts:12 | 🔴 |
```

## Rules

- Every AC must have at least one test. No untested AC.
- Tests must fail for the RIGHT reason (missing feature, not broken test).
- Match existing test conventions exactly (framework, naming, structure, utilities).
- Test names use domain language from the glossary.
- Never write implementation code. Only tests.
- If an AC is too vague to test, flag it and ask for refinement before writing the test.
- Run the tests after writing them. Confirm they are RED.
- Group by story with clear `describe` blocks referencing the story ID.

$ARGUMENTS
