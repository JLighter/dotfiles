#!/bin/bash
# Tests de dot_claude/executable_statusline.sh, la statusline de Claude Code.
#
# Le script reçoit sur stdin le JSON de session décrit dans
# https://code.claude.com/docs/en/statusline et affiche une ligne sobre :
# Quoi (modèle, effort, fast, thinking, agent, style) │ Remplissage │ Où
# (dossier, branche, worktree, PR). Il sort toujours 0 avec un texte lisible,
# sinon Claude Code affiche une ligne vide.
#
# Lancement : bash tests/statusline.test.sh
set -u
export LC_ALL=C.UTF-8   # ${#var} compte des caractères, pas des octets
unset COLUMNS           # la largeur du shell qui lance les tests ne doit rien changer

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/dot_claude/executable_statusline.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ESC=$(printf '\033')

G_BRANCH=$(printf '\356\202\240')     # U+E0A0
G_WORKTREE=$(printf '\357\206\273')   # U+F1BB
G_PR=$(printf '\357\220\207')         # U+F407
G_EFFORT=$(printf '\357\207\236')     # U+F1DE
G_AGENT=$(printf '\357\212\275')      # U+F2BD
G_STYLE=$(printf '\357\207\274')      # U+F1FC
G_MODEL=$(printf '\357\213\233')     # U+F2DB
G_POWERLINE=$(printf '\356\202\260')  # U+E0B0, style v1 abandonné

# Sortie brute dans $OUT, code de sortie dans $STATUS, texte visible dans $TEXT
# (sans couleurs ni liens OSC 8). Les variables d'environnement passées en
# préfixe (COLUMNS=…, HOME=…) atteignent le script.
run() {
  OUT=$(printf '%s' "$1" | sh "$SCRIPT")
  STATUS=$?
  TEXT=$(printf '%s' "$OUT" | sed -e "s/${ESC}\[[0-9;]*m//g" -e "s/${ESC}]8;;[^${ESC}]*${ESC}\\\\//g")
}

ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n       sortie : %s\n' "$1" "$2"; }

contains()     { case "$TEXT" in *"$2"*) ok "$1" ;; *) ko "$1" "$TEXT" ;; esac; }
not_contains() { case "$TEXT" in *"$2"*) ko "$1" "$TEXT" ;; *) ok "$1" ;; esac; }
raw_contains() { case "$OUT" in *"$2"*) ok "$1" ;; *) ko "$1" "$OUT" ;; esac; }
matches()      { case "$TEXT" in $2) ok "$1" ;; *) ko "$1" "$TEXT" ;; esac; }
exits_zero()   { [ "$STATUS" -eq 0 ] && ok "$1" || ko "$1" "code $STATUS"; }
non_empty()    { [ -n "$TEXT" ] && ok "$1" || ko "$1" "(vide)"; }
equals()       { [ "$2" = "$3" ] && ok "$1" || ko "$1" "attendu « $3 », obtenu « $2 »"; }

# Largeur affichée du texte visible (un emoji ou un idéogramme occupe 2 colonnes).
cols() { printf '%s' "$TEXT" | wc -L | tr -d ' '; }

# Nombre de cases pleines et vides de la jauge de remplissage.
filled() { printf '%s' "$TEXT" | grep -o '▓' | wc -l | tr -d ' '; }
empty()  { printf '%s' "$TEXT" | grep -o '░' | wc -l | tr -d ' '; }
cells()  { echo $(( $(filled) + $(empty) )); }
# Code couleur posé juste avant la première case de la jauge (vide si aucun).
gauge_color() {
  printf '%s' "$OUT" | grep -o "${ESC}\[[0-9;]*m\(▓\|░\)" | head -1 | sed "s/${ESC}\[\([0-9;]*\)m.*/\1/"
}

