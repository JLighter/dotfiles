---
name: harness-init
description: Initialise ou met à jour le harness d'un projet par un entretien court avec AskUserQuestion : forge, agents de l'équipe, emplacement de la documentation, vérifications, instructions, permissions, hooks, pre-commit, CI, environnement et hébergement. Tout ce qui est partagé vit dans le dépôt, pour que chaque développeur le reçoive par git clone et ./init.sh. Chaque choix devient un fichier et une preuve. Utiliser quand l'utilisateur démarre un projet, veut outiller Claude Code sur un dépôt, ou relance l'initialisation d'un projet déjà initialisé par ce skill. Ne pas utiliser pour auditer un harness existant (harness-audit) ni pour découper un projet long (marathon, proposé à la fin).
disable-model-invocation: true
---

# Initialiser le harness d'un projet

Le dépôt est la seule configuration partagée : ce qui vit dans `~/.claude` n'existe que sur la machine de celui qui l'a écrit. Ce skill pose dans le projet ce qui lui est propre et ce dont ses mécanismes dépendent, et rien de plus. Chaque élément répond à un besoin présent, et est posé comme mécanisme plutôt que comme consigne quand c'est possible.

## Étape 0 : constater avant de demander

Les faits se cherchent, ils ne se demandent pas. Avant la première question, relever sans rien écrire :

- git initialisé ou non, remote, forge, visibilité, branche par défaut ;
- stack : fichiers de dépendances, gestionnaire de paquets, formateur, linter, typecheck, framework de tests ;
- harness existant : `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.mcp.json`, hooks git, `.pre-commit-config.yaml`, CI, `init.sh`, `docs/`, `docs/harness/harness-plan.md` ;
- documentation : `docs/`, `mkdocs.yml`, `docusaurus.config.*`, `.readthedocs.yaml`, wiki de la forge activé, serveur MCP de documentation déclaré ;
- ce que le global couvre (`~/.claude/settings.json`, `~/.claude/CLAUDE.md`, skills globaux).

Selon ce qui existe :

- **Rien ou presque** : initialisation, étapes 1 à 4.
- **`docs/harness/harness-plan.md` existe** : le projet a été initialisé par ce skill, c'est une **relance**. Périmètre : le bloc `## Harness` du fichier d'instructions et les fichiers listés au plan comme issus de `templates/`, rien d'autre. Pour chacun, montrer le diff entre le gabarit actuel adapté au projet et le fichier du projet, et demander confirmation fichier par fichier : l'équipe a pu adapter ces fichiers, rien n'est écrasé en silence. Une décision nouvelle entre au plan avec un nouvel identifiant `HI-xx`.
- **Harness substantiel sans ce plan** : proposer `harness-audit` et s'arrêter.

**Dépendances dures au global.** Une règle ou un outil du global qu'un mécanisme du projet lit ou applique (hook, pre-commit, CI, permission, skill ou agent du projet) est une dépendance dure : elle est recopiée dans le projet, même si le global la contient déjà. Une préférence que rien ne vérifie reste dans le global de chacun. En équipe, inventorier ces dépendances et les lister au plan ; seul, les lister aussi, le projet pourra changer de mains.

Ouvrir par un résumé de trois lignes : ce qui existe, ce qui manque, le niveau de sensibilité pressenti.

## Étape 1 : l'entretien, court

Les décisions forment un arbre, décrit dans `references/arbre.md`. Chaque nœud y est **Demandé**, **Au plan** ou **Constat**. Seuls les nœuds Demandés sont posés, par vagues d'au plus quatre questions ; une question n'est posée que dans une vague postérieure à celle de son parent. Quatre vagues au plus ; une vague vide est sautée.

Règles des questions :

- **[technique]** : la première option est la recommandation, marquée « (Recommandé) », avec sa raison dans la description.
- **[métier]** : coût, budget, exposition publique, choix d'hébergeur, données sensibles. Options et conséquences, **sans recommandation**. L'arbitrage est à l'utilisateur.
- **Toujours une option « Pas maintenant »** pour ce qui n'est pas indispensable. KISS et YAGNI : un outil sans besoin présent est un coût.
- **multiSelect** pour les listes.
- **Irréversible signalé** dans la description : dépôt public, hébergeur avec verrouillage, données déjà en production.
- Une réponse « Other » est un fait nouveau : le vérifier dans le dépôt si c'est possible, et en tirer les questions qui en dépendent.
- Jamais de secret dans l'entretien. Pour un jeton ou une clé, demander seulement où il sera stocké.

## Étape 2 : le plan, avant tout fichier

Écrire `docs/harness/harness-plan.md` (frontmatter `id`, `type`, `status: draft`, `last-updated`) avec :

