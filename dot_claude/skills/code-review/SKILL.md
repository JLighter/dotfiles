---
name: code-review
description: Launch code quality review (safety, performance, developer experience). Use when the user asks to review code quality, check code, or after writing backend/logic code.
---

Launch the code-review agent to perform a full code quality review on the current changes.

Pass the following context to the agent: review files changed in the current git diff. If no diff is available, review files mentioned by the user or ask what to review.

$ARGUMENTS
