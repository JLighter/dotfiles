#!/bin/sh
# Statusline de Claude Code, en segments powerline : modèle, remplissage du
# contexte, dossier courant, branche git.
#
# Claude Code passe le JSON de session sur stdin
# (https://code.claude.com/docs/en/statusline) et n'affiche la sortie que si
# le script sort 0 : chaque échec se rabat donc sur un texte lisible plutôt
# que sur une ligne vide.
#
# Couleurs : les 16 couleurs ANSI seulement, pour suivre le thème Omarchy.
# Glyphes : Nerd Font (cf. .chezmoiscripts/50-font), écrits en octets UTF-8
# octaux pour rester lisibles par tout `printf` POSIX.
# Tests : tests/statusline.test.sh.

SEP=$(printf '\356\202\260')      # U+E0B0 séparateur powerline
I_MODEL=$(printf '\357\213\233')  # U+F2DB microchip
I_CTX=$(printf '\357\207\200')    # U+F1C0 database
I_DIR=$(printf '\357\201\274')    # U+F07C folder-open
I_GIT=$(printf '\356\202\240')    # U+E0A0 branche

command -v jq >/dev/null 2>&1 || { printf 'statusline : jq manquant'; exit 0; }

# Une valeur par ligne : modèle, pourcentage, dossier pour git, dossier affiché.
# Un caractère de contrôle décalerait les lignes ou piloterait le terminal :
# retiré du texte affiché, et un chemin qui en contient n'est pas affiché du tout.
FIELDS=$(jq -r '
  def clean: gsub("[\u0000-\u001f\u007f]"; "");
  def text: select(type == "string") | clean | select(. != "");
  (.workspace.current_dir // .cwd // "" | if type == "string" and (test("[\u0000-\u001f\u007f]") | not) then . else "" end) as $dir
  | ([.model.display_name, .model.id | text] | first // "?"),
    (.context_window.used_percentage | if type == "number" and . >= 0 and . <= 100 then round else "" end),
    $dir,
    ($dir | rtrimstr("/") as $d
      | if $dir == "" then ""
        elif $d == "" then "/"
        elif $d == (env.HOME // "" | rtrimstr("/")) then "~"
        else $d | split("/") | last end)
' 2>/dev/null) || { printf 'statusline : entrée illisible'; exit 0; }

# IFS vide : garder les espaces en bord de valeur, qui font partie d'un chemin.
{ IFS= read -r MODEL; IFS= read -r PCT; IFS= read -r DIR; IFS= read -r NAME; } <<EOF
$FIELDS
EOF

# Fond du segment précédent, pour la flèche de transition.
PREV=

# seg <couleur 0-7> <texte> : ouvre un segment texte noir sur fond coloré.
seg() {
  if [ -z "$PREV" ]; then
    printf '\033[30;4%sm %s ' "$1" "$2"
  else
    printf '\033[3%s;4%sm%s\033[30;4%sm %s ' "$PREV" "$1" "$SEP" "$1" "$2"
  fi
  PREV=$1
}

seg 4 "$I_MODEL $MODEL"

if [ -z "$PCT" ]; then
  seg 7 "$I_CTX --"
elif [ "$PCT" -ge 80 ]; then
  seg 1 "$I_CTX $PCT%"
elif [ "$PCT" -ge 50 ]; then
  seg 3 "$I_CTX $PCT%"
else
  seg 2 "$I_CTX $PCT%"
fi

if [ -n "$DIR" ]; then
  seg 6 "$I_DIR $NAME"

  # --no-optional-locks : ne pas disputer index.lock à un git lancé en parallèle.
  # -uno : les fichiers non suivis ne comptent pas, et le statut reste rapide.
  BRANCH=$(git -C "$DIR" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) ||
    BRANCH=$(git -C "$DIR" --no-optional-locks rev-parse --short HEAD 2>/dev/null) ||
    BRANCH=
  if [ -n "$BRANCH" ]; then
    if [ -n "$(git -C "$DIR" --no-optional-locks status --porcelain -uno 2>/dev/null)" ]; then
      BRANCH="$BRANCH*"
    fi
    seg 5 "$I_GIT $BRANCH"
  fi
fi

printf '\033[0;3%sm%s\033[0m' "$PREV" "$SEP"
