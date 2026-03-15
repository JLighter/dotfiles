---
name: ux-review
description: Launch UX review (visual hierarchy, interaction, user flow). Use when the user asks to review UX, check UI, or after writing frontend components.
---

Launch the ux-review agent to perform a full UX review on the current changes.

Pass the following context to the agent: review frontend files changed in the current git diff. If no diff is available, review files mentioned by the user or ask what to review.

$ARGUMENTS
