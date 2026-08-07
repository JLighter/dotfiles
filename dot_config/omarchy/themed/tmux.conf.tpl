# Palette tmux dérivée du thème Omarchy actif.
#
# Omarchy régénère ce template dans ~/.config/omarchy/current/theme/tmux.conf à
# chaque `omarchy theme set`, en substituant les {{ ... }} depuis le colors.toml
# du thème. Le .tmux.conf le source après Catppuccin, ce qui écrase la palette
# du flavor par celle du thème système. Sur macOS le fichier n'existe pas et
# Catppuccin reste seul maître.
#
# Les noms @thm_* sont ceux de Catppuccin : les conserver permet à tout le reste
# du .tmux.conf de fonctionner sans y toucher.

# Base
set -g @thm_fg "{{ foreground }}"
set -g @thm_bg "{{ background }}"

# Surfaces et gris, du plus sombre au plus clair
set -g @thm_surface_0 "{{ color0 }}"
set -g @thm_surface_1 "{{ color8 }}"
set -g @thm_overlay_0 "{{ color8 }}"
set -g @thm_overlay_1 "{{ color7 }}"
set -g @thm_overlay_2 "{{ color7 }}"

# Accents. lavender sert aux bordures de pane actives et à la sélection, il est
# donc mappé sur l'accent du thème plutôt que sur un bleu ANSI.
set -g @thm_lavender "{{ accent }}"
set -g @thm_mauve "{{ color5 }}"
set -g @thm_green "{{ color2 }}"
set -g @thm_yellow "{{ color3 }}"
set -g @thm_peach "{{ color11 }}"

# Rien de plus ici : le .tmux.conf source ce fichier juste après Catppuccin,
# donc mode-style et display-panes-colour sont posés ensuite avec ces valeurs.
