#!/bin/sh
# herdr et ce qu'il pose hors du depot. Plugins : config.toml declare en
# `plugin_action` les touches de deux d'entre eux :
#   vim-herdr-navigation — ctrl+h/j/k/l
#   herdr-spawn          — prefix+enter, lanceur d'agent
# herdr.auto-title (titre des onglets) et hunk.diff (diffs, demande `hunk`)
# n'ont pas de touche mais font partie de l'environnement.
#
# Volontairement pas `run_once`, contrairement aux autres scripts d'installation.
# Un plugin peut disparaitre du lock (mise a jour de herdr, reinstallation) et
# les touches qui pointent dessus deviennent alors muettes : la config reste
# valide, herdr capte bien la touche, mais l'action n'existe plus. Rejoue a
# chaque apply, ce script repose ce qui manque.
set -eu

log() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

# Binaire : installateur officiel, qui verifie le SHA-256 du manifeste et pose
# herdr dans ~/.local/bin, sans sudo. Seulement s'il manque : les mises a jour
# passent ensuite par `herdr update`. ~/.local/bin n'est pas forcement dans le
# PATH de chezmoi (zshrc l'ajoute plus tard), d'ou l'ajout ici.
PATH="$PATH:$HOME/.local/bin"
if ! command -v herdr >/dev/null 2>&1; then
    log "Installation de herdr"
    # Telecharge avant d'executer : dans `curl | sh`, un curl en echec donne a
    # sh une entree vide, qui sort en 0. Meme regle que pour les plugins : sans
    # reseau, le reste de l'apply passe.
    if ! installer=$(curl -fsSL https://herdr.dev/install.sh) \
        || ! printf '%s\n' "$installer" | sh; then
        log "herdr : installation echouee, a rejouer"
        exit 0
    fi
fi

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

# Le meme depot sert aux deux OS : chaque plugin declare linux et macos.
# herdr.auto-title est compile a l'installation : go est dans 10-packages.
install_if_missing paulbkim-dev/vim-herdr-navigation vim-herdr-navigation
install_if_missing JLighter/herdr-spawn herdr-spawn
install_if_missing kryptamine/herdr-auto-title herdr.auto-title
install_if_missing edmundmiller/herdr-plugin-hunk hunk.diff

# Hook d'etat des agents Claude : settings.json l'appelle par son chemin,
# herdr l'ecrit. Reinstalle seulement s'il manque ou date d'une autre version.
if herdr integration status 2>/dev/null | grep -q '^claude: current '; then
    log "integration claude a jour"
else
    log "Installation de l'integration claude"
    herdr integration install claude || log "integration claude echouee, a rejouer"
fi

# Skill herdr : `herdr --skill` en est la source, et suit donc la version du
# binaire. Remplace le lien vers ~/.agents/skills/herdr pose par `npx skills`,
# fige a la version du jour de l'installation.
skill_dir="$HOME/.claude/skills/herdr"
[ -L "$skill_dir" ] && rm "$skill_dir"
mkdir -p "$skill_dir"
if herdr --skill > "$skill_dir/SKILL.md.tmp"; then
    mv "$skill_dir/SKILL.md.tmp" "$skill_dir/SKILL.md"
    log "skill herdr a jour"
else
    rm -f "$skill_dir/SKILL.md.tmp"
    log "skill herdr : generation echouee, a rejouer"
fi
