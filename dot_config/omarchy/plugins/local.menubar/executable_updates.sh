#!/bin/bash

# Releve des mises a jour en attente, pour le widget Updates de local.menubar.
#
# Sortie TSV, une ligne par paquet :
#   pkg <origine> <nom> <version_installee> <version_disponible>
#
# `checkupdates` synchronise une base temporaire plutot que celle du systeme :
# il n'exige pas les droits root et ne perturbe pas un pacman en cours. Les
# deux commandes touchent le reseau, d'ou un appel espace cote widget.

set -u

# checkupdates et `yay -Qua` sortent tous deux « nom ancienne -> nouvelle ».
if command -v checkupdates >/dev/null 2>&1; then
  checkupdates 2>/dev/null |
    awk 'NF >= 4 { printf "pkg\trepo\t%s\t%s\t%s\n", $1, $2, $4 }'
fi

# Assistant AUR, s'il y en a un. `paru` et `yay` partagent la meme interface.
for helper in paru yay; do
  if command -v "$helper" >/dev/null 2>&1; then
    "$helper" -Qua 2>/dev/null |
      awk 'NF >= 4 { printf "pkg\taur\t%s\t%s\t%s\n", $1, $2, $4 }'
    break
  fi
done