# fixture <dossier> <remplissage JSON> [champs JSON supplémentaires]
# Un champ supplémentaire déjà présent (model, workspace) remplace le premier :
# jq garde la dernière occurrence d'une clé.
fixture() {
  printf '{"model":{"display_name":"Opus 5.5"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":%s}%s}' \
    "$1" "$2" "${3:+,$3}"
}

# Dépôts de test isolés de la config git de l'utilisateur (hooksPath, signature…).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git_repo() {
  mkdir -p "$1"
  git -C "$1" init -q -b "${2:-feature-x}"
  printf 'a\n' > "$1/f"
  git -C "$1" add f
  git -C "$1" -c user.name=t -c user.email=t@t commit -q -m init
}
git_repo "$WORK/propre"
git_repo "$WORK/modifie";   printf 'b\n' >> "$WORK/modifie/f"
git_repo "$WORK/non-suivi"; printf 'n\n' > "$WORK/non-suivi/nouveau"
git_repo "$WORK/detache";   git -C "$WORK/detache" checkout -q --detach
git_repo "$WORK/longue" feature-branche-au-nom-tres-long
SHA=$(git -C "$WORK/detache" rev-parse --short HEAD)
mkdir -p "$WORK/hors-depot" "$WORK/home" "$WORK/propre/sous/dossier" "$WORK/propre "

echo "Forme"
run "$(fixture "$WORK/propre" 42)"
exits_zero   "sort 0 sur une entrée complète"
matches      "ordre Quoi → Remplissage → Où"       "*Opus 5.5*42%*propre*feature-x*"
contains     "groupes séparés par │"               " │ "
raw_contains "séparateur atténué"                  "${ESC}[2m │ "
case "$OUT" in "${ESC}"*) ko "modèle en couleur par défaut" "$OUT" ;; *) ok "modèle en couleur par défaut" ;; esac
not_contains "pas de séparateur powerline"         "$G_POWERLINE"
case "$OUT" in *"
"*) ko "tient sur une ligne" "$OUT" ;; *) ok "tient sur une ligne" ;; esac

echo "Remplissage"
contains     "affiche le pourcentage"              "42%"
run "$(fixture "$WORK/hors-depot" 41.6)"
contains     "arrondit un pourcentage flottant"    "42%"
run "$(fixture "$WORK/hors-depot" 0)"
contains     "0 % mesuré : affiché 0%"             "0%"
not_contains "0 % mesuré : pas le marqueur --"     "--"
run "$(fixture "$WORK/hors-depot" 50)"
equals       "jauge de 10 cases"                   "$(cells)" 10
equals       "50 % : 5 cases pleines"              "$(filled)" 5
run "$(fixture "$WORK/hors-depot" 29)"
equals       "29 % : vert"                         "$(gauge_color)" 32
run "$(fixture "$WORK/hors-depot" 30)"
equals       "30 % : jaune"                        "$(gauge_color)" 33
run "$(fixture "$WORK/hors-depot" 59)"
equals       "59 % : encore jaune"                 "$(gauge_color)" 33
run "$(fixture "$WORK/hors-depot" 60)"
equals       "60 % : rouge"                        "$(gauge_color)" 31
run "$(fixture "$WORK/hors-depot" null)"
contains     "non mesuré : marqueur --"            "--"
not_contains "non mesuré : jamais 0%"              "0%"
equals       "non mesuré : jauge vide"             "$(filled)/$(empty)" 0/10
case "$(gauge_color)" in 31|32|33) ko "non mesuré : couleur neutre" "$(gauge_color)" ;; *) ok "non mesuré : couleur neutre" ;; esac
run '{"model":{"display_name":"Opus 5.5"},"workspace":{"current_dir":"/"}}'
contains     "context_window absent : marqueur --" "--"
not_contains "context_window absent : jamais 0%"   "0%"
run "$(fixture "$WORK/hors-depot" 100.2)"
contains     "au-dessus de 100 : borné à 100%"     "100%"
equals       "au-dessus de 100 : jauge pleine"     "$(filled)" 10
equals       "au-dessus de 100 : rouge"            "$(gauge_color)" 31
run "$(fixture "$WORK/hors-depot" -1)"
contains     "sous 0 : borné à 0%"                 "0%"
not_contains "sous 0 : pas le marqueur --"         "--"
run "$(fixture "$WORK/hors-depot" '"beaucoup"')"
contains     "remplissage non numérique : --"      "--"
run "$(fixture "$WORK/hors-depot" 29.6)"
contains     "29.6 : affiché 30%"                  "30%"
equals       "29.6 : couleur du nombre affiché"    "$(gauge_color)" 33

