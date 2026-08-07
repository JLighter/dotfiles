#!/bin/sh
# Plugins tmux. Deux emplacements distincts, voulus par le .tmux.conf :
#   ~/.tmux/plugins/tpm             — tpm, chargé en dernière ligne du conf
#   ~/.config/tmux/plugins/catppuccin — chargé à la main (`run`), pas par tpm
# Sans le second, tmux affiche une erreur à chaque démarrage.
set -eu

log() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

clone_if_missing() {
    if [ -d "$2" ]; then
        log "$(basename "$2") déjà présent"
    else
        log "Clone de $(basename "$2")"
        git clone --depth=1 "$1" "$2"
    fi
}

clone_if_missing https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
clone_if_missing https://github.com/catppuccin/tmux "$HOME/.config/tmux/plugins/catppuccin"

log "Lancer <C-space> I dans tmux pour installer les plugins restants"
