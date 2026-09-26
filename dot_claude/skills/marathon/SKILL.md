---
name: marathon
description: Initialise un projet long, qui demandera plusieurs sessions d'agent, selon le harness d'Anthropic pour agents longue durée. Produit une liste de fonctionnalités en JSON, un fichier de progression, un script init.sh, et installe dans le projet le hook et le skill de reprise qui relisent ces fichiers à chaque session. Utiliser quand l'utilisateur veut démarrer un projet ou une tâche qui dépassera une session, ou demande d'initialiser un harness longue durée. Ne pas utiliser pour une tâche qui tient en une session.
---

# Marathon

Ce skill joue le rôle de l'« initializer agent » de l'article d'Anthropic. Il ne tourne qu'une fois par projet. Il n'écrit aucun code applicatif : il prépare ce dont les sessions suivantes auront besoin pour reprendre sans mémoire. Source : Anthropic, « Effective harnesses for long-running agents », novembre 2025.

## Étape 0 : préconditions

- Si `features.json` ou `claude-progress.md` existe déjà à la racine, **arrêter** : le projet est initialisé. Dire à l'utilisateur d'utiliser le skill `reprise` du projet.
- Si le répertoire n'est pas un dépôt git, lancer `git init`.

## Étape 1 : comprendre la demande

Interroger l'utilisateur avec l'outil AskUserQuestion, par lots de questions courtes, jusqu'à pouvoir écrire chaque fonctionnalité avec des étapes de vérification observables. Sujets à couvrir : utilisateurs et parcours principaux, stack imposée ou libre, ce qui est hors périmètre, comment on vérifie qu'une fonctionnalité marche (navigateur, API, CLI).

## Étape 2 : liste de fonctionnalités

Écrire `features.json` à la racine selon `references/features.md` : schéma, critère de découpage, ordre de priorité.

## Étape 3 : script d'initialisation

Copier `templates/init.sh` à la racine, rendre exécutable, adapter les commandes à la stack. Le script doit être idempotent et sortir en erreur si le smoke test échoue. Le lancer une fois pour vérifier qu'il passe.

## Étape 4 : fichier de progression

Copier `templates/claude-progress.md` à la racine et remplir la session 0.

## Étape 5 : installer le mécanisme de reprise

1. Copier `templates/session-start.sh` et `templates/check-features.py` dans `.claude/hooks/` du projet, rendre exécutables.
2. Fusionner `templates/settings.json` dans `.claude/settings.json` du projet sans écraser l'existant. Il déclare le hook SessionStart et interdit `git commit --no-verify`.
3. Installer le pre-commit : `.git/hooks/pre-commit` appelle `.claude/hooks/check-features.py`.
4. Copier `templates/skills/reprise/` dans `.claude/skills/reprise/` du projet. C'est le protocole de session : ouverture, travail sur une fonctionnalité, clôture. Il vit dans le projet et non en global, parce qu'il n'a de sens que là où `features.json` existe.
5. Ajouter au `CLAUDE.md` du projet les trois lignes de `references/protocole.md`, et rien d'autre.

## Étape 6 : commit initial

Un commit qui contient tous ces fichiers, message « chore: initialise le harness longue durée », et une ligne dans `claude-progress.md` qui le référence.

## Ce que marathon ne fait pas

- Il n'implémente aucune fonctionnalité et ne passe aucun `passes` à `true`.
- Il ne réécrit pas un projet déjà initialisé.
- Il n'installe rien dans la configuration globale de l'utilisateur.
- Il ne décide pas seul du périmètre : chaque fonctionnalité hors de ce que l'utilisateur a dit est proposée, pas ajoutée.
