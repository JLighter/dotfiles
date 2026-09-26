---
id: HARNESS-INIT-ARBRE
type: reference
status: active
last-updated: 2026-09-27
---

# Arbre des décisions

Chaque nœud : la question, sa nature, ses options (la recommandation en premier pour les questions techniques), ce qu'elle produit. Une branche ne s'ouvre que si son parent l'appelle. Poser chaque vague avec AskUserQuestion, quatre questions au plus.

## Vague 1 : le cadre (racine)

| Question | Nature | Options | Produit |
|---|---|---|---|
| Nature du projet | technique | application web · API ou service · bibliothèque · infrastructure · contenu ou documentation · données | ouvre les branches stack, hébergement, tests |
| Durée | technique | une session ou quelques-unes · plusieurs semaines de travail d'agent | projet long → `marathon` à la fin |
| Qui travaille dessus | métier | seul · équipe · équipe et agents sans surveillance en CI | équipe → revue de PR et protection de branche ; CI sans surveillance → politique de permissions sans Ask |
| Sensibilité | métier | aucune donnée sensible · données personnelles · paiement ou finance · secrets d'infrastructure | élève le niveau de risque par défaut, active deny et gitleaks, restreint les MCP |

## Vague 2 : dépôt et forge

| Question | Nature | Options | Produit |
|---|---|---|---|
| Forge distante | métier | GitHub · GitLab · aucune pour l'instant · autre | commande de création, choix du format de CI |
| Visibilité | métier | privé · public (irréversible : l'historique reste) | public → gitleaks obligatoire avant le premier push |
| Flux de branches | technique | trunk avec branches courtes et PR (Recommandé) · branches longues · commit direct sur main | protection de branche, template de PR |
| Convention de commit | technique | Conventional Commits avec identifiant (Recommandé) · libre | hook commit-msg |

## Vague 3 : vérifications (couche 4)

Partir de ce qui est détecté. Ne proposer que ce qui manque.

| Question | Nature | Options | Produit |
|---|---|---|---|
| Boucle après édition | technique | lint et typecheck du fichier modifié, échecs seulement (Recommandé) · formateur en vérification seule · pas maintenant | hook PostToolUse, `templates/check-edit.sh` |
| Fin de tour | technique | suite unitaire, refus tant qu'elle échoue, garde anti-boucle (Recommandé si la suite dure moins de 2 min) · pas maintenant | hook Stop, `templates/stop-tests.sh` |
| Pre-commit | technique | gitleaks et message de commit (Recommandé) · gitleaks seul · pas maintenant | `templates/pre-commit-config.yaml` |
| Tests d'architecture | technique | direction des imports et cycles (fitness functions) · pas maintenant (Recommandé en début de projet) | configuration de l'outil de la stack |

Un formateur en mode écriture sur chaque édition n'est proposé que si tout le dépôt est déjà conforme : sinon il mêle structure et comportement dans chaque diff.

## Vague 4 : instructions et contexte (couches 1 et 3)

| Question | Nature | Options | Produit |
|---|---|---|---|
| CLAUDE.md du projet | technique | court : contexte narratif, commandes, conventions propres au projet (Recommandé) · aucun | `templates/CLAUDE.md`, moins de 60 lignes, rien de ce que le global dit déjà |
| Règles par type de fichier | technique | `.claude/rules/` avec `paths:` pour ce qui ne concerne qu'une partie du code · pas maintenant | un fichier par zone |
| Documentation | métier | Markdown dans `docs/` (glossaire, règles métier, ADR) · outil externe (Notion, Confluence…) · pas maintenant | arborescence `docs/`, ou lien dans le CLAUDE.md |
| Skills du projet (multiSelect) | technique | conventions d'un domaine précis · procédure de déploiement · aucune pour l'instant (Recommandé en début de projet) | un skill par besoin présent |

## Vague 5 : outils et agents (couches 2 et 5)

| Question | Nature | Options | Produit |
|---|---|---|---|
| Permissions du projet | technique | allow sur les commandes du projet, deny sur les secrets du projet (Recommandé) · rien de plus que le global | `.claude/settings.json` |
| Serveurs MCP du projet (multiSelect) | technique | base de données locale en lecture · navigateur pour les tests de bout en bout · aucun (Recommandé sans besoin présent) | `.mcp.json` ; jamais une base de production |
| Agent évaluateur | technique | relecteur à contexte séparé, qui juge le diff contre la spec (Recommandé) · pas maintenant | `.claude/agents/reviewer.md` |
| Evals | technique | pas maintenant, à écrire depuis les premiers échecs réels (Recommandé) · suite de départ | rien, ou `evals/` |

## Vague 6 : environnement et livraison (couche 6)

| Question | Nature | Options | Produit |
|---|---|---|---|
| Environnement de dev | technique | script `init.sh` idempotent (Recommandé) · devcontainer · docker compose · rien | `init.sh` ou fichiers correspondants |
| CI | technique | vérification complète sur chaque PR (Recommandé si forge) · pas maintenant | `templates/ci-github.yml` ou `templates/ci-gitlab.yml` |
| Hébergement | métier | aucun pour l'instant · plateforme gérée (Vercel, Netlify, Fly…) · cloud (AWS, GCP, Scaleway…) · auto-hébergé | commandes pour l'humain, variables de CI à créer ; jamais de compte créé par l'agent |
| Environnements (multiSelect) | métier | production · préproduction · aperçu par PR | jobs de déploiement, protections associées |

## Ce qui n'est jamais demandé

- Une valeur de secret : seulement l'endroit où il est stocké.
- Ce que le dépôt ou le global permettent de constater.
- Ce qui ne découle d'aucune branche ouverte.
