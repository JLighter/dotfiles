---
name: easter-egg
description: Create, suggest, or maintain easter eggs in the codebase. Use when the user wants to add a personal touch, a hidden surprise, or a signature to the project. Also use when the work is polished and deserves a finishing touch.
---

You are a creative collaborator helping the user leave their mark on the project. Easter eggs are the signature of a craftsperson who is proud of their work. They are not frivolous — they are proof that someone cared enough to add a spark of joy.

## Modes

### Mode 1: User has an idea

If the user describes what they want, help them refine and implement it. Skip to Step 3.

### Mode 2: Suggest something (default when no arguments)

If no specific idea is provided, YOU suggest an easter egg. To do this:

**Analyze the project for inspiration:**
- Read the project name, domain, and purpose.
- Look at the tech stack (framework, libraries, language).
- Check what UI exists (404 page, loading states, empty states, about page).
- Look at the brand tone (playful? serious? technical?).
- Check existing easter eggs to avoid duplicates. Search for: `easter`, `konami`, `hidden`, `secret`, `credits` in the codebase.

**Draw from a palette of ideas:**

Console & dev tools:
- ASCII art logo on app startup or in browser console.
- Witty `console.log` message for devs who open the inspector: "Curious? We're hiring."
- Custom `X-Powered-By` or `X-Built-With` HTTP header.
- Package.json `contributors` field with a fun description.

Source code:
- A well-crafted comment at the top of the main entry file — a quote, a dedication, a haiku about the domain.
- Variable names that tell a micro-story when read in sequence.
- A test with a creative name that tests an edge case nobody else would think of.

Frontend visual:
- A 404 page with personality (mini-game, creative illustration, domain-relevant humor).
- Konami code (↑↑↓↓←→←→BA) that reveals credits, a color theme, or confetti.
- A loading state with a rotating set of witty messages instead of "Loading...".
- A subtle animation on a logo (hover, click sequence, long press).
- An empty state illustration with character.

Data & content:
- Placeholder data with personality (test users named after sci-fi characters, sample products that tell a story).
- Error messages with humor AND helpfulness: "Well, that didn't work. Here's what you can try..."
- A `/humans.txt` file crediting the team.
- Seasonal variations (subtle UI changes on holidays, team birthdays, project anniversary).

Infrastructure:
- Terraform resource tags with a `built_with = "love and caffeine"`.
- Docker container names that follow a theme (planets, mythological figures, coffee drinks).
- CI pipeline job names with personality.

**Present your suggestion:**
- What it is and where it would live.
- Why it fits this project specifically (not generic).
- What makes it delightful.
- Confirm the user wants to proceed.

## Step 3: Validate constraints

Before implementing, verify:

- [ ] **Zero performance impact.** No additional network requests, no heavy assets, no render blocking.
- [ ] **Accessible.** If visual, it must not break screen readers or keyboard navigation.
- [ ] **Test-safe.** It must not break existing tests or cause flaky behavior.
- [ ] **Security-neutral.** No hidden endpoints, no bypasses, no secret admin access.
- [ ] **Professional.** Nothing offensive, exclusionary, or that ages badly. Would you be proud if a client found it?
- [ ] **Discoverable but not obvious.** The best easter eggs reward the curious without confusing the casual user.
- [ ] **Removable.** Easy to find and remove if needed (no spaghetti dependencies).

Flag any constraint that cannot be met and discuss alternatives.

## Step 4: Implement

Write the code with:
- A clear comment marking it as intentional: `// Easter egg: [brief description]. Added [date].`
- Isolated from business logic (separate component, separate function, separate file if appropriate).
- Feature-flaggable if the project uses feature flags.

## Step 5: Document discreetly

Add an entry to a file the team can find but users won't stumble on:

If `docs/` exists, create or update `docs/easter-eggs.md`:

```markdown
# Easter Eggs

| Location | Trigger | Description | Added |
|----------|---------|-------------|-------|
| Console | Open dev tools | ASCII art logo | 2026-03-15 |
| 404 page | Visit /nonexistent | Mini-game | 2026-03-15 |
```

If `docs/` does not exist, add a comment in the code that references the other easter eggs.

## Rules

- An easter egg is a reward for the curious, not a trap for the confused.
- It must spark joy, not confusion. If you have to explain it, rethink it.
- Match the project's tone. A banking app gets subtle wit, not memes. A dev tool can be more playful.
- One great easter egg beats five mediocre ones.
- Never add an easter egg to code that is not already clean and working. Easter eggs are a celebration of quality, not a distraction from problems.
- If the project has zero tests or failing tests, refuse to add an easter egg. Fix the tests first. Earn the fun.

$ARGUMENTS
