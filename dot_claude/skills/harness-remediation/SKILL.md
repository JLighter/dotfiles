---
name: harness-remediation
description: Applique les recommandations d'un rapport d'audit de harness produit par harness-audit, une à la fois, dans l'ordre de priorité, chacune prouvée par un test qui échoue avant et passe après. Utiliser quand l'utilisateur demande d'appliquer, implémenter ou corriger les recommandations d'un audit de harness, ou de traiter un rapport HARNESS-AUDIT. Ne pas utiliser sans rapport d'audit, ni pour découvrir de nouveaux problèmes (c'est le rôle de harness-audit).
---

# Remédiation de harness

Ce skill applique ce qu'un audit a recommandé. Il ne découvre rien, ne juge pas son propre résultat, et ne tranche aucun choix laissé ouvert par le rapport. Chaque recommandation suit le cycle TDD : la preuve d'application du rapport est le test qui échoue, le mécanisme est ce qui le fait passer.

## Étape 0 : préconditions

- Un rapport produit par `harness-audit`, avec des recommandations numérotées par priorité et une preuve d'application pour chacune. Sans rapport, arrêter et proposer `harness-audit`.
- Une recommandation sans preuve d'application exécutable n'est pas appliquée : elle est renvoyée à l'audit avec le statut « preuve manquante ».
- La session de remédiation n'est pas la session de l'audit : l'agent qui corrige ne doit pas avoir produit le diagnostic.

## Étape 1 : revérifier chaque constat

Un rapport est daté. Depuis, un déploiement, une commande `/model` ou un installeur a pu changer la configuration. Pour chaque recommandation, relancer la vérification qui fonde son constat. Si le constat n'est plus vrai, statut « constat caduc », avec ce qui a changé, puis passer à la suivante.

## Étape 2 : arbitrages humains, en un seul lot

Relever dans le rapport tout ce qui n'appartient pas à l'agent, et le poser en une fois avec AskUserQuestion avant de commencer :

- les options « (a) / (b) » d'une recommandation ;
- les décisions dont le rapport dit qu'elles ne sont « pas établies » (une suppression voulue ou non, par exemple) ;
- toute suppression de règle, qui exige d'abord une mesure (étape 4).

Une recommandation dont l'arbitrage n'est pas rendu reste au statut « en attente d'arbitrage ».

## Étape 3 : une recommandation à la fois, dans l'ordre du rapport

Pour chacune, dans cet ordre strict :

1. **Plan.** Si elle touche les permissions, le sandbox, les secrets, le classifieur de l'auto mode ou un hook destructif, présenter le plan (fichiers, changement, preuve, retour arrière) et attendre la validation. Sinon, exécuter directement.
2. **Red.** Lancer la preuve d'application et constater qu'elle échoue. Si elle passe déjà, statut « déjà appliquée », rien à faire.
3. **Green.** Poser le mécanisme, le plus petit possible, puis relancer la preuve : elle doit passer.
4. **Negative space.** Vérifier ce que le changement ne doit pas casser, en l'écrivant avant de le tester : un commit légitime passe toujours, un fichier nouveau est toujours formaté, un outil autorisé l'est toujours. Voir `references/negative-space.md`.
5. **Commit.** Un commit par recommandation, qui cite son identifiant (`R2b`) et le pourquoi. Jamais un changement de structure et un changement de comportement dans le même commit.

Si une étape échoue, revenir à l'état d'avant la recommandation, noter l'échec, et passer à la suivante seulement si elle est indépendante.

## Fichiers protégés

Quand un fichier est protégé contre l'écriture de l'agent (deny `Edit`, sandbox), ne pas chercher à contourner la protection. Écrire le changement dans la source versionnée si elle existe (dépôt dotfiles, template chezmoi), sinon préparer un patch, et donner à l'humain la commande exacte qui l'applique. La preuve est lancée après son application.

## Étape 4 : mesurer ce qui ne se prouve pas par une commande

Retirer une règle d'instruction ou modifier un skill exige de mesurer l'effet, pas de le supposer :

- Pour un skill ou un plugin : `claude plugin eval <cible> --ablation with-without --no-publish --max-cost-usd <plafond>`, avant et après. Sans cas d'eval existants, en proposer cinq à dix tirés des constats du rapport et les faire valider avant de lancer quoi que ce soit.
- Pour une règle du CLAUDE.md : des tâches témoins rejouées avec et sans la règle, dans des sessions séparées.
- Toujours annoncer le nombre de sessions et le plafond de coût avant de lancer, et attendre l'accord.
- `--no-publish` est obligatoire : le rapport d'eval décrit l'intérieur du harness.

## Étape 5 : preuves déléguées

Une preuve qui exige plusieurs dépôts, une nouvelle session, ou un accès que l'agent n'a pas, n'est pas simulée. Statut « appliquée, preuve déléguée », avec la commande exacte à lancer par l'humain et le résultat attendu. La recommandation n'est « prouvée » qu'une fois ce résultat rapporté.

## Étape 6 : journal dans le rapport

Ajouter au rapport une section `## Remédiation <date>`, sans modifier les sections de l'audit, avec le tableau de `references/journal.md`. Passer `status` du frontmatter de `draft` à `remediation-en-cours`, puis `remediation-terminee` quand toutes les recommandations ont un statut final.

## Étape 7 : fermer la boucle

Recommander un nouvel audit, dans une nouvelle session, avec `harness-audit`. Comparer les trois chiffres du résumé avant et après. La remédiation est terminée quand un autre regard le constate, pas quand ce skill le déclare.

## Ce que ce skill ne fait pas

- Il ne déclare pas le harness « corrigé » ou « de bonne qualité » : il rapporte des statuts et des preuves.
- Il n'applique pas une recommandation sans preuve, ni un arbitrage que l'humain n'a pas rendu.
- Il ne contourne pas une protection (deny, sandbox) pour appliquer un changement.
- Il ne supprime pas une règle sans mesure.
- Il n'ajoute pas de recommandation : un nouveau problème découvert en chemin va dans le journal, section « Constats nouveaux », pour le prochain audit.