echo "Quoi"
run "$(fixture "$WORK/hors-depot" 10 '"effort":{"level":"high"}')"
contains     "effort affiché"                      "$G_EFFORT high"
run "$(fixture "$WORK/hors-depot" 10)"
not_contains "effort absent : rien"                "$G_EFFORT"
run "$(fixture "$WORK/hors-depot" 10 '"fast_mode":true')"
contains     "fast actif : affiché"                "fast"
run "$(fixture "$WORK/hors-depot" 10 '"fast_mode":false')"
not_contains "fast inactif : rien"                 "fast"
run "$(fixture "$WORK/hors-depot" 10 '"thinking":{"enabled":true}')"
contains     "thinking actif : affiché"            "think"
run "$(fixture "$WORK/hors-depot" 10 '"thinking":{"enabled":false}')"
not_contains "thinking inactif : rien"             "think"
run "$(fixture "$WORK/hors-depot" 10 '"agent":{"name":"relecteur"}')"
contains     "agent présent : affiché"             "$G_AGENT relecteur"
run "$(fixture "$WORK/hors-depot" 10)"
not_contains "agent absent : rien"                 "$G_AGENT"
run "$(fixture "$WORK/hors-depot" 10 '"output_style":{"name":"Explanatory"}')"
contains     "style non default : affiché"         "$G_STYLE Explanatory"
run "$(fixture "$WORK/hors-depot" 10 '"output_style":{"name":"default"}')"
not_contains "style default : rien"                "$G_STYLE"
run '{"model":{"display_name":""},"workspace":{"current_dir":"/"}}'
contains     "nom de modèle vide : repli ?"        "?"
run "$(fixture "$WORK/hors-depot" 10 '"cost":{"total_cost_usd":12.34},"rate_limits":{"five_hour":{"used_percentage":77}},"session_name":"ma-session","workspace":{"current_dir":"'"$WORK/hors-depot"'","repo":{"owner":"proprio","name":"depot"}}')"
not_contains "jamais le coût"                      "12.34"
not_contains "jamais les quotas"                   "77"
not_contains "jamais le nom de session"            "ma-session"
not_contains "jamais owner/dépôt"                  "proprio"
run '{"workspace":{"current_dir":"/"}}'
contains     "modèle absent : repli ?"             "?"
run '{"model":{"display_name":"","id":"claude-opus-5-5"},"workspace":{"current_dir":"/"}}'
contains     "nom vide : repli sur l'identifiant"  "claude-opus-5-5"

echo "Où : dossier"
run "$(fixture "$WORK/hors-depot" 10)"
contains     "nom du dossier courant"              "hors-depot"
not_contains "jamais le chemin complet"            "$WORK"
HOME="$WORK/home" run "$(fixture "$WORK/home" 10)"
contains     "le HOME s'affiche ~"                 "~"
not_contains "le HOME ne s'affiche pas en clair"   "home"
HOME="$WORK/home" run "$(fixture "$WORK/home/" 10)"
contains     "HOME avec slash final : ~"           "~"
HOME="$WORK" run "$(fixture "$WORK/hors-depot" 10)"
contains     "sous-dossier du HOME : son nom"      "hors-depot"
not_contains "sous-dossier du HOME : pas ~"        "~"
run '{"cwd":"'"$WORK/hors-depot"'"}'
contains     "repli sur .cwd sans workspace"       "hors-depot"

