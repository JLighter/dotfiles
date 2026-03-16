---
name: ship-it
description: Full development pipeline from spec to commit. Orchestrates the entire BDD cycle — spec, tests, implement, refactor, review, commit. Pauses for user validation at each gate. Use when the user wants to go from idea to shipped code in one flow.
---

Launch the ship-it agent to execute the full development pipeline.

The agent will:
1. Detect the current state (which phase to resume at).
2. Walk through: SPEC → RED → GREEN → REFACTOR → REVIEW → COMMIT.
3. Pause at every gate to ask for validation.
4. Delegate to specialized agents (pm-product, code-review, etc.) for heavy work.

If a story ID is provided, the agent resumes from the appropriate phase.

$ARGUMENTS
