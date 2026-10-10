---
id: HARNESS-INIT-ARBRE
type: reference
status: active
last-updated: 2026-09-27
---

# Arbre des décisions

Chaque nœud a une nature (technique ou métier) et un mode :

- **Demandé** : posé avec AskUserQuestion. Toutes les questions métier, et les questions techniques sans défaut évident.
- **Au plan** : question technique à recommandation claire. Elle n'est pas posée : la recommandation entre dans le plan (étape 2) marquée « défaut », avec les autres options, et l'utilisateur la change à la validation. Rien n'est décidé en silence.
- **Constat** : un nœud que l'exploration a tranché n'est ni posé ni proposé ; il figure au plan comme constat.

Une question n'est posée que dans une vague postérieure à celle de son parent. Quatre vagues au plus, quatre questions au plus par vague ; une vague vide est sautée.

## Vague 1 : le cadre

| Question | Nature | Posée si | Options | Produit |
|---|---|---|---|---|
| Nature du projet | technique | l'exploration ne tranche pas | la plus probable d'après l'exploration (Recommandé) · application web · API ou service · bibliothèque · infrastructure · contenu ou documentation · données | stack, tests, options d'hébergement proposées |
| Durée | technique | toujours | une session ou quelques-unes (Recommandé : `marathon` s'ajoute plus tard sans perte) · plusieurs semaines de travail d'agent | projet long → `marathon` à la fin |
| Qui travaille dessus | métier | toujours | seul · équipe · équipe et agents sans surveillance en CI | équipe → revue de PR, protection de branche ; CI sans surveillance → permissions sans Ask |
| Sensibilité | métier | toujours | aucune donnée sensible · données personnelles · paiement ou finance · secrets d'infrastructure | élève le niveau de risque par défaut, restreint les MCP |

## Vague 2 : forge, hébergement, agents

| Question | Nature | Posée si | Options | Produit |
|---|---|---|---|---|
| Forge distante | métier | aucun remote détecté | GitHub · GitLab · aucune pour l'instant · autre | commande de création, format de CI |
| Hébergement | métier | nature ≠ bibliothèque, contenu | aucun pour l'instant · plateforme gérée (Vercel, Netlify, Fly…) · cloud (AWS, GCP, Scaleway…) · auto-hébergé | commandes pour l'humain, variables de CI ; jamais de compte créé par l'agent |
| Agents de l'équipe | technique | équipe | Claude Code seul (Recommandé si personne n'utilise autre chose) · plusieurs agents (Codex, Cursor…) | plusieurs → `AGENTS.md` de référence et `CLAUDE.md` réduit à `@AGENTS.md` |

## Vague 3 : ce qui dépend de la vague 2

