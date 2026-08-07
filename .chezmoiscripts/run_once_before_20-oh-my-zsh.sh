#!/bin/sh
# oh-my-zsh et les trois plugins qui ne s'installent pas via le gestionnaire de
# plugins. Joué en `before` : chezmoi écrit ~/.zshrc juste après, donc la
# version d'oh-my-zsh ne peut pas gagner la course.
set -eu

log() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

OMZ="$HOME/.oh-my-zsh"

if [ -d "$OMZ" ]; then
    log "oh-my-zsh déjà présent"
else
    log "Installation d'oh-my-zsh"
    # KEEP_ZSHRC : ne pas générer de .zshrc, c'est chezmoi qui le fournit.
    # RUNZSH/CHSH : pas de shell interactif ni de chsh ici (cf. script 40).
    KEEP_ZSHRC=yes RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

CUSTOM="${ZSH_CUSTOM:-$OMZ/custom}"
for plugin in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
    if [ -d "$CUSTOM/plugins/$plugin" ]; then
        log "$plugin déjà présent"
    else
        log "Clone de $plugin"
        git clone --depth=1 "https://github.com/zsh-users/$plugin" \
            "$CUSTOM/plugins/$plugin"
    fi
done
