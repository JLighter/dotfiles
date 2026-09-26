---
name: creer-cours
description: Construit un cours progressif sur un sujet donné, module par module, publié comme une page web (artifact) avec un exercice interactif par module. Utiliser quand l'utilisateur veut apprendre ou maîtriser un sujet, demande un cours, une formation, un parcours d'apprentissage, ou veut transformer un sujet en modules et exercices pour lui ou pour une équipe. Ne pas utiliser pour une explication ponctuelle qui tient en une réponse.
---

# Créer un cours

Un cours est livré en modules, un à la fois, dans une page web qui grandit. Chaque module se termine par un exercice interactif produit avec le skill `creer-exercice`. La méthode vient d'un cours de sept modules mené en septembre 2026 ; `references/methode.md` en donne les raisons et les erreurs à ne pas refaire.

## Étape 1 : vérifier le sujet avant d'écrire

1. Chercher les sources primaires du sujet : qui a forgé ou popularisé le terme, quand, avec quelle définition. Lire les textes eux-mêmes, pas seulement leurs résumés.
2. Noter pour chaque source : auteur, titre, date, URL, et ce qui en est tiré.
3. Toute source qui n'a pas pu être lue est signalée comme telle dans la page, jamais citée de mémoire.
4. Si le sujet a moins de deux ans, dater chaque affirmation : le vocabulaire bouge.

## Étape 2 : connaître l'apprenant

Avec AskUserQuestion, en un seul lot : son métier et ce qu'il fera du cours, son niveau de départ, le format de livraison préféré (page, conversation, les deux). Chercher un **fil rouge** : un objet réel de l'apprenant (sa configuration, son code, son projet) qui servira d'exemple dans chaque module. Un cours sur son propre cas s'apprend deux fois plus vite qu'un cours sur un cas inventé.

## Étape 3 : le plan

Cinq à sept modules. Pour chacun : titre, notions, exercice prévu. Le dernier module applique tout au métier de l'apprenant (mission, projet, audit). Présenter le plan, puis livrer le module 1 sans attendre une validation formelle du plan.

## Étape 4 : la page

Partir de `assets/cours-template.html`. Elle contient le style et les composants documentés en commentaire. Publier avec l'outil Artifact, puis mettre à jour **la même page** à chaque module : l'adresse ne change pas, et l'apprenant la partage s'il le souhaite.

## Étape 5 : un module

Structure : les notions (texte court, un tableau quand il y a une comparaison), un encadré d'application au métier de l'apprenant, un exercice. Règles :

- Chaque affirmation factuelle vient d'une source de l'étape 1 ou est marquée comme synthèse personnelle.
- Avant d'écrire un fait technique précis (une option, un code de sortie, un comportement d'outil), le vérifier dans la documentation officielle. Une erreur publiée dans un cours se transmet à l'apprenant.
- Quand une erreur est découverte après publication, la corriger et l'annoncer dans un encadré « Correction » au module suivant. L'apprenant doit savoir ce qu'il a appris de faux.
- L'exercice est produit avec le skill `creer-exercice`, puis lié depuis l'encadré du module.

## Étape 6 : les retours de l'apprenant

- Un score d'exercice se lit par ses erreurs, pas par son total. Demander la page « Revoir les erreurs » si le détail manque.
- Quand l'apprenant conteste une réponse, examiner l'argument sur le fond. S'il a raison, corriger l'exercice et le dire.
- Si l'apprenant demande de faire lui-même une partie laissée à sa contribution, la faire.

## Étape 7 : consolider

- Après chaque module : un second exercice sur des cas inédits, à faire quelques jours plus tard sans relire les explications. Un second essai sur les mêmes cas mesure la mémoire, pas la compréhension.
- En fin de cours, un exercice terrain : utiliser pour de vrai l'outil ou la méthode construits pendant le cours.

## Étape 8 : la progression entre sessions

Tenir à jour un fichier de mémoire du projet : modules livrés, adresses des pages, scores, biais observés chez l'apprenant, exercice en attente. Un cours dure plusieurs sessions : sans ce fichier, la session suivante recommence à zéro.

## Ce que ce skill ne fait pas

- Il ne livre pas tout le cours d'un coup : un module à la fois, avec son exercice.
- Il n'évalue pas la compétence de l'apprenant : il rapporte des scores et des biais, l'apprenant en tire ses conclusions.
- Il ne cite pas une source qu'il n'a pas lue.
