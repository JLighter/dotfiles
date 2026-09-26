---
name: harness-init
description: Initialise le harness d'un projet par un entretien avec AskUserQuestion : forge et branches, stack et vérifications, CLAUDE.md et rules du projet, permissions et MCP, skills et agents, documentation, hooks, pre-commit, CI, evals, environnement et hébergement. L'utilisateur choisit ce qu'il veut, chaque choix devient un fichier et une preuve. Utiliser quand l'utilisateur démarre un projet, veut mettre en place ou outiller Claude Code sur un dépôt, ou demande d'initialiser le harness d'un projet. Ne pas utiliser pour auditer un harness existant (harness-audit) ni pour un projet long à découper en fonctionnalités (marathon, qui peut être appelé à la fin).
---

# Initialiser le harness d'un projet

Le global reste lean et vaut pour tous les projets. Ce skill pose dans le projet tout ce qui lui est propre, et rien de plus. Chaque élément est choisi par l'utilisateur, répond à un besoin présent, et est posé comme mécanisme plutôt que comme consigne quand c'est possible.

## Étape 0 : constater avant de demander

Les faits se cherchent, ils ne se demandent pas. Avant la première question, relever sans rien écrire :

- git initialisé ou non, remote existant, forge (GitHub, GitLab…), branche par défaut ;
- stack détectée : fichiers de dépendances, gestionnaire de paquets, formateur, linter, typecheck, framework de tests déjà configurés ;
- harness existant : `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.mcp.json`, hooks git, `.pre-commit-config.yaml`, CI, `docs/` ;
- ce que le global couvre déjà (`~/.claude/settings.json`, `~/.claude/CLAUDE.md`, skills globaux) : ne jamais le dupliquer dans le projet.

Si le projet a déjà un harness substantiel, proposer `harness-audit` à la place et s'arrêter.

Ouvrir par un résumé de trois lignes : ce qui existe, ce qui manque, le niveau de sensibilité pressenti.

## Étape 1 : l'entretien, par vagues

Les décisions forment un arbre, décrit dans `references/arbre.md`. Une décision n'est posée que quand celles dont elle dépend sont tranchées. Chaque vague est un appel à AskUserQuestion, avec au plus quatre questions.

Règles des questions :

- **[technique]** : la première option est la recommandation, marquée « (Recommandé) », avec sa raison dans la description.
- **[métier]** : coût, budget, exposition publique, choix d'hébergeur, données sensibles. Options et conséquences, **sans recommandation**. L'arbitrage est à l'utilisateur.
- **Toujours une option « Pas maintenant »** pour ce qui n'est pas indispensable. KISS et YAGNI : un outil sans besoin présent est un coût.
- **multiSelect** pour les listes (skills, agents, serveurs MCP, environnements).
- **Irréversible signalé** dans la description : dépôt public, hébergeur avec verrouillage, données déjà en production.
- Une réponse « Other » est un fait nouveau : le vérifier dans le dépôt si c'est possible, et en tirer les questions qui en dépendent.
- Jamais de secret dans l'entretien. Pour un jeton ou une clé, demander seulement où il sera stocké.

## Étape 2 : le plan, avant tout fichier

Écrire `docs/harness/harness-plan.md` (frontmatter `id`, `type`, `status: draft`, `last-updated`) avec :

1. **Décisions** : tableau ID (`HI-01`…), décision, nature (métier ou technique), couche du harness, raison.
2. **Refusé ou reporté** : ce qui a reçu « Pas maintenant », pour que le prochain audit ne le compte pas comme un oubli.
3. **Fichiers à créer**, et pour chacun la **preuve** qui montrera qu'il agit.
4. **Actions externes**, laissées à l'humain avec leur commande exacte : création du dépôt distant, protection de branche, comptes d'hébergement, secrets de CI.
5. **Baby steps**, dans l'ordre : sécurité d'abord (deny, gitleaks), puis vérifications, puis confort.

Présenter le plan et attendre la validation. C'est le seul point d'arrêt obligatoire.

## Étape 3 : poser, un pas à la fois

Pour chaque pas du plan, avec les gabarits de `templates/` :

1. Écrire le fichier, adapté à la stack détectée.
2. Lancer sa preuve : un hook de vérification sort en 2 avec l'erreur sur stderr quand on lui donne une faute, et en 0 sans sortie sinon ; le pre-commit refuse un faux jeton et accepte un commit ordinaire ; la CI démarre.
3. Committer, un commit par pas, avec l'identifiant `HI-xx` dans le message.

Une preuve qui échoue arrête le pas : corriger ou retirer, jamais laisser un mécanisme non prouvé.

## Étape 4 : passer la main

- Si le projet dépassera une session, proposer `marathon`, qui installe la liste de fonctionnalités et le skill `reprise`.
- Recommander un premier `harness-audit` dans une nouvelle session : il sert de point zéro, et vérifie ce skill par un autre regard.
- Donner la liste des actions externes restant à faire par l'humain.

## Ce que ce skill ne fait pas

- Il ne crée ni dépôt distant, ni compte, ni ressource d'hébergement, et ne pousse rien : il donne les commandes.
- Il ne recommande pas sur un arbitrage métier.
- Il ne duplique pas le global dans le projet, et ne modifie pas `~/.claude`.
- Il n'installe rien qui n'ait été choisi, ni un mécanisme dont la preuve n'a pas été lancée.
- Il ne déclare pas le harness « prêt » : il rapporte ce qui est posé, prouvé, reporté.
