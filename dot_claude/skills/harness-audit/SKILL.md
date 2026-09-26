---
name: harness-audit
description: Audit du harness d'un dépôt ou de la configuration globale ~/.claude (CLAUDE.md, AGENTS.md, skills, hooks, permissions, MCP, CI, mémoire) avec une grille par couche et un rapport déclaré vs mécanisé. Utiliser quand l'utilisateur demande d'auditer, diagnostiquer ou évaluer la configuration agent d'un projet ou sa configuration globale, la maturité de son harness, ou pourquoi son agent est peu fiable. Mots-clés : audit harness, diagnostic CLAUDE.md, maturité agent, déclaré vs mécanisé.
---

# Audit de harness

Un harness est tout ce qui entoure le modèle et façonne son comportement. Cet audit répond à une seule question par élément trouvé : **qui exécute l'action, le modèle sur consigne ou un mécanisme extérieur ?** Une consigne est déclarée. Un hook, une permission, un job CI, un sandbox sont mécanisés.

## Étape 0 : cadrage

Fixer trois choses avant de lire le moindre fichier. Si l'utilisateur ne les a pas données, les demander avec AskUserQuestion.

1. **Le périmètre.** Un dépôt, la configuration globale `~/.claude`, ou les deux. Le harness d'une session est la somme du global et du projet : auditer les deux et les lire ensemble donne le diagnostic complet.
2. **L'emplacement du rapport.** Toujours hors du périmètre audité, pour que l'audit ne modifie rien de ce qu'il mesure. Par défaut : le répertoire de travail courant s'il n'est pas audité, sinon le demander.
3. **Les couches hors périmètre.** Pour la configuration globale, les couches 5 et 6 (evals, CI, scripts d'initialisation, conteneurs) vivent dans les projets : les déclarer hors périmètre dès le départ.

## Étape 1 : inventaire

Lister, sans juger, tout ce qui existe. Pour un dépôt, chercher dans cet ordre :

| Couche | Où chercher |
|---|---|
| 1 Instructions | `CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`, `~/.claude/CLAUDE.md`, `.cursorrules`, output styles, corps des `SKILL.md` |
| 2 Outils et permissions | `.claude/settings*.json` (`permissions`), `.mcp.json`, sandbox, `allowed-tools` des skills |
| 3 Contexte et mémoire | frontmatter des `SKILL.md`, répertoire memory, fichiers de progression, sous-agents dans `.claude/agents/` |
| 4 Boucles de vérification | `hooks` dans settings, pre-commit, `.github/workflows`, linters custom |
| 5 Évaluation et observabilité | `evals/`, `claude plugin eval`, agents évaluateurs, traces |
| 6 Environnement | scripts d'init, worktrees, Dockerfile, devcontainer, CI |

Pour la configuration globale, chercher dans `~/.claude/` :

| Couche | Où chercher |
|---|---|
| 1 Instructions | `CLAUDE.md`, `rules/`, `output-styles/`, corps des `skills/*/SKILL.md` |
| 2 Outils et permissions | `settings.json` et `settings.local.json` (`permissions`, `sandbox`), serveurs MCP des plugins, `~/.claude.json` pour les serveurs MCP utilisateur |
| 3 Contexte et mémoire | frontmatter des `skills/*/SKILL.md`, `agents/`, `projects/*/memory/` |
| 4 Boucles de vérification | `hooks` dans `settings*.json` et les scripts qu'ils appellent dans `hooks/` |
| Versionnement du harness | la source de `~/.claude` si elle existe (dépôt dotfiles, chezmoi, stow, liens symboliques), son historique git, et la **dérive** entre source et déployé dans les deux sens |

La dérive entre source et déployé est un constat à part entière : une modification faite sur place est perdue au prochain déploiement, et un déploiement complet peut écraser ou recréer des fichiers. Relever le sens de chaque écart et ce qu'un déploiement produirait.

Pour chaque élément, noter : chemin, couche, **déclaré ou mécanisé**, nombre de lignes si c'est un fichier d'instructions.

**Angles morts.** Tout fichier qui n'a pas pu être lu (refus du sandbox, permission, absence d'accès) est noté avec la raison. Un angle mort n'est jamais compté comme une absence : `~/.claude.json` illisible ne veut pas dire « aucun serveur MCP ».

Pour un hook, lire le script qu'il appelle, pas seulement sa déclaration : ce qu'il renvoie, avec quel code de sortie, et s'il modifie des fichiers.

Pour une mémoire ou un fichier de progression, vérifier qu'il est à jour : une entrée contredite par l'état actuel (outil disparu, procédure remplacée) est notée comme périmée.

