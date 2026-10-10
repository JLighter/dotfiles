---
id: CLAUDE-PROJET
type: instructions
status: active
last-updated: <date>
modele-cible: <modèle>
---

<!-- Moins de 60 lignes. Rien de ce que le global dit déjà, sauf les dépendances dures listées au plan. Chaque règle porte son origine. -->

## Contexte narratif
<D'où vient le projet, quel problème il résout, choix structurants et pourquoi, zones sensibles, état actuel.>

## Commandes
- Installer et démarrer : `./init.sh`, après chaque clone
- Tests : `<commande>` · Lint : `<commande>` · Typecheck : `<commande>`

## Propre à ce projet
- <règle> (origine : <incident, ADR ou date>)

## Harness
Posé par harness-init, mis à jour sur place par une relance. Décisions : `docs/harness/harness-plan.md`.
<!-- Une ligne par sujet posé. Documentation reportée : supprimer sa ligne. -->
- Documentation : <où elle vit, en une ligne>. Voir `docs/harness/documentation.md`.
- Vérifications : <hooks, pre-commit, CI, en une ligne>.
