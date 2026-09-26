#!/bin/bash
# Signale à l'humain, au démarrage d'une session, toute dérive entre
# ~/.claude et sa source chezmoi (~/.dotfiles/dot_claude) : fichier modifié
# sur place par /model, /config ou un installeur, ou supprimé sans que la
# source le sache.
#
# Ne sort rien quand tout est aligné. Sinon, une seule ligne en
# systemMessage : affichée à l'humain, jamais ajoutée au contexte du modèle.

command -v chezmoi >/dev/null 2>&1 || exit 0

DRIFT=$(chezmoi status "$HOME/.claude" 2>/dev/null | wc -l | tr -d ' ')

if [ "$DRIFT" -gt 0 ]; then
  printf '{"systemMessage": "chezmoi : %s écart(s) entre ~/.claude et ~/.dotfiles. Voir : chezmoi status ~/.claude"}\n' "$DRIFT"
fi

exit 0