1. **Décisions** : tableau ID (`HI-01`…), décision, origine (demandée, défaut ou constat), nature, couche du harness, raison. Pour un défaut, les autres options.
2. **Dépendances dures au global** recopiées dans le projet, avec leur source.
3. **Refusé ou reporté** : ce qui a reçu « Pas maintenant », pour que le prochain audit ne le compte pas comme un oubli.
4. **Fichiers à créer**, et pour chacun la **preuve** qui montrera qu'il agit.
5. **Actions externes**, faites une fois par l'humain, avec leur commande exacte : dépôt distant, protection de branche, comptes d'hébergement, secrets de CI (dont `GITLEAKS_LICENSE` pour un dépôt d'organisation GitHub), espace de documentation externe ou première page du wiki. Et la **preuve de la CI** : l'humain pousse une branche, ouvre une PR, et confirme que la CI a démarré et que ses jobs passent.
6. **Par développeur** : ce que chacun fait après `git clone`. Cible : `./init.sh`, puis approuver les serveurs de `.mcp.json` et s'authentifier aux outils externes s'il y en a. Rien d'autre : si la liste s'allonge, c'est `init.sh` qu'il faut compléter.
7. **Baby steps**, dans l'ordre : sécurité d'abord (deny, gitleaks, `.gitignore`), puis environnement, puis vérifications, puis confort.

Présenter le plan et attendre la validation. C'est le seul point d'arrêt obligatoire. Les défauts se changent ici.

## Étape 3 : poser, un pas à la fois

Pour chaque pas du plan, avec les gabarits de `templates/` :

1. Écrire le fichier, adapté à la stack détectée. Les scripts de hooks Claude Code vont dans `.claude/hooks/`. Les scripts sont rendus exécutables (`chmod +x`) et commités en mode `100755` (`git ls-files -s`). `.claude/settings.json` ne déclare que les hooks posés.
2. Lancer sa preuve : un hook de vérification sort en 2 avec l'erreur sur stderr quand on lui donne une faute, et en 0 sans sortie sinon ; `git-guard.sh` refuse `git commit --no-verify` et accepte `git commit -m "…"` ; le pre-commit refuse un faux jeton et accepte un commit ordinaire ; `init.sh` réussit deux fois de suite, et `CI=true ./init.sh` ne pose aucun hook ; le fichier de CI est un YAML valide (l'agent ne pousse pas : son démarrage est une preuve de l'humain, étape 2).
3. Committer, un commit par pas, avec l'identifiant `HI-xx` dans le message.

Une preuve qui échoue arrête le pas : corriger ou retirer, jamais laisser un mécanisme non prouvé.

Règles d'écriture :

- **Fichier d'instructions** : modifier celui qui existe, `CLAUDE.md` ou `AGENTS.md`, sans jamais créer l'autre à côté. Si aucun n'existe : `CLAUDE.md` pour une équipe sur Claude Code seul ; `AGENTS.md` et un `CLAUDE.md` réduit à `@AGENTS.md` si l'équipe utilise plusieurs agents.
- **Bloc `## Harness`** : une ligne par sujet posé, qui pointe vers le fichier qui le détaille (`templates/CLAUDE.md`) ; un sujet reporté n'a pas de ligne. Mis à jour sur place à la relance, sans doublon, sans toucher aux sections voisines.
- **Serveurs MCP** : `.mcp.json` depuis `templates/mcp.json`. Un jeton passe par `${VARIABLE}`, jamais en clair.
- **Documentation** : `docs/harness/documentation.md` depuis la variante de `templates/docs/` choisie, ou depuis la description de l'utilisateur pour « Other ». Les fichiers de contenu (glossaire, règles, ADR) ne sont pas créés d'avance : ils naissent avec le premier terme, la première règle ou la première décision tranchés.
- **Fichiers locaux** : ajouter `templates/gitignore` au `.gitignore` du projet, puis vérifier qu'aucune règle existante n'ignore un fichier partagé (`git check-ignore` sur `.claude/settings.json`, `.mcp.json`, le fichier d'instructions : aucun ne doit sortir).

Dernier pas, la **preuve du clone neuf** : `git clone` du projet dans `$TMPDIR`, `./init.sh`, puis les preuves du pre-commit et du hook d'édition dans ce clone. Elle montre ce qu'un autre développeur reçoit, pas ce qui marche sur la machine qui a initialisé.

## Étape 4 : passer la main

- Si le projet dépassera une session, proposer `marathon`, qui installe la liste de fonctionnalités et le skill `reprise`.
- Recommander un premier `harness-audit` dans une nouvelle session : il sert de point zéro, et vérifie ce skill par un autre regard.
- Donner la liste des actions externes et la section « Par développeur ».

## Ça marche si

- Dans un clone neuf, après `./init.sh` seul, le pre-commit refuse un faux jeton et accepte un commit ordinaire, et le hook d'édition sort en 2 sur une faute.
- `CI=true ./init.sh` ne pose aucun hook git et n'exige aucun outil de poste.
- Le fichier d'instructions que lisent les agents de l'équipe contient le bloc `## Harness`, et chaque pointeur mène à un fichier qui existe.
- `git ls-files` ne liste aucun fichier `*.local.*`, et `git check-ignore` ne sort aucun fichier partagé.
- L'agent ne peut pas sauter les hooks git : `git-guard.sh` refuse `--no-verify`, `commit -n` et le push forcé.
- Aucune dépendance dure listée au plan n'existe seulement dans `~/.claude`.
- La documentation est accessible à l'agent depuis un clone neuf : Markdown présent, wiki cloné par `init.sh`, ou serveur déclaré dans `.mcp.json`.
- Une relance du skill sur le projet ne modifie aucun fichier sans confirmation.

## Ce que ce skill ne fait pas

- Il ne crée ni dépôt distant, ni compte, ni espace de documentation, ni ressource d'hébergement, et ne pousse rien : il donne les commandes.
- Il ne recommande pas sur un arbitrage métier.
- Il ne recopie du global que les dépendances dures, et ne modifie pas `~/.claude`.
- Il n'installe rien qui n'ait été choisi ou validé au plan, ni un mécanisme dont la preuve n'a pas été lancée.
- Il ne déclare pas le harness « prêt » : il rapporte ce qui est posé, prouvé, reporté.