echo "Où : branche"
run "$(fixture "$WORK/propre" 10)"
contains     "branche avec son glyphe"             "$G_BRANCH feature-x"
not_contains "arbre propre : pas d'astérisque"     "feature-x*"
run "$(fixture "$WORK/propre/sous/dossier" 10)"
contains     "sous-dossier d'un dépôt : branche"   "feature-x"
run "$(fixture "$WORK/modifie" 10)"
contains     "fichier suivi modifié : astérisque"  "feature-x*"
raw_contains "astérisque en jaune"                 "${ESC}[33m*"
run "$(fixture "$WORK/non-suivi" 10)"
not_contains "fichier non suivi seul : pas d'astérisque" "feature-x*"
run "$(fixture "$WORK/detache" 10)"
contains     "HEAD détachée : SHA court"           "$SHA"
run "$(fixture "$WORK/hors-depot" 10)"
not_contains "hors dépôt : pas de branche"         "$G_BRANCH"
run "$(fixture "$WORK/propre " 10)"
not_contains "espace finale : pas la branche du voisin" "feature-x"

echo "Où : worktree"
run "$(fixture "$WORK/hors-depot" 10 '"workspace":{"current_dir":"'"$WORK/hors-depot"'","git_worktree":"essai"}')"
contains     "worktree affiché"                    "$G_WORKTREE essai"
run "$(fixture "$WORK/hors-depot" 10 '"workspace":{"current_dir":"'"$WORK/hors-depot"'","git_worktree":"hors-depot"}')"
not_contains "worktree = dossier : masqué"         "$G_WORKTREE"
run "$(fixture "$WORK/hors-depot" 10)"
not_contains "pas de worktree : rien"              "$G_WORKTREE"

echo "Où : pull request"
PR_URL="https://github.com/o/r/pull/1234"
pr() { fixture "$WORK/hors-depot" 10 '"pr":{"number":1234,"url":"'"$PR_URL"'"'"${1:+,\"review_state\":\"$1\"}"'}'; }
run "$(pr)"
contains     "numéro de PR"                        "$G_PR #1234"
raw_contains "lien OSC 8 vers la PR"               "${ESC}]8;;$PR_URL"
raw_contains "lien OSC 8 refermé après la PR"      "#1234${ESC}]8;;${ESC}\\"
case "$OUT" in *"m$G_PR"*) ko "sans état : PR sans couleur" "$OUT" ;; *) ok "sans état : PR sans couleur" ;; esac
run "$(pr approved)"
raw_contains "approuvée : vert"                    "${ESC}[32m$G_PR"
run "$(pr changes_requested)"
raw_contains "modifications demandées : rouge"     "${ESC}[31m$G_PR"
run "$(pr pending)"
raw_contains "en attente : jaune"                  "${ESC}[33m$G_PR"
run "$(pr draft)"
raw_contains "brouillon : atténué"                 "${ESC}[2m$G_PR"
run "$(fixture "$WORK/hors-depot" 10)"
not_contains "pas de PR : rien"                    "$G_PR"
run "$(fixture "$WORK/hors-depot" 10 '"pr":{"url":"https://x/1"}')"
not_contains "PR sans numéro : rien"               "$G_PR"

