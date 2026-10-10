# Documentation : Markdown dans le dépôt

La documentation vit dans `docs/`, versionnée avec le code, relue en PR, reçue par chaque `git clone`.

| Contenu | Emplacement |
|---|---|
| Glossaire | `docs/domain/glossary.md` |
| Règles métier (`BR-XXX`) | `docs/domain/business-rules.md` |
| Décisions (`ADR-XXX`) | `docs/architecture/decisions/` |
| Guides | `docs/guides/` |

Un fichier absent n'est pas une erreur : il naît avec le premier terme, la première règle ou la première décision tranchés.

## Lire

Avant de travailler dans une zone : `grep -rn "<identifiant ou terme>" docs/`. Les termes du glossaire s'emploient tels quels, sans synonyme.

## Écrire

Dans la même PR que le code qui en dépend. Une contradiction avec une ADR existante se signale explicitement, elle ne s'écrase pas.

## Publication

<Aucune | Docusaurus (`docusaurus.config.*`) | MkDocs (`mkdocs.yml`) | Read the Docs (`.readthedocs.yaml`)>. La source reste le Markdown de `docs/` ; le site ne s'édite jamais directement.
