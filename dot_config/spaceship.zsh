# Spaceship — configuration du prompt.
#
# Chargé par spaceship lui-même (lib/config.zsh cherche ce chemin), pas par
# le .zshrc. L'intérêt : `spaceship edit` rouvre ce fichier et le re-source à
# la sauvegarde, donc le prompt change sans rouvrir de shell.
#
# Référence locale, une page par section :
#   /opt/homebrew/opt/spaceship/docs/sections/
#   /opt/homebrew/opt/spaceship/docs/config/prompt.md
#
# `spaceship add <section>` / `spaceship remove <section>` essaient une
# section à chaud, sans toucher à ce fichier.

SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_CHAR_SYMBOL="> "

# user/host ne s'affichent qu'en SSH (défaut) : savoir « qui » sans « où »
# n'aide pas. exec_time était déjà calculé par son hook precmd sans être
# affiché. exit_code et jobs restent muets tant qu'il n'y a rien à signaler.
SPACESHIP_PROMPT_ORDER=(user host dir git exec_time line_sep jobs exit_code char)
SPACESHIP_EXIT_CODE_SHOW=true
