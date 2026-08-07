#!/bin/sh
# Applique RobotoMono Nerd Font à l'ensemble du système Omarchy.
#
# `omarchy font set` propage la famille à waybar, swayosd, hyprlock, foot,
# alacritty, kitty et à la règle monospace de fontconfig — donc à toutes les
# applications qui suivent la police système, Steam compris.
#
# Ghostty n'est volontairement pas concerné : le motif sed d'Omarchy exige des
# guillemets que notre config n'a pas, et elle déclare ses quatre graisses
# explicitement là où Omarchy ne pose qu'une famille.
#
# Sans effet ailleurs que sur Omarchy : la commande n'y existe pas.
set -eu

FONT="RobotoMono Nerd Font"

command -v omarchy-font-set >/dev/null 2>&1 || exit 0

if ! fc-list | grep -qi "$FONT"; then
    printf '\033[1;33m..\033[0m %s introuvable, police système inchangée\n' "$FONT" >&2
    printf '   Installer avec : sudo pacman -S ttf-roboto-mono-nerd\n' >&2
    exit 0
fi

printf '\033[1;34m::\033[0m Police système : %s\n' "$FONT"
omarchy font set "$FONT"
