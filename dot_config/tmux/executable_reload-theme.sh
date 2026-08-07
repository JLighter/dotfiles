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
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin="$HOME/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux"

# Purge les couleurs en cache du flavor précédent.
tmux show -g 2>/dev/null \
  | grep -oE '^@thm_[a-z0-9_]+' \
  | while IFS= read -r opt; do tmux set -gu "$opt"; done

tmux set -g @catppuccin_flavor "$flavor"
tmux run "$plugin"

# Recharger Catppuccin peut régénérer status-format et donc réinitialiser les
# marqueurs de débordement (retour à < >). On réapplique les flèches après
# chaque bascule de thème pour que l'affichage reste stable.
"$here/fix-status-markers.sh"

# Les couleurs des gros chiffres de sélection de pane (display-panes) n'acceptent
# pas les références #{@thm_*} : on les réapplique avec la valeur résolue du
# nouveau flavor, sinon elles restent figées sur l'ancien thème.
tmux set -g display-panes-colour "$(tmux display-message -p '#{@thm_overlay_1}')"
tmux set -g display-panes-active-colour "$(tmux display-message -p '#{@thm_mauve}')"
