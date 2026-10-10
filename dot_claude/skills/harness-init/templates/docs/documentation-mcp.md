# Documentation : <outil> via MCP

La documentation vit dans <outil>, espace <nom de l'espace>. L'agent la lit par le serveur MCP `<nom>`, déclaré dans `.mcp.json` (portée projet) avec l'URL du serveur officiel de l'outil, vérifiée dans sa documentation.

Chaque développeur approuve ce serveur au premier lancement de Claude Code dans le projet, et s'authentifie une fois (section « Par développeur » du plan). Si l'outil demande un jeton plutôt qu'OAuth, `.mcp.json` le lit par `${<VARIABLE>}` dans `headers`, et chaque développeur définit la variable dans son environnement : la valeur n'est jamais dans le dépôt. Sans jeton, retirer `headers`.

| Contenu | Emplacement dans <outil> |
|---|---|
| Glossaire | <page ou base> |
| Règles métier (`BR-XXX`) | <page ou base> |
| Décisions (`ADR-XXX`) | <page ou base> |

## Lire

Par les outils `mcp__<nom>__*`, en cherchant par identifiant ou par terme. Les termes du glossaire s'emploient tels quels, sans synonyme. Si le serveur ne répond pas, le dire : ne jamais deviner le contenu d'une page.

## Écrire

Une modification change la page pour toute l'équipe, hors revue de code. Demander confirmation avant chaque écriture.

## Limite

Les identifiants ne sont pas trouvables par grep dans le dépôt, et la documentation n'est pas versionnée avec le code.
