---
id: INIT-FEATURES
type: reference
status: draft
last-updated: 2026-09-26
---

# Liste de fonctionnalités

## Schéma

```json
[
  {
    "id": "F-001",
    "category": "functional",
    "priority": 1,
    "description": "Le bouton Nouvelle conversation ouvre une conversation vide",
    "steps": [
      "Ouvrir l'interface principale",
      "Cliquer sur Nouvelle conversation",
      "Vérifier que la liste des messages est vide et le champ de saisie actif"
    ],
    "passes": false
  }
]
```

- `id` : identifiant grepable, repris dans les messages de commit.
- `category` : `functional`, `ui`, `api`, `infra`, `non-functional`.
- `priority` : entier, 1 est le plus prioritaire. Les sessions prennent la plus prioritaire à `passes: false`.
- `steps` : étapes qu'un évaluateur extérieur peut rejouer, pas une description d'implémentation.
- `passes` : seul champ que les sessions de code ont le droit de modifier. Le pre-commit `check-features.py` refuse tout autre changement.

## Critère de découpage d'une fonctionnalité

Une fonctionnalité est à la bonne taille quand elle respecte les cinq règles ci-dessous. Si l'une échoue, découper ou fusionner comme indiqué. Les règles s'appliquent dans l'ordre.

1. **Un résultat observable de l'extérieur.** Les `steps` se rejouent sans lire le code : clic dans un navigateur, appel d'API, commande CLI, requête sur la base. Une fonctionnalité purement technique (schéma, authentification, configuration) est admise seulement si ses `steps` en observent l'effet, par exemple « la table orders existe et accepte une ligne valide ». Si aucune étape observable n'est possible, fusionner avec la première fonctionnalité qui l'utilise.
2. **Une seule phrase de description, sans « et ».** « L'utilisateur crée et modifie une commande » est deux fonctionnalités. Couper à chaque « et » qui relie deux actions.
3. **Entre deux et six `steps`.** Au-delà de six, découper en suivant les étapes : chaque groupe cohérent devient une entrée. Une seule étape signale une entrée trop fine : la fusionner avec sa voisine de même parcours.
4. **Un cas d'erreur a sa propre entrée quand il a son propre comportement visible**, par exemple un message, une redirection ou un code HTTP spécifique. Il est une étape de l'entrée principale quand il se limite à « rien ne se passe ». Priorité : juste après l'entrée du cas nominal.
5. **Aucune dépendance vers une fonctionnalité de priorité plus basse.** Si F-012 ne peut pas passer sans F-030, soit F-030 remonte, soit la partie nécessaire de F-030 est extraite dans une nouvelle entrée placée avant F-012.

### Contrôle global

Après découpage, compter les entrées. Moins de 15 pour un projet de plusieurs sessions signale des fonctionnalités trop grosses : relire la règle 3. Plus de 300 signale un découpage trop fin ou un périmètre trop large : présenter le compte à l'utilisateur avant d'écrire le fichier.

### Ce que ces règles ne font pas

- Elles n'estiment pas le nombre de fichiers ou de lignes : l'initializer ne connaît pas encore le code.
- Elles ne garantissent pas qu'une entrée tienne en une session. Si une session n'arrive pas à la terminer, elle ne la découpe pas elle-même : elle note le blocage dans `claude-progress.md`, et l'humain décide du découpage, puis committe avec `--no-verify`.

## Ordre de priorité

1. Ce qui débloque les autres (squelette, authentification, modèle de données).
2. Le parcours principal de bout en bout, même dépouillé.
3. Les variantes et cas d'erreur du parcours principal.
4. Le reste, par valeur pour l'utilisateur.
