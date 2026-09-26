---
id: EXERCICE-FORMAT
type: reference
status: active
last-updated: 2026-09-26
---

# Format de la spécification JSON

```json
{
  "title": "Nom de l'exercice, 2 à 4 mots",
  "eyebrow": "Sujet · module N · exercice interactif",
  "lede": "Consigne en deux ou trois phrases. HTML autorisé : <strong>, <code>.",
  "rule": [["Mot-clé", "rappel court"], ["...", "..."]],
  "perfect": "Message affiché si tout est juste.",
  "fallback": "Message si aucun biais ne domine.",
  "verdicts": { "nom du biais": "Message si ce biais domine." },
  "questions": [
    {
      "src": "Contexte court affiché en étiquette",
      "q": "La question posée",
      "code": "Énoncé ou extrait, affiché en bloc de code. Chaîne vide si inutile.",
      "opts": [
        { "id": "a", "h": "Titre de l'option", "s": "précision sous le titre" }
      ],
      "ok": ["a"],
      "trap": { "b": "nom du biais" },
      "why": "Réponse, raison, puis pourquoi chaque autre option est fausse."
    }
  ]
}
```

- `ok` : une ou plusieurs réponses acceptées. Plusieurs seulement si l'énoncé permet de les trouver toutes.
- `trap` : sur une mauvaise réponse uniquement. Le nom du biais doit être identique d'un cas à l'autre pour être compté ensemble, et correspondre à une clé de `verdicts`.
- `rule` : trois à cinq rappels affichés en tête, qui donnent les critères sans donner les réponses.
- Le verdict affiché est celui du biais le plus fréquent s'il apparaît au moins deux fois, sinon `fallback`.
- `assets/exemple-spec.json` est une spécification complète de dix cas, à lire avant d'écrire la première.
