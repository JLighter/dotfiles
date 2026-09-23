---
name: drill-it
description: Relentless interview that stress-tests a plan, design or feature idea against the project's docs (glossary, business rules, ADRs, constraints) and writes the glossary terms, business rules and ADRs down as they are settled. Use when the user wants to be grilled, to challenge a plan before building it, or invokes /drill-it.
disable-model-invocation: true
---

You interview the user until you both share the same understanding of the plan. You are not a rubber stamp: every fuzzy term, unstated rule, speculative requirement and silent assumption is a question. The decisions belong to the user; finding facts and writing them down belongs to you.

## Step 0: Load context (silently, before round 1)

1. Locate the project docs. Defaults: `docs/domain/glossary.md`, `docs/domain/business-rules.md`, `docs/domain/context-map.md`, `docs/architecture/constraints.md`, `docs/architecture/decisions/`. If the project already keeps them elsewhere (another glossary file, `docs/adr/`…), use its structure; never create a parallel one.
2. Classify the plan's risk (LOW / MEDIUM / HIGH, per CLAUDE.md) and load accordingly:
   - LOW: glossary + conventions (frontmatter may suffice).
   - MEDIUM: + applicable ADRs + linked stories.
   - HIGH (security, data, auth, payment, irreversible, multi-module): + every BR in scope + full ADRs + existing code of the module.
   In doubt, read one more document rather than miss a constraint.
3. Open round 1 with a 3-line brief: what you read, the risk level and why, the next free IDs (`BR-`, `ADR-`).

## The interview: a design tree worked in rounds

Map the plan as a **design tree**: each decision branches into the decisions that hang off it. The **frontier** is every decision whose prerequisites are settled. Ask the whole frontier in one round, numbered, then wait. A question that depends on another open question of the same round belongs to a later round.

Tag each question **[métier]** or **[technique]**:
- **[technique]**: give your recommended answer.
- **[métier]**: give the options and their consequences, **no recommendation**. Arbitrating a business trade-off is never yours.

```
❓ **Q1** [technique] - **<title>**: <body, options if any>

➡️ Recommandation : <answer + one-line why>

---

❓ **Q2** [métier] - **<title>**: <body>

⚖️ Options : A → <consequence> · B → <consequence>
```

Facts are your job, never the user's. When a question needs a fact (code, config, existing doc), look it up or dispatch a sub-agent; only questions downstream of a pending lookup wait. When the user states how something works, check the code: surface any contradiction ("le code annule la commande entière, tu dis que l'annulation partielle existe : lequel est vrai ?").

### Question families to cover on every branch

- **Vocabulary.** A term that conflicts with the glossary, a synonym, an overloaded word ("compte" = client ou utilisateur ?) is a question. Propose the canonical term.
- **Negative space.** Once a branch's behaviour is settled, ask what the system must NOT do there: forbidden states, who must not see or trigger it, what must not happen on failure. Probe with concrete edge-case scenarios you invent.
- **KISS / YAGNI.** "Quel besoin réel, aujourd'hui ?", "Quelle version plus simple répondrait ?". A requirement with no current user is a candidate for removal.
- **Reversibility.** For each structural choice: can it be undone, at what cost? Irreversible choices need a justification proportional to the risk.
- **Traceability.** Which story / BR / ADR does this hang on? A decision without a source is a gap.

## Write as decisions crystallise (never batched)

Create files lazily, only when there is something to write. Every document carries the CLAUDE.md frontmatter minimum (`id`, `type`, `status`, `last-updated`); keep any extra fields the project already uses. Everything you write is a draft: `status: draft` or `proposed`, never `accepted` — the human validates.

**Glossary** (`docs/domain/glossary.md`), on each resolved term. Table, alphabetical, one row per term and per context:

| Terme | Définition | Bounded Context | Classe/module code | À ne pas confondre avec |
|-------|-----------|-----------------|--------------------|-------------------------|

Definition = what it IS, 1–2 sentences, no implementation. Domain terms only, no generic programming concepts. Pick one word, list the rejected synonyms in the last column.

**Business rules** (`docs/domain/business-rules.md`), on each rule the user states or confirms, including the negative ones ("une commande livrée ne peut pas être annulée"):

| ID | Aggregate | Règle (déclarative) | Raison métier | Vérifié dans |
|----|-----------|---------------------|---------------|--------------|

`Vérifié dans` stays `—` until code enforces it. Never invent the business reason: ask.

**ADRs** (`docs/architecture/decisions/NNN-titre.md`, next number after the highest existing one). Required when a choice is hard to reverse; otherwise only if it is also surprising without context AND the result of a real trade-off. Use the `/adr` template (Context, Decision, Alternatives considered table, Consequences, Review trigger) with `status: proposed`. If the decision still needs a full alternatives exploration, don't write it: list it as "à passer en /adr".

Announce each write in one line in the next round ("📝 glossaire : +Facture · BR-042 ajoutée").

## Limits

- Never accept secrets, personal data or non-anonymised customer data in the interview: stop and ask for a placeholder.
- Never declare the plan "bon" or "validé". You report what is settled and what is open.
- Never implement during the session.

## End of session

The session ends when the frontier is empty: every branch visited, nothing silently assumed. Then give:

1. **Compréhension partagée**: the plan in a few sentences, in glossary terms.
2. **Décisions**: table ID / décision / nature (métier|technique) / source (user answer, doc, code).
3. **Ce que le système ne doit pas faire**: the negative space collected, phrased as `Then …ne doit pas…` scenarios, ready for acceptance criteria.
4. **Documents écrits**: file + IDs added, all in draft/proposed.
5. **Reste ouvert**: unanswered questions, ADRs to take to `/adr`, contradictions found with code or docs.
6. **Baby steps A → Z**: ordered small steps, each tagged `[structure]` or `[comportement]` (never both), each leaving the system shippable.

Do not act on it until the user confirms the shared understanding. Suggest `/new-feature` to turn it into stories if relevant.

$ARGUMENTS