echo "Largeur"
# La ligne garde 2 colonnes de marge sous COLUMNS. Chaque palier ne s'applique
# que si le précédent ne suffit pas : on part de la largeur obtenue W, et
# COLUMNS = W + 1 laisse moins que la marge, ce qui force le palier suivant.
printf 'b\n' >> "$WORK/longue/f"
FULL="$(fixture "$WORK/longue" 50 '"workspace":{"current_dir":"'"$WORK/longue"'","git_worktree":"essai"},"model":{"display_name":"Opus 5.5 (1M context)"},"effort":{"level":"high"},"fast_mode":true,"thinking":{"enabled":true},"agent":{"name":"relecteur"},"output_style":{"name":"Explanatory"},"pr":{"number":7,"url":"https://x/7"}')"
run "$FULL"; W=${#TEXT}
equals       "sans COLUMNS : jauge entière"        "$(cells)" 10
COLUMNS=$((W + 2)) run "$FULL"
equals       "tient avec la marge : rien d'abrégé" "${#TEXT}" "$W"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
equals       "1) jauge réduite à 5 cases"          "$(cells)" 5
contains     "1) modèle encore complet"            "(1M context)"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
not_contains "2) modèle abrégé"                    "(1M context)"
contains     "2) modèle abrégé : nom gardé"        "Opus 5.5"
contains     "2) branche encore complète"          "feature-branche-au-nom-tres-long"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
not_contains "3) branche tronquée"                 "feature-branche-au-nom-tres-long"
contains     "3) branche tronquée à 20 caractères" "feature-branche-au-…*"
contains     "3) style encore présent"             "$G_STYLE"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
not_contains "4) style retiré"                     "$G_STYLE"
contains     "4) agent encore présent"             "$G_AGENT"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
not_contains "5) agent retiré"                     "$G_AGENT"
contains     "5) thinking encore présent"          "think"
COLUMNS=$((W + 1)) run "$FULL"; W=${#TEXT}
not_contains "6) thinking retiré"                  "think"
contains     "6) fast encore présent"              "fast"
COLUMNS=$((W + 1)) run "$FULL"
not_contains "7) fast retiré"                      "fast"
COLUMNS=10 run "$FULL"
exits_zero   "très étroit : sort 0"
for kept in "Opus 5.5" "50%" "$G_EFFORT" "longue" "$G_BRANCH" "*" "$G_WORKTREE essai" "$G_PR"; do
  contains   "très étroit : jamais retiré : $kept" "$kept"
done
COLUMNS=10 run "$(fixture "$WORK/hors-depot" 10 '"model":{"display_name":"(beta)"}')"
contains     "modèle tout entre parenthèses : jamais vidé" "(beta)"

# Caractères larges : un emoji occupe deux colonnes, la ligne doit le savoir.
WIDE="$(fixture "$WORK/hors-depot" 50 '"agent":{"name":"🤖🤖🤖🤖🤖🤖"}')"
run "$WIDE"; W=$(cols)
COLUMNS=$((W + 1)) run "$WIDE"
equals       "emoji compté double : jauge réduite" "$(cells)" 5
[ "$(cols)" -le $((W - 1)) ] && ok "emoji compté double : marge respectée" || ko "emoji compté double : marge respectée" "$(cols) > $((W - 1))"

COLUMNS=abc run "$FULL"
exits_zero   "COLUMNS non numérique : sort 0"
equals       "COLUMNS non numérique : ignoré"      "$(cells)" 10

echo "Robustesse"
run "ceci n'est pas du JSON"
exits_zero   "entrée illisible : sort 0"
contains     "entrée illisible : le signale"       "illisible"
run '{"model":"Opus","workspace":{"current_dir":"/"}}'
exits_zero   "champ mal typé : sort 0"
not_contains "champ mal typé : pas « entrée vide »" "vide"
run ""
exits_zero   "entrée vide : sort 0"
non_empty    "entrée vide : affiche quelque chose"
# PATH réduit à git seul : jq introuvable.
mkdir -p "$WORK/bin"; ln -s "$(command -v git)" "$WORK/bin/git"
OUT=$(printf '%s' "$(fixture "$WORK/propre" 10)" | PATH="$WORK/bin" /bin/sh "$SCRIPT"); STATUS=$?
TEXT=$OUT
exits_zero   "sans jq : sort 0"
contains     "sans jq : le signale"                "jq manquant"

printf '\n%d ok, %d échec(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
