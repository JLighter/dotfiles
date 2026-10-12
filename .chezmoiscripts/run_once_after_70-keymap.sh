#!/bin/sh
# Aligne la disposition clavier système (console TTY, X11, écran de connexion)
# sur celle de Hyprland : AZERTY fr.
#
# `localectl set-keymap` écrit /etc/vconsole.conf et, par conversion, le
# XkbLayout de /etc/X11/xorg.conf.d/00-keyboard.conf. La variante mac et les
# options (compose, bascule de groupe) restent dans .config/hypr/input.lua :
# elles ne concernent que la session Hyprland.
#
# Sans effet ailleurs que sous systemd : la commande n'y existe pas.
set -eu

KEYMAP="fr"

command -v localectl >/dev/null 2>&1 || exit 0

if grep -qx "KEYMAP=$KEYMAP" /etc/vconsole.conf 2>/dev/null; then
    printf '\033[1;34m::\033[0m Disposition système déjà en %s\n' "$KEYMAP"
    exit 0
fi

printf '\033[1;34m::\033[0m Disposition système : %s\n' "$KEYMAP"
sudo localectl set-keymap "$KEYMAP"
