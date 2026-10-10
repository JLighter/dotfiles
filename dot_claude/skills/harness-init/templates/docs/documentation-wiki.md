# Documentation : wiki de la forge

La documentation vit dans le wiki <GitHub | GitLab> du projet : un dépôt git séparé, `<url-du-dépôt>.wiki.git`. Il n'est pas cloné avec le code et n'est pas relu en PR.

`init.sh` le clone ou le met à jour dans `.wiki/`, ignoré par git.

| Contenu | Page |
|---|---|
| Glossaire | `.wiki/Glossaire.md` |
| Règles métier (`BR-XXX`) | `.wiki/Regles-metier.md` |
| Décisions (`ADR-XXX`) | `.wiki/ADR-XXX-<titre>.md` |

## Lire

`git -C .wiki pull -q`, puis `grep -rn "<identifiant ou terme>" .wiki/`. Les termes du glossaire s'emploient tels quels, sans synonyme.

## Écrire

Commit dans `.wiki/`, puis push : la page change pour toute l'équipe sans revue. Demander confirmation avant chaque push.

## Limite

Le code et sa documentation ne sont pas dans le même commit : une PR peut changer une règle sans que le wiki suive.
