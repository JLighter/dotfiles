#!/bin/sh
# Plugins herdr, dont les keybindings de config.toml dependent :
#   vim-herdr-navigation — ctrl+h/j/k/l, declares en `plugin_action`
#
# Volontairement pas `run_once`, contrairement aux autres scripts d'installation.
# Un plugin peut disparaitre du lock (mise a jour de herdr, reinstallation) et
# les touches qui pointent dessus deviennent alors muettes : la config reste
# valide, herdr capte bien la touche, mais l'action n'existe plus. Rejoue a
# chaque apply, ce script repose ce qui manque.
set -eu

log() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

# Le meme depot sert aux deux OS : le plugin declare linux et macos.
command -v herdr >/dev/null 2>&1 || { log "herdr absent, plugins ignores"; exit 0; }

install_if_missing() {
    if herdr plugin list 2>/dev/null | grep -q "^- $2 "; then
        log "$2 deja present"
    else
        log "Installation de $2"
        # Une panne reseau ne doit pas faire echouer tout le `chezmoi apply` :
        # le reste des dotfiles se pose tres bien sans les plugins.
        herdr plugin install "$1" --yes || log "$2 : installation echouee, a rejouer"
    fi
}

install_if_missing paulbkim-dev/vim-herdr-navigation vim-herdr-navigation
