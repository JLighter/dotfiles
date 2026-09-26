---
name: reprise
description: Protocole de session d'un projet long initialisé par l'initializer (features.json et claude-progress.md à la racine). Utiliser au début de chaque session pour reprendre le travail, quand l'utilisateur dit reprendre, continuer, passer à la suite ou fonctionnalité suivante, et avant de terminer une session pour la clôturer. Ne pas utiliser dans un projet sans features.json.
---

# Reprise

Une session de ce projet traite **une seule fonctionnalité**, la termine ou note pourquoi elle ne l'est pas, et laisse le dépôt dans un état dont la session suivante peut repartir sans rien savoir de celle-ci.

## Ouverture

1. **Lire l'état.** Le hook SessionStart l'a normalement injecté : avancement, prochaine fonctionnalité, dernière session, derniers commits. S'il manque, lire `claude-progress.md` (bloc le plus récent), `git log --oneline -10`, puis `features.json`.
2. **Remettre l'environnement.** Lancer `./init.sh`. S'il échoue, la session sert à le réparer, et à rien d'autre.
3. **Vérifier la base.** Rejouer les `steps` des deux dernières fonctionnalités passées à `true`. Si l'une échoue, la repasser à `false`, et c'est elle que la session traite.
4. **Choisir.** Sinon, prendre la fonctionnalité à `passes: false` de plus petite `priority`. Si le dernier bloc de progression nomme un point de reprise, repartir de là.
5. **Annoncer** en une ligne à l'utilisateur : fonctionnalité choisie, son `id`, et pourquoi elle.

## Travail

- Une seule fonctionnalité. Si une autre est nécessaire en chemin, s'arrêter et la noter comme blocage plutôt que l'implémenter en passant.
- Committer à chaque étape stable, avec l'`id` dans le message : `feat(F-012): pagination de la liste des commandes`.

## Clôture

Déclenchée quand la fonctionnalité est terminée, quand la fenêtre de contexte approche de sa limite, ou quand l'utilisateur arrête.

1. **Vérifier comme un évaluateur.** Rejouer chaque étape de `steps` de l'extérieur : navigateur, appel d'API, commande. Pas de lecture du code à la place. `passes: true` seulement si toutes passent.
2. **Mettre à jour `features.json`** : uniquement le champ `passes`. Le pre-commit refuse tout autre changement.
3. **Écrire le bloc de session** en tête de `claude-progress.md`, au-dessus du précédent :

   ```
   ## Session <n> — <date> — <id>
   - Fait : <ce qui marche maintenant, vérifié>
   - Décisions : <choix et raison, une ligne chacun>
   - Blocages : <ce qui empêche d'avancer, ou « aucun »>
   - Reprise : <id> — <fichier:ligne ou prochaine action exacte>
   ```

4. **Committer** l'état final, message `chore(<id>): clôture de session <n>`.

## Ce que ce skill ne fait pas

- Il ne modifie pas une fonctionnalité de la liste, ne la découpe pas, n'en ajoute pas. Une fonctionnalité trop grosse pour une session est notée en blocage, et l'humain redécoupe.
- Il ne passe pas `passes` à `true` sur la foi de tests unitaires seuls : ce sont les `steps` qui font foi.
- Il ne recopie pas la délibération dans le bloc de session : décisions et raisons seulement.
