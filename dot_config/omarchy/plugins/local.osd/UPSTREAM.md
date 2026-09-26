# On-screen display

Cloned from `omarchy.osd`.

Source: `/usr/share/omarchy/shell/plugins/osd`

The original remains built into Omarchy. Remove this plugin directory or swap
your bar entry back to `omarchy.osd` whenever you want to return to the built-in.

## Resynchronisation

Dernière : **2026-08-15**, contre Omarchy `4.0.0.alpha` (`omarchy-dev`
`4.0.0.r1744.gf002044`).

La méthode : recopier `Osd.qml` et `OsdModel.js` depuis le natif, puis
réappliquer la seule personnalisation ci-dessous. Ne pas fusionner à la main —
l'amont refond régulièrement le dimensionnement de la carte, et un merge
conserverait des largeurs mortes.

### La seule personnalisation

`suppressedByBarGauge()` dans `Osd.qml`, appelée en tête de `show()` : le volume
ne s'affiche pas en OSD, la barre `local.menubar` porte déjà sa propre jauge. Le
filtre ne vise que les notifications de niveau (icône `volume-*` **avec** un
pourcentage) ; le changement de périphérique de sortie n'envoie qu'un message et
continue de passer, comme la luminosité, le micro et le touchpad.

`OsdModel.js` est une copie conforme du natif — aucune personnalisation.

### Ce que cette resynchro a rapporté

- Dimensionnement de la carte par colonnes mesurées (`TextMetrics`) au lieu de
  largeurs fixes : le padding reste égal quel que soit le glyphe ou le message.
- Colonne d'icône calée sur l'encre du glyphe et non sur sa chasse, épinglée au
  glyphe le plus large (`widestIcon`) pour que la barre ne saute plus quand
  l'icône change de seuil.
- Nouveaux glyphes `reboot`, `shutdown`, `logout` ; glyphe `touch` corrigé.
- Animation de la barre de progression, et mise à jour de l'état avant ouverture
  pour qu'un OSD neuf démarre à sa valeur.

Pour mesurer la dérive avant la prochaine resynchro :

```bash
diff ~/.config/omarchy/plugins/local.osd/Osd.qml \
     /usr/share/omarchy/shell/plugins/osd/Osd.qml
```

Elle doit valoir 11 lignes — la personnalisation et rien d'autre.
