#!/bin/sh
# Amorçage complet d'une machine, macOS ou Omarchy.
#
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/jlighter/dotfiles/main/bootstrap.sh)"
#
# Installe chezmoi, clone le dépôt, applique les dotfiles. Tout le reste
# (paquets, oh-my-zsh, plugins, tpm, shell par défaut) est pris en charge par
# les scripts de .chezmoiscripts/ que `chezmoi apply` déclenche.
#
# Idempotent : relançable sans risque sur une machine déjà configurée.
set -eu

REPO_URL="https://github.com/jlighter/dotfiles.git"
DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

log()  { printf '\033[1;34m::\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m!!\033[0m %s\n' "$1" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git est requis (macOS : xcode-select --install)"

# ── 1. chezmoi ───────────────────────────────────────────────────────────────
if command -v chezmoi >/dev/null 2>&1; then
    log "chezmoi déjà présent"
else
    log "Installation de chezmoi"
    case "$(uname -s)" in
        Darwin)
            command -v brew >/dev/null 2>&1 || die "Homebrew requis : https://brew.sh"
            brew install chezmoi
            ;;
        Linux)
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --needed --noconfirm chezmoi
            else
                die "Distribution non gérée : installe chezmoi manuellement (https://chezmoi.io)"
            fi
            ;;
        *)
            die "OS non géré : $(uname -s)"
            ;;
    esac
fi

# ── 2. Dépôt ─────────────────────────────────────────────────────────────────
if [ -d "$DOTFILES/.git" ]; then
    log "Dépôt déjà présent dans $DOTFILES"
else
    log "Clone du dépôt dans $DOTFILES"
    git clone "$REPO_URL" "$DOTFILES"
fi

# ── 3. Application ───────────────────────────────────────────────────────────
# `init` pose les questions (nom, email, machine pro) et écrit
# ~/.config/chezmoi/chezmoi.toml, qui fixe sourceDir : les appels suivants à
# `chezmoi` n'ont plus besoin de --source.
log "Application des dotfiles"
chezmoi init --source "$DOTFILES" --apply

log "Terminé. Ouvre un nouveau terminal pour charger le shell."
