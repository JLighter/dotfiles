#!/usr/bin/env bash
# Recharge le thème Catppuccin de tmux pour le flavor passé en argument.
#
# Pourquoi ce script : les fichiers de palette du plugin utilisent `set -ogq`
# (set only if unset), donc les variables @thm_* déjà posées ne sont jamais
# réécrites lors d'un simple `run catppuccin.tmux`. On purge d'abord toute la
# famille @thm_* pour forcer la reprise des couleurs du nouveau flavor.
#
# Appelé par les hooks client-light-theme / client-dark-theme dans .tmux.conf.

set -euo pipefail

flavor="${1:?usage: reload-theme.sh <flavor>}"
plugin="$HOME/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux"

# Purge les couleurs en cache du flavor précédent.
tmux show -g 2>/dev/null \
  | grep -oE '^@thm_[a-z0-9_]+' \
  | while IFS= read -r opt; do tmux set -gu "$opt"; done

tmux set -g @catppuccin_flavor "$flavor"
tmux run "$plugin"