| Question | Nature | Posée si | Options | Produit |
|---|---|---|---|---|
| Visibilité | métier | forge choisie et visibilité non détectée | privé · public (irréversible : l'historique reste) | public → gitleaks en CI obligatoire avant le premier push |
| Emplacement de la documentation | métier | aucun outil de documentation détecté | voir la branche Documentation | `docs/harness/documentation.md` |
| Environnements (multiSelect) | métier | hébergement ≠ aucun | production · préproduction · aperçu par PR | jobs de déploiement, protections associées |
| Fin de tour | technique | la suite unitaire dure plus de 2 min | pas maintenant (Recommandé : une suite lente bloque chaque tour) · suite unitaire, refus tant qu'elle échoue | hook Stop, `templates/stop-tests.sh` |

## Vague 4 : ce qui dépend de la vague 3

| Question | Nature | Posée si | Options | Produit |
|---|---|---|---|---|
| Publication de la documentation | technique | documentation = Markdown dans le dépôt | aucune (Recommandé : YAGNI, ajoutable sans migration) · Docusaurus · MkDocs · Read the Docs (hébergé, compte à créer) | configuration du générateur ; la source reste `docs/` |

### Branche Documentation

Critère déclaré par l'utilisateur : outils plats, ou à forte intégration IA (serveur MCP officiel). Question métier, donc **sans recommandation** ; les options sont classées selon ce critère et chaque description dit ce qu'elle coûte.

| Option | Description à montrer | Produit |
|---|---|---|
| Markdown dans le dépôt | Plat, versionné avec le code, relu en PR, reçu par chaque `git clone`, identifiants `BR-XXX`/`ADR-XXX` trouvables par grep. Un site peut en être généré (vague 4). | `templates/docs/documentation-depot.md` |
| Outil externe avec serveur MCP (Notion, Confluence, Asana…) | Lu par l'agent via MCP. Chaque développeur approuve le serveur et s'authentifie. Licence éventuelle. Identifiants non trouvables par grep dans le dépôt, pas versionnés avec le code. | `templates/docs/documentation-mcp.md`, `templates/mcp.json` |
| Wiki de la forge (proposé seulement si forge GitHub ou GitLab) | Markdown plat, mais dépôt git séparé : pas cloné avec le code, pas relu en PR. N'existe qu'après la création de sa première page. | `templates/docs/documentation-wiki.md`, `.wiki/` dans `.gitignore`, clonage par `init.sh` |
| Pas maintenant | Aucun fichier, aucune ligne Documentation dans le bloc `## Harness`. | reporté au plan |

« Other » : l'utilisateur décrit l'outil en un paragraphe, écrit tel quel dans `docs/harness/documentation.md`. Vérifier que l'outil a un serveur MCP ou une CLI ; sinon, le signaler : l'agent ne pourra pas lire cette documentation.

## Au plan : défauts techniques, jamais posés

| Nœud | Défaut | Autres options | Produit |
|---|---|---|---|
| Flux de branches | trunk avec branches courtes et PR | branches longues · commit direct sur main | protection de branche, template de PR |
| Convention de commit | Conventional Commits avec identifiant | libre | hook commit-msg de `templates/pre-commit-config.yaml` |
| Pre-commit | gitleaks et message de commit | gitleaks seul · pas maintenant | `templates/pre-commit-config.yaml` |
| Garde git de l'agent | refus de `--no-verify`, `commit -n`, push forcé | pas maintenant | hook PreToolUse, `templates/git-guard.sh` |
| Boucle après édition | lint et typecheck du fichier modifié, échecs seulement | formateur en vérification seule · pas maintenant | hook PostToolUse, `templates/check-edit.sh` |
| Fin de tour (suite < 2 min) | suite unitaire, refus tant qu'elle échoue, garde anti-boucle | pas maintenant | hook Stop, `templates/stop-tests.sh` |
| Tests d'architecture | pas maintenant en début de projet | direction des imports et cycles | configuration de l'outil de la stack |
| Fichier d'instructions | court, avec le bloc `## Harness` | aucun | `templates/CLAUDE.md`, moins de 60 lignes |
| Règles par type de fichier | pas maintenant | `.claude/rules/` avec `paths:` | un fichier par zone |
| Skills du projet | aucun en début de projet | un skill par besoin présent | `.claude/skills/` |
| Permissions du projet | allow sur les commandes du projet, deny sur ses secrets | rien de plus que le global | `templates/settings.json` → `.claude/settings.json` |
| Serveurs MCP du projet | aucun sans besoin présent | base locale en lecture · navigateur pour l'e2e | `templates/mcp.json` → `.mcp.json` ; jamais une base de production |
| Agent évaluateur | relecteur à contexte séparé | pas maintenant | `templates/reviewer.md` → `.claude/agents/reviewer.md` |
| Evals | pas maintenant, à écrire depuis les premiers échecs réels | suite de départ | rien, ou `evals/` |
| Environnement de dev | `init.sh` | devcontainer (mêmes responsabilités dans `postCreateCommand`) · docker compose | `templates/init.sh` |
| Hooks git sans action (projet Node) | script `prepare` qui appelle `./init.sh --hooks-only` | rien | `package.json` |
| CI (si forge) | vérification complète et scan de secrets sur chaque PR | pas maintenant | `templates/ci-github.yml` ou `templates/ci-gitlab.yml` |

Les scripts de hooks Claude Code vont dans `.claude/hooks/`, chemin qu'utilise `templates/settings.json`. Un hook refusé ou reporté est retiré de `.claude/settings.json` en même temps que son script n'est pas posé.

Un formateur en mode écriture sur chaque édition n'est proposé que si tout le dépôt est déjà conforme : sinon il mêle structure et comportement dans chaque diff.

## Ce qui n'est jamais demandé

- Une valeur de secret : seulement l'endroit où il est stocké.
- Ce que le dépôt ou le global permettent de constater.
- Ce qui ne découle d'aucune branche ouverte.
