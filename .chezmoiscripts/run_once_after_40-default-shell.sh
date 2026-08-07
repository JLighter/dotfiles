#!/bin/sh
# Bascule le shell de connexion sur zsh. Demande le mot de passe : c'est la
# seule étape interactive du bootstrap.
set -eu

ZSH_BIN="$(command -v zsh 2>/dev/null || true)"

if [ -z "$ZSH_BIN" ]; then
    printf '\033[1;33m..\033[0m zsh introuvable, shell par défaut inchangé\n' >&2
    exit 0
fi

# Déjà sur zsh : rien à faire.
case "${SHELL:-}" in
    *zsh) printf '\033[1;34m::\033[0m zsh est déjà le shell par défaut\n'; exit 0 ;;
esac

# chsh refuse un shell absent de /etc/shells (cas du zsh Homebrew sur macOS).
if ! grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null; then
    printf '\033[1;34m::\033[0m Ajout de %s à /etc/shells\n' "$ZSH_BIN"
    echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
fi

printf '\033[1;34m::\033[0m Bascule du shell par défaut sur %s\n' "$ZSH_BIN"
chsh -s "$ZSH_BIN"
