---
id: HARNESS-AXES
type: reference
status: draft
last-updated: 2026-09-25
---

# Axes d'amélioration par couche

La grille (`grille.md`) mesure la présence des mécanismes. Ces axes mesurent leur effet. Chaque axe se recommande uniquement quand son constat déclencheur est fait à l'inventaire, nomme la règle déclarée qu'il remplace, et donne la preuve qui permettra de vérifier qu'il a été appliqué. Un axe sans déclencheur observé ne figure pas dans le rapport.

---

## Couche 1 : instructions

### Axe 1.1 : origine de chaque règle

| | |
|---|---|
| Constat déclencheur | Fichier racine de plus de 60 lignes, ou règles sans indication de l'échec qu'elles corrigent |
| Règle déclarée remplacée | Aucune : l'axe porte sur la forme des règles, pas sur leur contenu |
| Mécanisme | Chaque règle conservée reçoit une origine en commentaire ou en lien (incident, transcription, date). Une règle sans origine retrouvée après une période fixée est retirée, et l'effet du retrait est observé sur quelques sessions |
| Preuve dans le dépôt | Chaque règle du fichier racine porte une origine ; un changelog des règles retirées existe |
| Ce que l'axe ne fait pas | Il ne juge pas la valeur pédagogique d'une règle pour l'équipe humaine. Ce contenu va dans un guide d'équipe, hors du harness |

### Axe 1.2 : retest des règles à chaque changement de modèle

| | |
|---|---|
| Constat déclencheur | Le fichier racine n'indique pas de modèle cible, ou n'a pas été modifié depuis un changement de modèle |
| Règle déclarée remplacée | Toute règle écrite pour compenser un défaut d'un modèle antérieur |
| Mécanisme | À chaque changement de modèle, chaque règle est rejouée sur une tâche témoin avec et sans la règle. Une règle sans effet mesurable est retirée |
| Preuve dans le dépôt | Frontmatter du fichier racine avec `modele-cible` et `last-updated` ; résultats du retest conservés |
| Ce que l'axe ne fait pas | Il ne s'applique pas aux règles de contrat avec l'humain (langue, format de rapport), qui ne dépendent pas du modèle |

---

## Couche 2 : outils et permissions

### Axe 2.1 : budget d'outils

| | |
|---|---|
| Constat déclencheur | Plus de dix outils MCP déclarés, ou des serveurs MCP sans appel dans les transcriptions récentes, ou des outils MCP doublonnant une CLI installée |
| Règle déclarée remplacée | « Utiliser l'outil X pour… » quand X n'est jamais appelé |
| Mécanisme | Mesurer le coût en tokens des définitions d'outils chargées à chaque tour. Retirer les serveurs dormants. Remplacer par une CLI les outils dont une CLI existe (git, docker, gh). Charger les outils spécialisés via un skill plutôt qu'en permanence |
| Preuve dans le dépôt | `.mcp.json` réduit, chaque serveur justifié par un usage documenté ; mesure du coût avant et après |
| Ce que l'axe ne fait pas | Il ne retire pas un outil au seul motif qu'il est rarement utilisé, si son absence forcerait l'agent à improviser sur une opération risquée |

### Axe 2.2 : moindre privilège construit depuis l'usage

| | |
|---|---|
| Constat déclencheur | Absence de `permissions` dans settings, ou tout autorisé, ou l'humain approuve manuellement les mêmes commandes à chaque session |
| Règle déclarée remplacée | « Ne jamais lire les .env », « ne jamais exécuter rm -rf », « demander avant de push » |
| Mécanisme | Construire l'allowlist depuis les transcriptions réelles (commandes approuvées de façon répétée), poser les deny sur les secrets et les commandes destructives, activer le sandbox. Les règles d'instruction correspondantes sont supprimées |
| Preuve dans le dépôt | `permissions.allow` et `permissions.deny` peuplés, sandbox configuré, règles correspondantes absentes du CLAUDE.md |
| Ce que l'axe ne fait pas | Il ne remplace pas la validation humaine sur les actions irréversibles ou externes (push, déploiement, envoi), qui restent des portes d'approbation |

---

## Couche 3 : contexte et mémoire

### Axe 3.1 : divulgation progressive

