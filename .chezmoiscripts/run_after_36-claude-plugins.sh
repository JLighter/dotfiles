#!/bin/sh
# Plugins Claude Code servis par une marketplace tierce :
#   claude-hud — le HUD de la statusline, cible de dot_claude/hooks/claude-hud-statusline.sh
#
# `settings.json` declare bien la marketplace et le plugin, mais le clone lui
# meme vit sous ~/.claude/plugins/, que le depot ne versionne pas. Sur une
# machine neuve les declarations pointent donc dans le vide : la statusline
# ne trouve rien et sort en silence. Ce script pose le clone manquant.
#
# Volontairement pas `run_once`, comme les plugins herdr : le cache peut etre
# purge sans que la declaration bouge.
set -eu

log() { printf '\033[1;34m::\033[0m %s\n' "$1"; }

command -v claude >/dev/null 2>&1 || { log "claude absent, plugins ignores"; exit 0; }

# Une panne reseau ne doit pas faire echouer tout le `chezmoi apply` : le reste
# des dotfiles se pose tres bien sans le HUD.
if claude plugin marketplace list 2>/dev/null | grep -q '^  . claude-hud$'; then
    log "marketplace claude-hud deja presente"
else
    log "Ajout de la marketplace claude-hud"
    claude plugin marketplace add jarrodwatts/claude-hud >/dev/null 2>&1 ||
        { log "claude-hud : marketplace injoignable, a rejouer"; exit 0; }
fi

if claude plugin list 2>/dev/null | grep -q '^  . claude-hud@claude-hud$'; then
    log "claude-hud deja installe"
else
    log "Installation de claude-hud"
    claude plugin install claude-hud@claude-hud --scope user >/dev/null 2>&1 ||
        log "claude-hud : installation echouee, a rejouer"
fi
