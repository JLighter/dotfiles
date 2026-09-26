---
id: COURS-METHODE
type: reference
status: active
last-updated: 2026-09-26
---

# Pourquoi la méthode est ainsi

Chaque règle du skill vient d'un fait observé pendant le cours de harness engineering de septembre 2026 (7 modules, 13 exercices).

## Vérifier avant d'écrire

Le terme « harness engineering » avait moins d'un an. Une définition de mémoire aurait été datée ou fausse. La recherche initiale a trouvé les textes fondateurs (Anthropic nov. 2025 et mars 2026, HumanLayer mars 2026, OpenAI août 2026) et une page inaccessible, signalée comme telle dans les sources.

Au module 5, la lecture de la documentation des hooks a révélé qu'un exemple publié au module 1 était faux : un hook en `exit 0` que l'agent ne voit jamais, présenté comme une bonne boucle. Correction : vérifier le fait technique avant de l'écrire, et annoncer la correction quand elle arrive après.

## Le fil rouge

L'apprenant avait un CLAUDE.md de 250 lignes. Le module 1 l'a fait classer par couche ; le module 2 l'a fait trier ; le module 7 a cité ses propres limites. Chaque notion s'est accrochée à un objet qu'il connaissait déjà, et l'exercice 1 a révélé son biais principal (classer par sujet au lieu de classer par exécutant) sur son propre texte.

## Un module à la fois, dans une page

L'apprenant a demandé la page après le module 1, puis a demandé que les modules y soient écrits directement. La page est devenue l'artefact de transfert du cours entre sessions, et un support partageable.

## Contribution de l'apprenant

Les parties à jugement (critères d'une grille, règles de découpage) ont été proposées à l'apprenant. Il en a rédigé une en trois passes, chaque relecture portant sur un seul critère : chaque ligne doit nommer une preuve vérifiable. Deux fois, il a demandé que la partie soit écrite pour lui : c'est son choix, pas un échec de la méthode.

## Construire un outil réel

Le cours a produit trois skills utilisables (audit, initialisation de projet long, reprise). Un cours qui se termine par un outil que l'apprenant installe et utilise se transfère mieux qu'un cours qui se termine par un quiz.

## Les exercices

Voir le skill `creer-exercice`, fichier `references/qualite-questions.md`. Les erreurs de conception qui y sont listées ont toutes été commises puis corrigées pendant ce cours.