| | |
|---|---|
| Constat déclencheur | Des sections du fichier racine ne servent que pour un type de tâche (documentation, tests, infra, commit), ou le contexte chargé à chaque tour dépasse ce qu'une tâche moyenne utilise |
| Règle déclarée remplacée | Toute section spécialisée du fichier racine |
| Mécanisme | Migrer chaque section spécialisée dans un skill avec une description déclencheuse précise. Mesurer les lignes chargées par tour avant et après. Vérifier que le skill se déclenche sur les tâches visées et pas sur les autres |
| Preuve dans le dépôt | Skills présents avec frontmatter, fichier racine réduit, mesure du contexte par tour |
| Ce que l'axe ne fait pas | Il ne migre pas une règle qui s'applique à toutes les tâches : un skill ne se charge que si la tâche correspond, il raterait les autres |

### Axe 3.2 : transfert entre sessions

| | |
|---|---|
| Constat déclencheur | Tâches qui dépassent une session, avec recommencements, travail perdu, ou l'agent qui redécouvre l'état du projet à chaque démarrage |
| Règle déclarée remplacée | « Lire le contexte existant avant de générer », « comprendre l'état initial » |
| Mécanisme | Un fichier de progression structuré, lu au démarrage et mis à jour en fin de session ; une liste de fonctionnalités en JSON dont l'agent ne modifie que le statut ; un commit descriptif par étape. Sur les tâches très longues, une remise à zéro du contexte à partir du fichier de transfert |
| Preuve dans le dépôt | Fichier de progression versionné, liste de fonctionnalités, hook ou consigne de démarrage qui les lit |
| Ce que l'axe ne fait pas | Il ne remplace pas la compaction automatique du harness, il la complète pour ce que le résumé perd |

---

## Couche 4 : boucles de vérification

### Axe 4.1 : non-régression comme cliquet

| | |
|---|---|
| Constat déclencheur | Règles d'instruction ajoutées après un incident (« ne plus jamais… »), ou historique git avec des corrections répétées du même type d'erreur |
| Règle déclarée remplacée | Toute consigne de la forme « ne pas refaire X » |
| Mécanisme | Chaque erreur de l'agent produit un test qui la reproduit, ajouté à la suite lancée par le hook PostToolUse. La règle d'instruction est ensuite supprimée, le test la porte |
| Preuve dans le dépôt | Tests nommés ou commentés avec la référence de l'incident, règle absente du CLAUDE.md |
| Ce que l'axe ne fait pas | Il ne remplace pas une règle de comportement conversationnel (langue, format), qu'aucun test ne peut capturer |

### Axe 4.2 : mutation testing

| | |
|---|---|
| Constat déclencheur | Suite de tests présente et verte, mais l'agent livre des bugs que les tests laissent passer, ou tests à assertions faibles (snapshot non justifié, attendu recopié de la sortie) |
| Règle déclarée remplacée | « Un test vérifie l'intention, pas l'implémentation », « quelle implémentation fausse ferait échouer ce test ? » |
| Mécanisme | Un outil de mutation (Stryker, PIT, mutmut, cargo-mutants selon le langage) tourne en CI sur le code modifié par l'agent. Un score sous le seuil bloque la fusion, et la liste des mutants survivants est renvoyée à l'agent |
| Preuve dans le dépôt | Configuration de l'outil, seuil dans la CI, rapport de la dernière exécution |
| Ce que l'axe ne fait pas | Il ne tourne pas dans un hook PostToolUse : trop lent. Sa place est la CI ou un job nocturne |

### Axe 4.3 : fitness functions

| | |
|---|---|
| Constat déclencheur | Principes de design déclarés dans les instructions (couplage, cohésion, dépendances, SOLID) sans aucun test qui les vérifie, ou revues humaines qui signalent de façon répétée des violations d'architecture dans le code produit par l'agent |
| Règle déclarée remplacée | « Le métier ne dépend pas de l'infrastructure », « ce qui change ensemble vit ensemble », « chaque dépendance ajoutée est justifiée », et toute définition de principe de design |
| Mécanisme | Chaque principe devient un test d'architecture exécutable : direction des imports entre couches, absence de cycles, taille maximale d'un module, liste blanche des dépendances. Outils selon le langage : ArchUnit, NetArchTest, dependency-cruiser, import-linter. Les tests rapides (imports, cycles) tournent dans le hook PostToolUse et ne renvoient que les violations ; les tests lents (métriques globales) tournent en CI. Les définitions de principes sont supprimées des instructions, remplacées par une ligne qui renvoie aux tests |
| Preuve dans le dépôt | Tests d'architecture versionnés, chacun nommé d'après le principe qu'il porte ; hook ou job qui les exécute ; principes absents du CLAUDE.md sauf renvoi |
| Ce que l'axe ne fait pas | Il ne capture pas les principes qui demandent un jugement (KISS, YAGNI, réversibilité). Ceux-là restent une revue humaine, ou une consigne courte si l'on accepte qu'elle soit seulement déclarée |

