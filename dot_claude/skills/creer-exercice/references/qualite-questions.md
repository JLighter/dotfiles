---
id: EXERCICE-QUALITE
type: reference
status: active
last-updated: 2026-09-26
---

# Règles de qualité d'un cas

Chaque règle vient d'une erreur commise puis corrigée pendant le cours de harness engineering de septembre 2026.

## 1. Tout ce qui sert à trancher est dans l'énoncé

Une option ne doit jamais affirmer un fait que l'énoncé ne donne pas. Erreur commise : l'option « un seul trial » acceptée comme juste, alors que l'énoncé ne disait pas combien de trials avaient tourné. Test : quelqu'un qui connaît le sujet et lit attentivement trouve-t-il la réponse sans deviner ?

## 2. Aucune réponse défendable n'est pénalisée

Avant de fixer la réponse attendue, chercher l'argument le plus fort pour chaque autre option. Erreur commise : « Grader modèle » seul accepté pour vérifier des conventions de nommage et de découpage, alors qu'un lint et des fitness functions en couvrent une grande partie. L'apprenant l'a relevé ; il avait raison. Si deux réponses se défendent, soit les accepter toutes les deux, soit réécrire l'énoncé pour qu'une seule tienne.

## 3. Les options répondent toutes à la question posée

Erreur commise : à « Comment noter cette task ? », une option proposait de découper la suite en cinq tasks, ce qui ne note rien. Une option d'une autre nature se repère par élimination et fausse le cas.

## 4. L'explication traite chaque option

Structure : la réponse, sa raison, puis pourquoi chaque autre option est fausse. Une explication qui ne justifie que la bonne réponse ne dit pas à l'apprenant ce qui clochait dans son choix.

## 5. Un libellé se comprend seul

Le titre de l'option dit l'action ou la position ; la ligne sous le titre la précise. Erreur commise : « 4 / 5, avec le critère manqué », incompréhensible hors contexte.

## 6. Les faits techniques sont vérifiés

Un code de sortie, une option d'outil, un comportement de configuration se vérifient dans la documentation avant d'entrer dans un cas. Erreur commise : un hook présenté comme une bonne boucle de retour alors qu'il sortait en code 0 et que l'agent ne voyait jamais sa sortie.

## 7. Le diagnostic couvre toutes les erreurs

Le générateur compte les biais nommés et, à part, les erreurs sans biais nommé. Erreur commise dans une version précédente : trois erreurs sur cinq n'apparaissaient nulle part dans le diagnostic. Si beaucoup d'erreurs restent sans biais, c'est que les pièges ont été mal choisis à l'étape 1.

## 8. Tester le zèle

Un exercice où chaque cas contient un défaut apprend à en voir partout. Inclure un cas correct, et un cas où la bonne décision est de ne rien mécaniser, ne rien supprimer ou ne rien conclure.
