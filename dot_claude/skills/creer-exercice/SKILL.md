---
name: creer-exercice
description: Produit un exercice interactif sous forme de page web (artifact) : une série de cas, des réponses à choisir, une explication par cas, et un diagnostic qui nomme les biais de l'apprenant. Utiliser pour un exercice de fin de module d'un cours, un quiz de formation pour une équipe, ou un test de compréhension sur un sujet. Mots-clés : exercice, quiz, QCM, cas pratiques, évaluation de formation.
---

# Créer un exercice interactif

Un exercice n'est pas un contrôle de mémoire : il met l'apprenant devant des cas et nomme les biais qui le font se tromper. Le générateur `assets/engine.py` produit la page à partir d'une spécification JSON ; ce skill sert à écrire une bonne spécification.

## Étape 1 : nommer les biais avant d'écrire les cas

Lister deux à cinq erreurs de raisonnement typiques du sujet, chacune en trois à six mots (« classer par sujet au lieu de l'exécutant », « promettre un chiffre »). Ce sont les pièges. Un cas sans piège teste une connaissance ; un cas avec piège teste un raisonnement.

## Étape 2 : écrire les cas

Dix à douze cas. Format et règles dans `references/format-spec.md`. Chaque cas respecte **toutes** les règles de `references/qualite-questions.md` : le relire contre la liste avant de passer au suivant.

Répartition :
- au moins un cas où la bonne réponse est « rien à corriger » ou « c'est correct », pour tester le zèle ;
- au moins un cas où deux réponses sont acceptées, avec une explication qui dit ce qui les distingue ;
- des pièges répartis sur plusieurs cas, pour que le diagnostic puisse compter un biais répété.

## Étape 3 : générer

```bash
python3 assets/engine.py spec.json exercice.html
```

Le générateur refuse une spécification incohérente : réponse attendue absente des options, piège posé sur une bonne réponse, identifiants dupliqués. Puis vérifier que le script de la page s'exécute :

```bash
node -e "const s=require('fs').readFileSync('exercice.html','utf8');const js=s.slice(s.lastIndexOf('<script>')+8,s.lastIndexOf('</script>'));const m={innerHTML:'',querySelectorAll:()=>[],addEventListener(){},focus(){}};new Function('document',js)({getElementById:()=>m});console.log('ok')"
```

## Étape 4 : publier et vérifier le rendu

Publier avec l'outil Artifact. L'exécution du script ne dit rien du rendu : demander à l'apprenant une capture de la première question et du diagnostic, ou regarder la page une fois. Deux défauts d'affichage sont passés inaperçus pendant trois exercices faute de ce contrôle.

## Étape 5 : second exercice

Pour consolider, écrire une seconde spécification sur des cas **inédits**, jamais sur les mêmes cas reformulés. Conseiller de la faire quelques jours après, sans relire les explications.

## Ce que ce skill ne fait pas

- Il ne modifie pas le style de `assets/style.html` sans raison : ce style contient deux correctifs d'affichage (boutons, débordement mobile).
- Il ne note pas l'apprenant : le diagnostic nomme des biais, il ne juge pas une personne.
- Il ne pose pas de question dont la réponse dépend d'une donnée absente de l'énoncé.