---

## Couche 5 : évaluation et observabilité

### Axe 5.1 : évaluateur séparé

| | |
|---|---|
| Constat déclencheur | Les instructions demandent à l'agent de relire, vérifier ou noter son propre travail, sans juge distinct ; ou l'agent déclare des tâches terminées qui ne le sont pas |
| Règle déclarée remplacée | « Relis ton travail », « vérifie avant de rendre », « ne dis jamais c'est bon » |
| Mécanisme | Un agent évaluateur à contexte séparé, qui ne voit pas le raisonnement du générateur, teste le résultat comme un utilisateur (Playwright, appels d'API, exécution) contre des critères écrits avant le travail, et rend une preuve par critère. Le générateur ne peut pas clore une tâche sans ce verdict |
| Preuve dans le dépôt | Définition de l'agent évaluateur, critères versionnés, verdicts conservés par tâche |
| Ce que l'axe ne fait pas | Il n'évalue pas le harness lui-même, seulement le travail produit. L'évaluation du harness relève de l'axe 5.2 |

### Axe 5.2 : evals à bras témoin

| | |
|---|---|
| Constat déclencheur | Des skills, hooks ou règles ont été ajoutés sans mesure de leur effet, ou une modification du harness a été justifiée par une impression |
| Règle déclarée remplacée | Aucune : l'axe porte sur la façon de faire évoluer le harness |
| Mécanisme | Un jeu de tâches témoin rejoué avec et sans le composant évalué (`claude plugin eval` ou équivalent). Un composant que le bras sans lui réussit aussi bien n'est pas conservé. Les résultats sont versionnés et comparés à chaque changement de modèle |
| Preuve dans le dépôt | Répertoire d'evals, résultats datés, décision de conserver ou retirer tracée pour chaque composant |
| Ce que l'axe ne fait pas | Il ne remplace pas les tests du code. Il teste le harness, pas le produit |

---

## Couche 6 : environnement

### Axe 6.1 : environnement reproductible par tâche

| | |
|---|---|
| Constat déclencheur | L'agent travaille dans l'environnement de développement de l'humain, sur la même branche ; ou les sessions commencent par des installations, des configurations, des erreurs d'environnement |
| Règle déclarée remplacée | Consignes de démarrage (« lancer npm install », « vérifier que la base tourne ») |
| Mécanisme | Un script d'initialisation ou un devcontainer qui amène l'environnement à un état connu ; un worktree ou une branche par tâche ; un commit vide qui marque le début de session. L'agent démarre toujours du même point |
| Preuve dans le dépôt | Script d'initialisation versionné, worktrees ou branches par tâche visibles dans l'historique |
| Ce que l'axe ne fait pas | Il n'isole pas l'agent des services externes partagés (bases de données de recette, API tierces), qui demandent un environnement dédié |

### Axe 6.2 : CI sur le travail de l'agent avant fusion

| | |
|---|---|
| Constat déclencheur | Le code produit par l'agent est fusionné après une relecture humaine seule, ou les hooks locaux sont la seule vérification |
| Règle déclarée remplacée | « Ne livrer que si les tests passent », « chaque livrable est validé par un autre regard » |
| Mécanisme | La CI rejoue sur chaque branche d'agent l'ensemble des vérifications des couches 4 et 5 : tests, lint, typecheck, fitness functions, mutation si configurée, évaluateur si configuré. La fusion est bloquée sans passage. Les hooks locaux restent pour le retour rapide, la CI est la vérification de référence |
| Preuve dans le dépôt | Workflow CI déclenché sur les branches d'agent, protection de branche exigeant son passage |
| Ce que l'axe ne fait pas | Il ne dispense pas de la revue humaine sur ce que la CI ne mesure pas : pertinence métier, lisibilité, choix de conception |