Pour la couche 5, relever les suites d'evals existantes et leurs derniers résultats, sans les lancer (voir « Ce que cet audit ne fait pas »).

## Étape 2 : déclaré contre mécanisé

Pour chaque règle d'instruction trouvée en couche 1, se demander : si le modèle ignore cette ligne, qui l'arrête ? Trois issues :

- Rien ne l'arrête et ça coûte cher → recommander un mécanisme (couche 2, 4 ou 6), nommé précisément.
- Rien ne l'arrête et ça coûte peu → la règle reste déclarée, à condition d'être courte et de tracer vers un échec observé.
- Quelque chose l'arrête déjà → la règle est redondante avec un mécanisme, la signaler.

## Étape 3 : niveau de maturité par couche

Attribuer un niveau de 0 à 3 à chaque couche selon la grille de `references/grille.md`. Ne jamais attribuer un niveau par impression : chaque niveau exige la preuve listée dans la grille.

Une couche déclarée hors périmètre à l'étape 0 reçoit « hors périmètre », pas 0. Une couche dont les preuves sont dans un angle mort reçoit le niveau prouvé par ce qui a été lu, avec la mention « partiel ».

## Étape 4 : rapport

Écrire le rapport à l'emplacement fixé à l'étape 0, avec ce frontmatter et ces sections, dans cet ordre :

```markdown
---
id: HARNESS-AUDIT-<date>
type: audit
status: draft
last-updated: <date>
modele-cible: <modèle en usage au moment de l'audit>
perimetre: <dépôt audité, configuration globale, ou les deux>
confidentialite: interne
---
## Résumé en trois chiffres
lignes d'instructions chargées à chaque tour / règles mécanisées sur règles totales / couches à 0 (hors périmètre exclues)
## Périmètre et angles morts
ce qui a été audité, les couches hors périmètre et pourquoi, les fichiers non lus et pourquoi
## Maturité par couche
tableau couche, niveau, preuve
## Inventaire
## Règles déclarées sans mécanisme
tableau règle, coût si ignorée, mécanisme recommandé
## Recommandations
au plus cinq, numérotées dans l'ordre de priorité, chacune traçable à une ligne de l'inventaire, avec le mécanisme nommé et une preuve d'application exécutable
## Constats sans recommandation
ce qui dépasse les cinq, gardé pour un audit suivant
```

**Priorité.** Les recommandations sont numérotées dans l'ordre où elles doivent être appliquées, et chacune dit pourquoi elle est à ce rang. L'ordre suit le risque : d'abord l'irréversible (secret exposé, dépôt public, suppression de données), puis la sécurité, puis la dérive de configuration, puis le confort et la réduction de contexte. Une recommandation qui en regroupe plusieurs indépendantes compte pour autant de recommandations.

**Confidentialité du rapport.** Le rapport décrit l'intérieur d'un harness : noms de dépôts, de services, de buckets, chemins internes. Il ne contient jamais la valeur d'un secret ni le contenu d'un fichier sensible, et il porte `confidentialite: interne`. Le signaler à l'utilisateur si l'emplacement choisi est dans un dépôt public ou partagé.

Pour rédiger les recommandations, consulter `references/axes-amelioration.md` : la grille mesure la présence des mécanismes, les axes mesurent leur effet. Un axe n'est recommandé que si son constat déclencheur a été fait à l'inventaire. Chaque recommandation issue d'un axe nomme ce constat et la règle déclarée qu'elle remplace.

## Ce que cet audit ne fait pas

- Il ne modifie aucun fichier du périmètre audité. Le rapport est écrit à l'emplacement choisi au cadrage, hors de ce périmètre.
- Il ne présente pas un angle mort comme une absence, ni une couche hors périmètre comme une couche à 0.
- Il ne lance pas de suite d'evals (`claude plugin eval`) : chaque cas démarre une session payante, les résultats sont écrits dans le périmètre audité, et le rapport HTML est publié par défaut. Mesurer l'effet d'un composant appartient à la remédiation (skill `harness-remediation`).
- Il n'applique aucune recommandation : c'est le rôle du skill `harness-remediation`, dans une autre session.
- Il ne recommande jamais de supprimer une règle sans dire ce qui la remplace ou pourquoi le modèle la respecte déjà.
- Il ne note pas la qualité du code, seulement celle du harness.
- Il ne juge pas une règle « bonne » ou « mauvaise » : il dit si elle est déclarée ou mécanisée, et ce qu'elle coûte.
