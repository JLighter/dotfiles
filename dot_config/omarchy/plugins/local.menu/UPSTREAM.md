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

### Couche 1 — les points d'habillage à réappliquer

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

### Couche 2 — la forme Raycast

Ajoutée le 2026-08-29, par-dessus la couche 1 et sans toucher à `MenuModel.js`.
Le moteur amont faisait déjà l'essentiel — recherche globale scorée sur tout
l'arbre (`searchScore`), sous-titres, sections `ViewSection`, icônes d'apps —
et seule la présentation manquait.

| Point | Avant | Ici |
|---|---|---|
| Largeur de carte | `Style.space(300)`, 520 pour deux routes | `Style.space(560)` pour toutes |
| En-tête | un `Text` : titre du menu, puis texte tapé | loupe + fil d'Ariane en pastille + saisie + caret |
| Titre du menu courant | placeholder de l'en-tête | pastille `crumb`, à gauche de la saisie |
| Échelle de la saisie | `title` | `heading` |
| Chemin d'un résultat | sous-titre, ligne doublée à 48 | colonne de droite, ligne simple |
| Sous-titre sous le libellé | recherche **et** dmenu | dmenu seul |
| Frontière de recherche | filet anonyme (`section === "drilldown"`) | bandeau nommé, via `sectionFor()` |
| Pied de carte | absent | rappels clavier + compteur de résultats |
| Fond de carte | `background` opaque | `cardOpacity` = 0.92 |
| Ombre | aucune | `MultiEffect`, piloté par `cardShadow` |
| Ouverture | instantanée | fondu + montée de 96 % |

Trois interrupteurs en tête de fichier pour revenir en arrière sans défaire le
reste : `cardShadow` (à couper en premier si le texte paraît moins net — le
`layer.enabled` qu'elle impose supprime l'anti-aliasing sous-pixel),
`cardOpacity` (à 1.0 la carte redevient pleine et la `layer_rule` de blur n'a
plus de prise) et `showFooter`.

Deux dépendances hors du plugin :

- `~/.config/hypr/looknfeel.lua` porte la `layer_rule` `blur-omarchy-menu`, dont
  le `ignore_alpha = 0.6` passe entre le voile de fond (0.5) et la carte (0.92).
  Changer `cardOpacity` sous ce seuil supprime le flou.
- `~/.config/hypr/bindings.lua` pointe les raccourcis sur `local.menu`.

`sectionFor(row, atCurrentLevel)` est le seul point ouvert : elle ne fait pour
l'instant que renommer le filet du clone. Toute règle plus fine doit trier les
lignes dans le même mouvement — `ListView` ne regroupe que les lignes
consécutives de même valeur.

### Couche 3 — repli temporaire de la bibliothèque d'apps

Ajoutée le 2026-10-18, contre Omarchy `4.0.5`. À retirer dès que l'amont
corrige le bug.

Omarchy 4.0.4 et 4.0.5 donnent `appLibrary: null` aux menus tiers :
`manifestHasKind` teste `Array.isArray(manifest.kinds)`, faux pour un manifeste
passé par le modèle des panneaux (omacom/omarchy#15360, #14761, #15851). La liste
Apps reste alors vide. Le menu natif n'est pas touché : il reçoit le vrai
`shell`.

| Point | Natif | Ici |
|---|---|---|
| `appLibrary` | `root.shell.appLibrary` | celui de l'hôte, sinon la copie locale chargée par `localAppLibrary` |
| `AppLibrary.qml`, `AppSearch.js` | `shell/services/` de l'hôte | copies conformes de la 4.0.5, sans retouche |

Le `Loader` s'active dès que l'hôte ne fournit rien. Il ne doit pas attendre
l'injection de `shell` : constaté sous 4.0.5, `shell` vaut encore `null` quand
le menu s'ouvre, et la liste resterait vide. Une fois le correctif amont
installé (PR omacom/omarchy#15692), la copie n'est plus chargée dès que `shell`
porte la bibliothèque de l'hôte.

`tests/omarchy-menu-applibrary.test.sh` surveille la couche : il échoue si une
mise à jour d'Omarchy change `AppLibrary.qml` ou `AppSearch.js` (les recopier),
ou si l'hôte est corrigé (`shell.qml` n'appelle plus `Array.isArray(manifest.kinds)`
et passe par `Util.manifestHasKind`) — c'est le signal de retrait.

Pour retirer la couche, dans `Menu.qml` :

1. supprimer le `Loader { id: localAppLibrary … }` et la propriété
   `hostAppLibrary` ;
2. rétablir `readonly property var appLibrary: root.shell ? root.shell.appLibrary : null` ;
3. supprimer `AppLibrary.qml`, `AppSearch.js` et
   `tests/omarchy-menu-applibrary.test.sh`.

Supprimer les copies sans le `Loader` casse tout le menu : le type
`AppLibrary` n'existerait plus.

Pour vérifier à l'exécution, ouvrir d'abord le sous-menu Apps (les lignes ne
sont fusionnées qu'à ce moment), puis comparer une entrée visible à une entrée
masquée. `item` renvoie `[object Object]` pour une ligne existante, `ok` sinon :

```bash
omarchy-shell shell call local.menu item apps.chromium                      # [object Object]
omarchy-shell shell call local.menu item apps.nautilus-autorun-software     # ok (NoDisplay)
```

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

Elle doit valoir ~500 lignes — les deux couches d'habillage et l'en-tête, rien
d'autre (~121 pour la seule couche 1, avant la forme Raycast). Si le chiffre
explose, c'est que l'amont a bougé : resynchroniser plutôt que patcher.

Le prix de la couche 2 est là : la resynchro coûte désormais deux passes de
réapplication au lieu d'une. Faire la couche 1 d'abord, vérifier que le menu
s'ouvre, puis la couche 2 — elles sont indépendantes.
