# local.notifications

Deux choses dans un seul plugin `service` :

1. **Les toasts**, rendus aux couleurs de `local.menubar` en interceptant le
   modele du service natif (`Service.qml`).
2. **L'archive**, un historique persistant de tout ce qui a ete recu
   (`Archive.qml` + `bin/notification-archive`), que la cloche de la barre
   affiche en panneau.

La cloche et son panneau vivent dans `local.menubar/Notifications.qml` ; ce
plugin-ci ne fait que tenir les donnees.

## Pourquoi une archive

Le service natif ecrit deja chaque notification sur disque, sous
`~/.local/state/omarchy/notifications/`, et deplace le fichier dans `history/`
quand le toast quitte l'ecran. Mais il n'en garde que **dix** : le onzieme est
supprime, avec l'icone conservee pour lui. Dix, c'est le bon compte pour
`showRecentHistory()`, dont le metier est de rejouer ce qu'on vient de manquer.
C'est tres loin du compte pour repondre a « c'etait quoi, deja », dix minutes
plus tard, au milieu d'autre chose.

`bin/notification-archive` recopie donc chaque fichier des qu'il apparait, et le
garde trente jours. Rien n'ecrit dans les repertoires du service : on les lit.

## Pourquoi depuis le disque et non depuis `popupModel`

`Service.qml` intercepte deja `popupModel` pour peindre ses propres toasts —
l'archive aurait pu se brancher la. Deux raisons de ne pas le faire :

- Une notification recue en **« ne pas deranger » n'entre jamais dans
  `popupModel`** : `handleNotification()` appelle `writeSilenced()` puis
  retourne. Elle n'existe que sur disque. Or « qu'est-ce que j'ai rate pendant
  que c'etait silencieux » est exactement la question a laquelle un centre de
  notifications existe pour repondre.
- Le format sur disque est un contrat stable. Le rendu des toasts paie deja une
  fragilite envers `popupModel`, `liveRefs` et `archivePopupFileFor` ; autant ne
  pas la payer deux fois.

## Ce qui n'est jamais garde

Une notification arrive porteuse d'une commande shell, dans le hint
`omarchy-exec-argv`, **choisie par celui qui l'envoie** — et n'importe quel
process du bus de session peut en envoyer une. Le commentaire de
`NotificationLogic.parseExecArgv()` en amont le dit sans detour : c'est
« equivalent to same-uid code execution ».

Cette commande n'est donc jamais stockee. Ce qui l'est, c'est au plus un
**chemin absolu vers une image** extrait de l'action par liste blanche, ouvert
par argument et non a travers un shell. Un chemin hostile est un fichier qui
refuse de s'ouvrir, pas une commande qui s'execute. La regle est ecrite deux
fois — a l'ingestion dans le script, a l'activation dans le panneau — pour que
si l'une se relache, l'autre tienne.

Les icones sont recopiees seulement apres controle du type MIME reel : une
notification dont l'`appIcon` designerait `~/.ssh/id_rsa` n'en fait pas une
seconde copie ici.

## Ou c'est garde

`~/.local/state/omarchy-notifications-archive/` : une ligne de JSON par
notification, plus une copie de chaque icone et de chaque image. Le repertoire
est en `0700`, l'archive en `0600`.

A savoir pour une raison : **c'est tout ce qu'on a recu**, messages de
conversation et codes a usage unique compris. Rien ne quitte la machine, mais ce
n'est pas quelque chose a synchroniser ou a sauvegarder a la legere.
`keepDays` est le reglage qui limite les degats, et **un jour** est une reponse
parfaitement raisonnable.

Desinstaller le plugin laisse l'archive en place, volontairement :

```bash
rm -rf ~/.local/state/omarchy-notifications-archive
```

## La ligne de commande

`bin/notification-archive` est le magasin, et la facon de chercher plus loin que
ce que le panneau charge :

```
watch              suit le service et archive ce qu'il recoit
sync               rattrape ce qui n'est pas encore archive
list [LIMITE]      l'archive en JSON, du plus recent au plus ancien
remove CLE         en retire une
clear              les retire toutes
seen [MS]          lit ou pose la date de derniere ouverture
unread             combien depuis
seed [N]           remplit d'un trafic d'essai
backfill           donne aux anciennes entrees l'image que leur action designe
prune              applique les limites de retention maintenant
```

Tout sort en JSON, y compris les echecs — pour que rien de ce qui rate n'atteigne
le panneau sous la forme d'une erreur de parsing.

```bash
# tout ce que Slack a envoye la semaine derniere, en texte
~/.config/omarchy/plugins/local.notifications/bin/notification-archive list 2000 \
  | jq -r '.[] | select(.app == "Slack") | "\(.summary): \(.body)"'
```

## Verifier sans regarder

```bash
omarchy-shell local.notifications.archive state      # entrees, non-lus, watcher vivant
omarchy-shell local.notifications.archive seed 25    # trafic d'essai
omarchy-shell local.notifications.archive clear
omarchy-shell menubar.notifications toggle           # ouvrir le panneau
```

## Dependances

`jq` et `inotifywait`, tous deux deja presents sur Omarchy. `magick`
(ImageMagick) est optionnel : il sert a redimensionner les apercus a la taille
du panneau ; sans lui la copie est gardee telle quelle.
