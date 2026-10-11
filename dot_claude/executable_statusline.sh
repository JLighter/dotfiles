#!/bin/sh
# Statusline de Claude Code, sur une ligne sobre :
#   Quoi (modèle, effort, fast, thinking, agent, style) │ Remplissage │ Où
#   (dossier, branche, worktree, PR)
#
# Claude Code passe le JSON de session sur stdin
# (https://code.claude.com/docs/en/statusline) et n'affiche la sortie que si
# le script sort 0 : chaque échec se rabat donc sur un texte lisible plutôt
# que sur une ligne vide.
#
# Couleur seulement quand elle porte un sens : jauge de remplissage (jaune à
# 30 %, rouge à 60 %), * d'un fichier suivi modifié, état de la PR.
# La ligne vise COLUMNS - 2. Trop large : jauge réduite, modèle abrégé,
# branche tronquée, puis retrait de style, agent, thinking, fast. Au-delà,
# Claude Code tronque.
#
# Tests : tests/statusline.test.sh.

command -v jq >/dev/null 2>&1 || { printf 'statusline : jq manquant'; exit 0; }

INPUT=$(cat)

DIR=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // .cwd // "" | strings' 2>/dev/null) ||
  { printf 'statusline : entrée illisible'; exit 0; }

# --no-optional-locks : ne pas disputer index.lock à un git lancé en parallèle.
# -uno : seuls les fichiers suivis comptent, et le statut reste rapide.
BRANCH=
DIRTY=
if [ -n "$DIR" ]; then
  BRANCH=$(git -C "$DIR" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null) ||
    BRANCH=$(git -C "$DIR" --no-optional-locks rev-parse --short HEAD 2>/dev/null) ||
    BRANCH=
  if [ -n "$BRANCH" ] && [ -n "$(git -C "$DIR" --no-optional-locks status --porcelain -uno 2>/dev/null)" ]; then
    DIRTY=1
  fi
fi

case "${COLUMNS:-}" in
  '' | *[!0-9]*) COLS=0 ;;
  *) COLS=$COLUMNS ;;
esac

# Chaque élément est une liste de morceaux {s, c (couleur), url (lien OSC 8)} ;
# la largeur se mesure sur le texte seul, sans les séquences d'échappement.
LINE=$(printf '%s' "$INPUT" | jq -j --arg branch "$BRANCH" --arg dirty "$DIRTY" --argjson cols "$COLS" '
  def rep($s; $n): [range($n) | $s] | join("");
  def part($s): {s: $s};
  def part($s; $c): {s: $s, c: $c};
  def trunc($n): if length > $n then .[:$n - 1] + "…" else . end;
  # Colonnes occupées : idéogrammes, hangûl et emoji en prennent deux, les
  # diacritiques combinants aucune. Glyphes Nerd Font, │ ▓ ░ … : une, comme
  # les compte Claude Code. Approximation de wcwidth, suffisante ici.
  def width:
    explode | map(
      if (. >= 768 and . <= 879) then 0
      elif (. >= 4352 and . <= 4447) or (. >= 11904 and . <= 42191)
        or (. >= 44032 and . <= 55203) or (. >= 63744 and . <= 64255)
        or (. >= 65040 and . <= 65049) or (. >= 65072 and . <= 65135)
        or (. >= 65280 and . <= 65376) or (. >= 65504 and . <= 65510)
        or (. >= 127744 and . <= 129791) or (. >= 131072 and . <= 262141) then 2
      else 1 end) | add // 0;

  def show:
    (if .c then "\u001b[\(.c)m\(.s)\u001b[0m" else .s end) as $t
    | if .url then "\u001b]8;;\(.url)\u001b\\\($t)\u001b]8;;\u001b\\" else $t end;

  . as $in
  | ($in.workspace.current_dir // $in.cwd // "" | strings) as $dir
  | ($dir | rtrimstr("/")) as $d
  | (if $dir == "" then ""
     elif $d == "" then "/"
     elif $d == (env.HOME // "" | rtrimstr("/")) then "~"
     else $d | split("/") | last end) as $name
  | ([$in.model.display_name, $in.model.id | strings | select(. != "")] | first // "?") as $model
  | ($in.context_window.used_percentage
     | if type == "number" then ([[., 0] | max, 100] | min | round) else null end) as $pct
  | (if $pct == null then "2" elif $pct >= 60 then "31" elif $pct >= 30 then "33" else "32" end) as $gauge

  | def render($o):
      def keep($k): ($o.drop | index([$k])) == null;
      [
        [ [part("\uf2db " + (if $o.short then $model | sub(" *\\([^)]*\\)$"; "") | select(. != "") // $model else $model end))],
          ($in.effort.level | strings | [part("\uf1de " + .)]),
          (select($in.fast_mode == true and keep("fast")) | [part("\uf0e7 fast")]),
          (select($in.thinking.enabled == true and keep("thinking")) | [part("\uf0eb think")]),
          ($in.agent.name | strings | select(keep("agent")) | [part("\uf2bd " + .)]),
          ($in.output_style.name | strings | select(. != "default" and keep("style")) | [part("\uf1fc " + .)])
        ],
        [ [ part(rep("▓"; (($pct // 0) * $o.bar / 100 | round)) + rep("░"; $o.bar - (($pct // 0) * $o.bar / 100 | round)); $gauge),
            part(" "),
            part(if $pct == null then "--" else "\($pct)%" end; $gauge) ] ],
        [ (select($name != "") | [part("\uf07c " + $name)]),
          (select($branch != "")
           | [part("\ue0a0 " + (if $o.trunc then $branch | trunc(20) else $branch end))]
             + (if $dirty == "1" then [part("*"; "33")] else [] end)),
          ($in.workspace.git_worktree | strings | select(. != $name) | [part("\uf1bb " + .)]),
          ($in.pr | objects | select(.number != null)
           | [{s: "\uf407 #\(.number)",
               c: {approved: "32", changes_requested: "31", pending: "33", draft: "2"}[.review_state // ""],
               url: (.url | if type == "string" then . else null end)}])
        ]
      ]
      | map(select(length > 0))
      | { width: (map(map(map(.s) | join("")) | join(" ")) | join(" │ ") | width),
          line: (map(map(map(show) | join("")) | join(" ")) | join(part(" │ "; "2") | show)) };

  [ {bar: 10, short: false, trunc: false, drop: []},
    {bar: 5,  short: false, trunc: false, drop: []},
    {bar: 5,  short: true,  trunc: false, drop: []},
    {bar: 5,  short: true,  trunc: true,  drop: []},
    {bar: 5,  short: true,  trunc: true,  drop: ["style"]},
    {bar: 5,  short: true,  trunc: true,  drop: ["style", "agent"]},
    {bar: 5,  short: true,  trunc: true,  drop: ["style", "agent", "thinking"]},
    {bar: 5,  short: true,  trunc: true,  drop: ["style", "agent", "thinking", "fast"]}
  ] as $paliers
  | if $cols <= 0 then $paliers[0] | render(.)
    else first(($paliers[] | render(.) | select(.width <= $cols - 2)), ($paliers[-1] | render(.))) end
  | .line
' 2>/dev/null)

# Rien produit : entrée vide, ou un champ d'un type inattendu a fait échouer jq.
if [ -z "$LINE" ]; then
  [ -n "$INPUT" ] && LINE='statusline : entrée illisible' || LINE='statusline : entrée vide'
fi
printf '%s' "$LINE"
