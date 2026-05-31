#!/usr/bin/env bash
# Personnalise les marqueurs de débordement de la liste de fenêtres dans la
# status bar tmux. Par défaut tmux affiche `<` / `>` (list-left-marker /
# list-right-marker) quand des fenêtres dépassent à gauche/droite hors écran.
# On les remplace par des flèches Nerd Font ( / ).
#
# Subtilité : ni tmux ni Catppuccin ne matérialisent `status-format` — tmux
# utilise un format par défaut INTERNE, que `show -gv status-format[0]` renvoie
# vide. On ne peut donc pas patcher une valeur inexistante. Ce script :
#   1. récupère le format par défaut depuis un serveur tmux vierge (socket isolé,
#      sans config) ;
#   2. y remplace les marqueurs par les flèches ;
#   3. l'affecte explicitement à status-format[0].
#
# Appelé depuis .tmux.conf APRÈS le chargement de Catppuccin. Idempotent.
#
# Réversible : `tmux set -gu 'status-format[0]'` rend la main au défaut tmux.

set -euo pipefail

# Glyphes Nerd Font depuis leurs octets UTF-8 (en dur, indépendant de l'encodage
# d'arguments / de la saisie) : U+F0D9 () = gauche, U+F0DA () = droite.
left=$(printf '\xef\x83\x99')
right=$(printf '\xef\x83\x9a')

# Récupère le status-format par défaut depuis un serveur tmux jetable et vierge,
# pour ne pas dépendre d'un format déjà patché ou vidé dans la session courante.
sock="_markers_$$"
tmux -L "$sock" -f /dev/null new-session -d 2>/dev/null
default_fmt=$(tmux -L "$sock" show -gv 'status-format[0]')
tmux -L "$sock" kill-server 2>/dev/null || true

[ -n "$default_fmt" ] || { echo "format par défaut introuvable" >&2; exit 1; }

# Remplace le marqueur (le caractère qui suit #[list=*-marker] EST le marqueur).
patched=$(printf '%s' "$default_fmt" \
  | sed -e "s/\(list=left-marker]\)<\{0,1\}/\1${left}/g" \
        -e "s/\(list=right-marker]\)>\{0,1\}/\1${right}/g")

tmux set -g 'status-format[0]' "$patched"
