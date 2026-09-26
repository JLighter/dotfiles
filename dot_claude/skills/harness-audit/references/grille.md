---
id: HARNESS-GRILLE
type: reference
status: draft
last-updated: 2026-09-26
---

# Grille de maturité par couche

Chaque niveau exige une preuve observable dans le dépôt. Sans preuve, le niveau n'est pas attribué.

Échelle commune :
- **0** : rien
- **1** : déclaré (des consignes existent, rien ne les fait respecter)
- **2** : mécanisé partiellement (au moins un mécanisme, sans couverture des cas coûteux)
- **3** : mécanisé et maintenu (mécanismes couvrant les cas coûteux, traçables à un échec, retestés)

## Couche 1 : instructions

| Niveau | Preuve exigée |
|---|---|
| 0 | Aucun fichier d'instructions |
| 1 | Fichier présent, plus de 60 lignes ou sans origine des règles |
| 2 | Fichier racine sous 60 lignes, contenu spécialisé migré en skills |
| 3 | Niveau 2 et chaque règle trace vers un échec observé (commentaire, lien, changelog) |

## Couche 2 : outils et permissions

| Niveau | Preuve exigée |
|---|---|
| 0 | Aucune règle de permission, tout est autorisé ou tout est demandé à l'humain |
| 1 | Des consignes d'usage d'outils dans les instructions, sans `permissions` ni sandbox |
| 2 | `permissions` avec au moins un deny sur les secrets et les commandes destructives |
| 3 | Niveau 2, sandbox actif, et chaque outil MCP déclaré justifié par un usage réel (pas d'outil dormant) |

## Couche 3 : contexte et mémoire

| Niveau | Preuve exigée |
|---|---|
| 0 | Tout le contexte est dans le fichier racine, rien n'est chargé à la demande |
| 1 | Des consignes disent quoi charger, mais aucun mécanisme ne le fait |
| 2 | Skills avec frontmatter déclencheur, ou sous-agents à contexte isolé |
| 3 | Niveau 2 et un artefact de transfert entre sessions (progress file, mémoire, feature list) lu au démarrage et à jour : aucune entrée contredite par l'état actuel. Une mémoire périmée ramène au niveau 2 |

## Couche 4 : boucles de vérification

| Niveau | Preuve exigée |
|---|---|
| 0 | Aucun hook Claude Code ni hook git, aucune vérification dans un pipeline CI |
| 1 | Des consignes de vérification dans les instructions, mais aucun mécanisme ne les exécute. Un test lancé par l'agent sur consigne reste à ce niveau |
| 2 | Au moins un hook PostToolUse dans settings.json, ou un pre-commit, qui exécute tests, lint ou typecheck, et dont la sortie atteint l'agent : stderr avec exit 2 sur PostToolUse, sans filtrage. Un hook qui sort en code 0 reste au niveau 1, Claude ne voit pas sa sortie |
| 3 | Quatre étages présents et filtrés : un hook PostToolUse sur Edit et Write qui lance format, lint et typecheck du fichier modifié et ne renvoie que les échecs, sur stderr avec exit 2 ; un hook Stop qui lance la suite unitaire, refuse la fin de tour tant qu'elle échoue et porte une garde contre la boucle ; un pre-commit qui vérifie la traçabilité dans le message ou le nom du commit et l'absence de secrets ; une CI qui rejoue la vérification complète sur le travail de l'agent avant fusion. Chaque hook ou job trace vers l'échec qui l'a motivé, en commentaire ou dans un changelog |

## Couche 5 : évaluation et observabilité

| Niveau | Preuve exigée |
|---|---|
| 0 | Aucune trace conservée, aucun eval |
| 1 | L'agent est invité à s'auto-évaluer (relecture, note) sans juge séparé |
| 2 | Un évaluateur distinct (agent, revue croisée, `claude plugin eval`) avec critères écrits |
| 3 | Niveau 2 et les résultats d'eval sont comparés à un bras sans harness, et conservés dans le dépôt |

## Couche 6 : environnement

| Niveau | Preuve exigée |
|---|---|
| 0 | L'agent travaille dans l'environnement de l'humain, sans isolation |
| 1 | Une consigne décrit comment démarrer, aucun script ne le fait |
| 2 | Script d'initialisation ou devcontainer reproductible, worktree ou branche dédiée |
| 3 | Niveau 2 et CI exécutée sur le travail de l'agent avant fusion, historique git lisible par session |
