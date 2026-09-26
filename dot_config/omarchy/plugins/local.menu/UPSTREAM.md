# Menu

Cloned from `omarchy.menu`.

Source: `/usr/share/omarchy/shell/plugins/menu`

L'original reste livré avec Omarchy. Supprimer ce dossier suffit à revenir au
menu natif — à condition de repointer les raccourcis (voir plus bas).

## Resynchronisation

Dernière : **2026-08-15**, contre Omarchy `4.0.0.alpha` (`omarchy-dev`
`4.0.0.r1744.gf002044`).

La méthode : recopier `Menu.qml` et `MenuModel.js` depuis le natif, puis
réappliquer les points d'habillage listés ci-dessous. **Ne pas fusionner à la
main** : l'amont réécrit régulièrement la mécanique, et `Menu.qml` +
`MenuModel.js` doivent être repris **ensemble** — le QML appelle des fonctions du
modèle qui changent de nom d'une version à l'autre (`keywordTextMatches` est
devenu `descriptionTextMatches`, `normalizeKeywords` a disparu).

`MenuModel.js` est une copie conforme du natif — aucune personnalisation. Toute
la mécanique (parsing JSONC, providers, gardes `when:`/`checked:`, navigation,
mode dmenu) est celle d'Omarchy à la ligne près.

### Les points d'habillage à réappliquer

Tous dans `Menu.qml`. Objectif : que le menu parle la même langue que la barre.

| Point | Natif | Ici |
|---|---|---|
| Fonte | `Style.font.menuFamily` | `Style.font.family` |
| Palette | `Color.menu.*` | `Color.bar.*` (+ `accent` = `Color.bar.active`) |
| Scrim | `Color.menu.scrim` | inchangé — c'est le voile du bureau |
| Bordures | `borderSpec` / `selectedBorderSpec` | `Border.none()` pour les deux |
| Fond de ligne | `selectedBackground` / transparent | `accentFill` (18 %) / `islandFill` (6 %) |
| Glyphe de ligne | `selectedText` / `foreground`, `iconLarge` | `accent` / `foreground`, `icon` |
| Libellé | `selectedText` sous curseur, `heading` | `foreground` toujours, `body` |
| Chevron | `selectedText`, opacité 0.36 | `accent` / `mutedColor`, opacité pleine |
| Champ de filtre | `foreground` + opacité, `heading` | `foreground` / `mutedColor`, `title` |
| Hauteurs de ligne | 50 / 58 | 38 / 48 |
| `ConfirmDialog` | `selectedBackground` / `selectedText` | `accent` / `background` |

Trois teintes dérivées à redéclarer en tête : `mutedColor`
(`Qt.darker(foreground, 1.4)`), `islandFill` (encre à 6 %), `accentFill`
(accent à 18 %).

### Ce que cette resynchro a rapporté

- Désinstallation d'une application depuis le menu (`requestDeleteSelected`,
  `confirmDelete`, `ConfirmDialog`).
- Providers volatils rechargés à chaud (`invalidateVolatileProvider`,
  `onAppsChanged`, `mergeAppRows`) : la liste des applications suit les
  installations sans rouvrir le menu.
- Système de gardes dans le modèle (`guardScript`, `guardPrelude`,
  `substituteGuardReaders`) : une entrée peut se masquer sur condition.
- Géométrie de défilement revue (`availableRowsHeight`, `foldedListHeight`,
  `freezeCardTop`, `revealCursor`) : le pli en bas de liste se lit comme une
  ligne coupée, et le curseur reste visible au clavier.
- Recherche par description (`descriptionTextMatches`) au lieu des mots-clés.

### Attention

`omarchy.menu` reste le plugin que vise le binaire `omarchy-menu`. Les raccourcis
Hyprland pointent sur `local.menu` (voir `~/.config/hypr/bindings.lua`) ; un
`omarchy menu` tapé à la main ouvre encore le menu natif.

Pour mesurer la dérive avant la prochaine resynchro :

```bash
diff ~/.config/omarchy/plugins/local.menu/Menu.qml \
     /usr/share/omarchy/shell/plugins/menu/Menu.qml
```

Elle doit valoir ~121 lignes — l'habillage et l'en-tête, rien d'autre. Si le
chiffre explose, c'est que l'amont a bougé : resynchroniser plutôt que patcher.
