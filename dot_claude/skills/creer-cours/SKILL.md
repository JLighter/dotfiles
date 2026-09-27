---
name: creer-cours
description: Construit un cours progressif sur un sujet donné, en parties et chapitres courts écrits pour qu'on puisse partir de zéro (style Site du Zéro), avec un QCM par chapitre, des TP réguliers, et chaque affirmation étiquetée selon ce qui la soutient. Utiliser quand l'utilisateur veut apprendre ou maîtriser un sujet, demande un cours, une formation, un tutoriel, un parcours d'apprentissage, ou veut transformer un sujet en chapitres et exercices pour lui ou pour une équipe. Ne pas utiliser pour une explication ponctuelle qui tient en une réponse.
---

# Créer un cours

Un cours est livré chapitre par chapitre, dans des pages web qui grandissent. Deux références encadrent l'écriture :
- `references/style-zero.md` : la manière d'écrire et de structurer. Chapitres courts, un concept à la fois, analogies, encadrés, résumés, TP.
- `references/methode.md` : pourquoi chaque règle existe, et les erreurs à ne pas refaire.

## Étape 1 : vérifier le sujet avant d'écrire

1. Chercher les sources primaires : qui a forgé ou popularisé le terme, quand, avec quelle définition. Lire les textes eux-mêmes, pas leurs résumés ; archiver le texte brut lu.
2. Tenir un registre des sources : identifiant (SRC-xx), auteur, **affiliation** (qui l'emploie ou le paie), date, URL, accès (lu, résumé seul, inaccessible), nature (documentation, étude, praticien, théorie).
3. Une source non lue est signalée comme telle, jamais citée de mémoire.
4. Chercher les **filiations** : de quelle idée plus ancienne vient chaque notion. Le domaine d'origine a souvent déjà trouvé ses limites.
5. Si le sujet a moins de deux ans, dater chaque affirmation : le vocabulaire bouge.

## Étape 2 : connaître l'apprenant

Avec AskUserQuestion, en un seul lot : son métier et ce qu'il fera du cours, son niveau de départ, tutoiement ou vouvoiement, format de livraison. Chercher un **fil rouge** : un objet réel de l'apprenant (sa configuration, son code, son projet) qui servira d'exemple dans chaque chapitre.

## Étape 3 : le plan

Des parties de trois à six chapitres. Pour chaque chapitre : un seul concept, ses prérequis, son QCM. Un TP toutes les deux ou trois leçons. La dernière partie applique tout au métier de l'apprenant. Présenter le plan, puis livrer le premier chapitre sans attendre une validation formelle.

## Étape 4 : les pages

Partir de `assets/cours-template.html`, ou du site de cours quand il existe. Mettre à jour **la même adresse** à chaque chapitre : l'apprenant garde son lien.

## Étape 5 : un chapitre

Suivre le déroulé de `references/style-zero.md` : problème concret, analogie avec sa limite, notion, exemple, pièges, « En résumé », QCM.

**Étiqueter chaque affirmation** selon ce qui la soutient :

| Étiquette | Quand |
|---|---|
| Donnée vérifiable | comportement documenté que chacun peut reproduire |
| Fait scientifique | résultat d'une étude avec mesure et protocole publiés |
| Pratique établie | portée par des décennies d'usage collectif, sans preuve décisive |
| Pratique émergente | au moins deux sources indépendantes : ni l'une citant l'autre, ni le même employeur |
| Opinion de praticien | une seule source, ou un retour d'expérience non mesuré |
| Synthèse du cours | construction propre au cours |

En cas de doute, l'étiquette la plus faible. Quand deux sources s'opposent, montrer la tension sans la trancher. Une analogie n'a pas d'étiquette : elle aide, elle ne prouve rien.

Avant d'écrire un fait technique précis (une option, un code de sortie, un comportement d'outil), le vérifier dans la documentation officielle.

## Étape 6 : vérification indépendante avant publication

Chaque passe de rédaction déforme les sources, et toujours dans le même sens : vers plus de certitude. Une nuance tombe (« peut », « en moyenne », « le plus souvent »), une attribution glisse, une condition disparaît. L'auteur ne voit pas ses propres déformations.

1. Extraire chaque affirmation du chapitre avec son étiquette et sa source.
2. La faire vérifier par un sous-agent qui ne reçoit que les affirmations, le registre des sources et les textes bruts, sans la conversation. Il cite le texte exact en cas d'écart.
3. Corriger, puis faire revérifier ce qui a été corrigé : les corrections introduisent aussi des déformations.
4. Contrôler la page par script : chaque étiquette renvoie à une source existante, aucune ancre cassée. Une section perdue pendant une modification se voit à une ancre manquante.

Ni l'auteur ni le sous-agent ne déclarent le chapitre « correct » : l'apprenant ou le relecteur humain valide.

Quand une erreur est découverte après publication, la corriger et l'annoncer dans un encadré « Correction » : l'apprenant doit savoir ce qu'il a appris de faux.

## Étape 7 : les retours de l'apprenant

- Un score se lit par ses erreurs, pas par son total. Demander la page « Revoir les erreurs » si le détail manque.
- Quand l'apprenant conteste une réponse, examiner l'argument sur le fond. S'il a raison, corriger et le dire.
- Si l'apprenant demande de faire lui-même une partie laissée à sa contribution, la faire.

## Étape 8 : consolider

- Après chaque partie : un second exercice sur des cas inédits, à faire quelques jours plus tard sans relire. Un second essai sur les mêmes cas mesure la mémoire, pas la compréhension.
- En fin de cours, un TP terrain : utiliser pour de vrai l'outil ou la méthode construits pendant le cours.

## Étape 9 : la progression entre sessions

Tenir à jour un fichier de mémoire du projet : chapitres livrés, adresses, scores, biais observés, exercice en attente, fichiers de travail (registre des sources, affirmations).

## Ce que ce skill ne fait pas

- Il ne livre pas tout le cours d'un coup : un chapitre à la fois, avec son QCM.
- Il n'évalue pas la compétence de l'apprenant : il rapporte des scores et des biais.
- Il ne cite pas une source qu'il n'a pas lue, et ne présente pas une opinion comme un fait.
- Il ne sacrifie pas l'exactitude au ton : une simplification est annoncée et levée plus loin.
