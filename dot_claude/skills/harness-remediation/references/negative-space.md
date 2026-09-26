---
id: REMEDIATION-NEGATIVE-SPACE
type: reference
status: active
last-updated: 2026-09-26
---

# Ce qu'un changement de harness ne doit pas casser

À écrire avant de tester, pour chaque recommandation. Exemples par type de mécanisme.

| Mécanisme ajouté | Vérifier qu'il bloque | Vérifier qu'il ne bloque pas |
|---|---|---|
| Deny sur un chemin de secret | la lecture du fichier visé | la lecture des fichiers voisins utiles au travail |
| Pre-commit de détection de secrets | un commit avec un faux jeton | un commit ordinaire ; un fichier de test contenant le mot « token » |
| Hook PostToolUse de formatage conditionnel | le reformatage d'un fichier non conforme | le formatage d'un fichier nouveau ou déjà conforme |
| Hook PostToolUse de vérification | l'édition qui introduit une erreur (exit 2, stderr visible) | une édition correcte (exit 0, aucune sortie) |
| Hook Stop | la fin de tour avec des tests rouges | la fin de tour avec des tests verts ; la sortie de la garde après N relances |
| Retrait d'une règle d'instruction | — | le comportement mesuré sur les tâches témoins |
| Changement de `autoMode` | l'action risquée dans un dépôt non déclaré | le travail ordinaire dans le dépôt de travail |

Un mécanisme qui bloque trop est désactivé par l'humain dans la semaine : le negative space protège autant le harness que ce qu'il surveille.
