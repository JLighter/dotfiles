#!/bin/bash
# Reflète l'état « en attente d'input utilisateur » de Claude dans le titre du
# pane tmux, pour que la status bar tmux le colore (cf. ~/.tmux.conf).
#
# Mécanique
#   Claude pose lui-même un glyph en tête du titre du pane : ✳ = prêt/terminé,
#   un caractère Braille animé = en travail. Mais il utilise ✳ AUSSI quand il
#   attend une réponse de l'utilisateur — tmux ne peut donc pas distinguer
#   « terminé » de « en attente ». Ce hook comble ce trou :
#     - sur Notification/idle_prompt : il réécrit le titre en préfixant un
#        (point d'interrogation rond Nerd Font), que tmux colore en jaune.
#     - sur UserPromptSubmit : l'utilisateur a repris la main, on ne touche à
#       rien — Claude réémet de lui-même son glyph « en travail » au tour suivant.
#
# On écrit la séquence OSC 2 (titre) directement dans le tty du pane plutôt que
# via send-keys : cela repose le titre sans rien injecter dans le stdin de
# l'application, donc sans perturber Claude.
#
# Le hook est silencieux et non bloquant : toute condition non remplie => exit 0.

WAIT_GLYPH=""

# Hors tmux : rien à faire.
[ -z "$TMUX" ] && exit 0
[ -z "$TMUX_PANE" ] && exit 0

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)

case "$EVENT" in
  Notification)
    NTYPE=$(printf '%s' "$INPUT" | grep -o '"notification_type":"[^"]*"' | head -1 | cut -d'"' -f4)
    # On ne marque QUE l'attente d'input utilisateur (idle / permission).
    case "$NTYPE" in
      idle_prompt|permission_prompt) ;;
      *) exit 0 ;;
    esac

    TTY=$(tmux display-message -p -t "$TMUX_PANE" "#{pane_tty}" 2>/dev/null)
    [ -z "$TTY" ] && exit 0
    [ -w "$TTY" ] || exit 0

    CUR=$(tmux display-message -p -t "$TMUX_PANE" "#{pane_title}" 2>/dev/null)
    # Déjà marqué « en attente » ? Ne rien refaire.
    case "$CUR" in
      "$WAIT_GLYPH"*) exit 0 ;;
    esac
    # Retire un éventuel glyph d'état de tête (✳ ou Braille U+2800..U+28FF) avant
    # de poser le nôtre, pour ne pas empiler les glyphs.
    STRIPPED=$(printf '%s' "$CUR" | sed -E 's/^(✳|[⠀-⣿])[[:space:]]*//')
    printf '\033]2;%s %s\007' "$WAIT_GLYPH" "$STRIPPED" > "$TTY"
    ;;
esac

exit 0
