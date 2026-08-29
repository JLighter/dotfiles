#!/bin/bash

# Taux de rafraichissement des ecrans, pour le widget Displays de local.menubar.
#
#   display_rate.sh list           -> JSON, une entree par ecran
#   display_rate.sh set NAME RATE  -> applique le taux, puis le rend persistant
#
# `list` ne fait que lire hyprctl. `set` applique a chaud, puis reecrit un bloc
# balise en fin de ~/.config/hypr/monitors.lua : une ligne par ecran configure,
# posee apres le catch-all pour le surcharger.
#
# Le bloc fige le mode, jamais l'echelle : celle-ci reste exprimee par la
# variable `omarchy_monitor_scale` du fichier, que `omarchy-hyprland-monitor-
# scaling` continue de piloter de son cote. Sans cela, la premiere ligne
# specifique ecrite ici gelerait l'echelle telle qu'elle etait ce jour-la.

set -euo pipefail

MONITOR_LUA="$HOME/.config/hypr/monitors.lua"
BLOCK_BEGIN="-- >>> local.menubar displays (genere, ne pas editer a la main)"
BLOCK_END="-- <<< local.menubar displays"

usage() {
  echo "Usage: display_rate.sh list | display_rate.sh set NAME RATE" >&2
}

monitors_json() {
  hyprctl monitors all -j
}

# Modes disponibles a la resolution courante de l'ecran, arrondis au centieme.
# Un ecran eteint ne rapporte ni resolution ni modes : il ressort avec une liste
# vide, et le widget n'affichera simplement pas de pastilles pour lui.
list() {
  monitors_json | jq -c '
    def modes($m):
      [ $m.availableModes[]?
        | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz$")
        | select((.w | tonumber) == $m.width and (.h | tonumber) == $m.height)
        | (.r | tonumber) ];

    [ .[]
      | . as $m
      | {
          name:    $m.name,
          enabled: ($m.disabled != true),
          width:   $m.width,
          height:  $m.height,
          rate:    (($m.refreshRate * 100 | round) / 100),
          rates:   ( (modes($m) + [$m.refreshRate])
                     | map(select(. > 0) | (. * 100 | round) / 100)
                     | unique )
        } ]'
}

apply() {
  local name="$1" want="$2"

  # Le nom finit dans une ligne Lua ecrite sur disque : seul un nom de
  # connecteur ordinaire peut passer.
  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Refusing unsafe monitor name" >&2; exit 1; }
  [[ $want =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Invalid refresh rate" >&2; exit 1; }

  local info
  info=$(monitors_json | jq -e -c --arg n "$name" '.[] | select(.name == $n)') ||
    { echo "Unknown monitor $name" >&2; exit 1; }

  # Le panneau affiche des taux arrondis : on retrouve ici le mode exact le plus
  # proche, sans quoi Hyprland refuserait "144" la ou le pilote annonce 143.91.
  local exact
  exact=$(jq -er --argjson want "$want" '
    . as $m
    | [ $m.availableModes[]?
        | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)Hz$")
        | select((.w | tonumber) == $m.width and (.h | tonumber) == $m.height)
        | (.r | tonumber) ]
    | (if length == 0 then [$m.refreshRate] else . end)
    | map({ rate: ., gap: (. - $want | fabs) })
    | sort_by(.gap)
    | .[0]
    | select(.gap <= 1.5)
    | .rate' <<<"$info") ||
    { echo "No mode near ${want}Hz on $name" >&2; exit 1; }

  local width height scale mode
  width=$(jq -r '.width' <<<"$info")
  height=$(jq -r '.height' <<<"$info")
  # hyprctl rend des flottants bruts (1.60000002) : cinq chiffres significatifs
  # suffisent a retrouver le facteur que l'utilisateur a choisi.
  scale=$(jq -r '.scale' <<<"$info" | awk '{ printf "%.5g\n", $0 }')
  mode="${width}x${height}@${exact}"

  hyprctl keyword monitor "$name,$mode,auto,$scale" >/dev/null
  persist "$name" "$mode"
}

persist() {
  local name="$1" mode="$2"
  [[ -f $MONITOR_LUA ]] || return 0

  # L'echelle reste pilotee par le fichier lui-meme quand il expose encore la
  # variable d'Omarchy ; sinon on fige la valeur courante, faute de mieux.
  local scale_expr
  if grep -q '^local omarchy_monitor_scale = ' "$MONITOR_LUA"; then
    scale_expr="omarchy_monitor_scale"
  else
    scale_expr=$(hyprctl monitors all -j |
      jq -r --arg n "$name" '.[] | select(.name == $n) | .scale' |
      awk '{ printf "%.5g\n", $0 }')
  fi

  local line="hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"auto\", scale = $scale_expr })"

  # Les autres ecrans deja configures sont conserves ; celui qu'on reecrit sort
  # de la liste avant d'y revenir avec son nouveau mode.
  local kept
  kept=$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
    $0 == e { inblock = 0 }
    inblock { print }
    $0 == b { inblock = 1 }' "$MONITOR_LUA" | grep -v "output = \"$name\"," || true)

  local body tmp
  # La substitution de commande mange les sauts de ligne finaux : sans cela, le
  # bloc s'eloignerait du texte d'une ligne vide de plus a chaque ecriture.
  body=$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '
    $0 == b { skip = 1 }
    !skip   { print }
    $0 == e { skip = 0 }' "$MONITOR_LUA")

  tmp=$(mktemp "${MONITOR_LUA}.XXXXXX")
  {
    printf '%s\n\n%s\n' "$body" "$BLOCK_BEGIN"
    [[ -n $kept ]] && printf '%s\n' "$kept"
    printf '%s\n%s\n' "$line" "$BLOCK_END"
  } >"$tmp"
  mv "$tmp" "$MONITOR_LUA"

  # monitors.lua est une cible chezmoi : sans ce rappel, le prochain
  # `chezmoi apply` reviendrait sur le taux qu'on vient d'ecrire.
  if command -v chezmoi >/dev/null 2>&1 &&
    chezmoi source-path "$MONITOR_LUA" >/dev/null 2>&1; then
    chezmoi add "$MONITOR_LUA" >/dev/null 2>&1 || true
  fi
}

case "${1:-}" in
list) list ;;
set)
  [[ $# -eq 3 ]] || { usage; exit 1; }
  apply "$2" "$3"
  ;;
-h | --help) usage ;;
*)
  usage
  exit 1
  ;;
esac
