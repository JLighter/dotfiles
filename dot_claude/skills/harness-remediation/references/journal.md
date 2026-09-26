---
id: REMEDIATION-JOURNAL
type: reference
status: active
last-updated: 2026-09-26
---

# Format du journal de remédiation

Section ajoutée à la fin du rapport d'audit, sans toucher aux sections existantes.

```markdown
## Remédiation <date>

Session distincte de l'audit. Modèle : <modèle>.

| Reco | Statut | Red (avant) | Green (après) | Negative space | Commit | Remarque |
|---|---|---|---|---|---|---|
| R2b | prouvée | commit avec faux glpat- accepté | refusé par gitleaks | commit légitime accepté | a1b2c3d | |
| R3 | appliquée, preuve déléguée | — | à lancer : `claude auto-mode config` dans deux dépôts | — | e4f5a6b | commande et résultat attendu ci-dessous |

### Constats nouveaux
Découverts pendant la remédiation, non traités, pour le prochain audit.
```

## Statuts

| Statut | Sens |
|---|---|
| prouvée | Red constaté, Green constaté, negative space vérifié |
| appliquée, preuve déléguée | mécanisme en place, preuve à lancer par l'humain |
| déjà appliquée | la preuve passait avant tout changement |
| constat caduc | le constat de l'audit n'est plus vrai |
| en attente d'arbitrage | un choix humain n'a pas été rendu |
| preuve manquante | le rapport ne donne pas de preuve exécutable |
| échouée, revenue en arrière | une étape a échoué, l'état d'avant est restauré |
