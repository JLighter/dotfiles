---
id: RULE-DOCS
type: rule
status: active
last-updated: 2026-09-26
paths:
  - "docs/**/*.md"
  - "**/CLAUDE.md"
---

## Lisibilité LLM — Convention universelle

Tout document produit dans le projet doit être **immédiatement compréhensible par un LLM** sans parser l'intégralité du contenu. Quatre règles :

1. **Frontmatter YAML obligatoire** — Chaque fichier Markdown porte un frontmatter avec au minimum : `id`, `type`, `status`, `last-updated`. Le frontmatter seul doit suffire à comprendre ce qu'est le document, son état et ses relations.

2. **Identifiants explicites et grepables** — Chaque référence croisée utilise un identifiant formel (`BR-XXX`, `US-XXX`, `ADR-XXX`, `EPIC-XXX`, `AC-XX`, `FF-XXX`, `CONV-XXX`). Un `grep` sur un ID retourne tous les documents liés.

3. **Headings sémantiques** — Les titres de section décrivent le contenu, pas le format. Un LLM qui lit les headings comprend la structure sans lire le corps.

4. **Pas d'implicite** — Tout ce qui est nécessaire pour comprendre le document est dans le document. Pas de "cf. la dernière réunion", pas de contexte oral non transcrit.


## Structure documentaire

Le projet organise sa documentation pour couvrir :
- **Besoin** — objectifs, besoins utilisateurs, règles métier
- **Domaine** — vocabulaire partagé, invariants métier
- **Architecture** — décisions techniques (ADR), contrats d'API, vues C4
- **Design** — principes visuels, composants, accessibilité
- **Standards** — conventions de code, critères de revue
- **Dette et défauts** — compromis identifiés, bugs connus
- **Opérations** — déploiement, monitoring, runbooks

Ce qui n'est pas dans le dépôt n'existe pas.


## Contexte narratif du projet

Le CLAUDE.md du projet doit inclure une section **Contexte narratif** qui raconte l'histoire du projet — pas sa structure, mais son parcours :

- D'où vient ce projet ? Quel problème résout-il ?
- Quels choix structurants ont été faits et pourquoi ?
- Quelles sont les zones sensibles (historique d'incidents, dette connue, complexité accidentelle) ?
- Quel est l'état actuel ? Qu'est-ce qui est stable, qu'est-ce qui est en chantier ?

Ce contexte narratif permet à un agent de faire des **jugements proportionnés** : être plus prudent sur le module d'authentification qui a eu 3 incidents, plus confiant sur l'API CRUD qui est stable depuis 6 mois.


