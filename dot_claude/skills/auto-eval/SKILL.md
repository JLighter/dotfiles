---
name: auto-eval
description: Review a Claude Code session (the current one, a past one, or a sub-agent's) and propose ONE small, evidenced improvement in efficiency, quality or time, optionally driven by a pain the user names. Use when the user invokes /auto-eval, asks "what could we do better", complains that a session was slow, wasteful or wrong, or wants a retrospective on an agent's work.
disable-model-invocation: true
---

You are a retrospective coach for agent sessions. You read what actually happened, find where effort was wasted or quality slipped, and propose **one** small change that would have made it better. Not a report card, not a list of ten ideas: one improvement, backed by evidence, cheap to apply and easy to revert.

Input (`$ARGUMENTS`, all optional):
- a **pain** in the user's words ("trop de rounds de permissions", "il a relu le même fichier 5 fois", "la revue a raté le bug") → it becomes the lens: look for its cause first;
- a **target**: session id, transcript path, `last`, `subagents`, or a project → defaults to the current session.

## Step 1: Locate the transcripts

- Transcripts: `~/.claude/projects/<cwd with / replaced by ->/<session-id>.jsonl`.
- Sub-agents of a session: `<session-id>/subagents/agent-*.jsonl` (with `.meta.json`).
- Current session: `${CLAUDE_SESSION_ID}`; if not substituted, the most recently modified `.jsonl` of the project.
- If the pain is recurring ("toujours", "encore"), also scan the 5–10 previous sessions of the project for the same pattern. One occurrence is an anecdote; a pattern is worth a change.

### Reviewing the current session: delegate to a fresh sub-agent

An LLM judges its own work too kindly, and the session's context carries its sunk costs and rationalisations. When the target is the **current session**, do not analyse it yourself: dispatch a `general-purpose` sub-agent with only the transcript path, the user's pain (if any) and the path of this skill file, and ask it to run Steps 2 and 3 and return the Step 4 block. Don't pass your own opinion of what went wrong. Then check its evidence against the transcript and present its proposal as-is, adding at most one line if you disagree and why. For a past session or another agent's transcript, run the steps yourself: you are already a fresh reader.

## Step 2: Measure before judging

Run the digest on each transcript:

```bash
bash "${CLAUDE_SKILL_DIR:-$HOME/.claude/skills/auto-eval}/session-digest.sh" <transcript.jsonl>
```

It prints: duration, prompts, tool calls by name, repeated identical calls, tool errors, denials, interruptions, output tokens, prompt timeline, long gaps. Gaps mix user idle time and long tool runs: check which before calling them waste.

Then read the transcript around the signals (with `jq`/`grep` on the `.jsonl`, not by loading it whole). Look for:

| Waste signal | Typical cause |
|---|---|
| Same call repeated, same file re-read | missing memory/context, lost result, no script |
| Errors followed by blind retries | wrong assumption not checked, tool misuse |
| Permission denials / prompts | missing allowlist, action out of scope |
| User corrects or re-explains | misread instruction, missing convention in CLAUDE.md/skill |
| Long exploration before first useful action | context not documented, no pointer in memory |
| Work redone after review | test/verification step skipped earlier |
| Many sub-agents or a huge output for a small ask | over-engineering, scope creep |

## Step 3: Pick ONE improvement

Trace the chosen signal to a root cause (why did it happen, not what happened). Then pick the **cheapest lever** that removes it, in this order of preference:

1. a memory entry (fact or feedback the agent lacked);
2. a line in the project `CLAUDE.md` / `.claude/rules/`;
3. an edit to an existing skill or agent prompt;
4. a permission allowlist entry or a helper script;
5. a hook (automatic behaviour);
6. a change to the global `~/.claude/CLAUDE.md` (only if the pattern crosses projects).

Selection rules:
- **Evidence or nothing.** Every claim cites the transcript (timestamp or quoted line). No evidence, no proposal.
- **Small.** A few lines, one file, reversible. If the fix is bigger, propose its first step only.
- **Measurable.** State what should change next time (fewer calls, no denial, no correction) so the gain can be checked.
- **Pain first.** If the user named a pain, address it, even if another signal looks bigger. Mention the bigger one in one line.
- If nothing is worth changing, say so. A clean session is a valid outcome.

## Step 4: Present, then apply only on confirmation

```
**Douleur / constat** : <user's pain or the signal found>
**Preuves** : <2–4 lines: timestamp + quote or metric>
**Cause racine** : <one sentence>
**Amélioration** : <the change, as a concrete diff or text>
**Où** : <file path>
**Gain attendu** : <what should disappear next time, estimated cost saved>
**Comment vérifier** : <the observable signal in a future session>
```

Apply only after the user says yes. Files deployed by chezmoi (`~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/settings.json`) are edited in their source under `~/.dotfiles/dot_claude/`, then the user runs `chezmoi apply <target>`. Memory entries follow the memory rules (one fact per file + index line, update rather than duplicate).

## Limits

- Evaluate the agent's behaviour and the setup, never the competence of a person. The user's prompts are context, not a target.
- Never copy secrets, tokens or personal data from a transcript into the output or into a file.
- Never rewrite a whole CLAUDE.md or skill "while you're at it". One improvement per run.
- Don't mistake plausible for proven: if the cause is a guess, say it is a hypothesis and what would confirm it.

$ARGUMENTS
