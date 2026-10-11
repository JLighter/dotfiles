#!/bin/bash
# Tests de dot_claude/executable_statusline.sh, la statusline de Claude Code.
#
# Le script reçoit sur stdin le JSON de session décrit dans
# https://code.claude.com/docs/en/statusline et doit, quoi qu'il arrive,
# sortir 0 avec une ligne non vide : sinon Claude Code affiche une ligne vide.
#
# Lancement : bash tests/statusline.test.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/dot_claude/executable_statusline.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/statusline-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ESC=$(printf '\033')

# Sortie brute du script, code de sortie dans $STATUS.
run_raw() {
  OUT=$(printf '%s' "$1" | sh "$SCRIPT")
  STATUS=$?
}

# Sortie sans les séquences de couleur, pour les assertions sur le texte.
run() {
  run_raw "$1"
  TEXT=$(printf '%s' "$OUT" | sed "s/${ESC}\[[0-9;]*m//g")
}

ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n       sortie : %s\n' "$1" "$2"; }

contains()     { case "$TEXT" in *"$2"*) ok "$1" ;; *) ko "$1" "$TEXT" ;; esac; }
not_contains() { case "$TEXT" in *"$2"*) ko "$1" "$TEXT" ;; *) ok "$1" ;; esac; }
raw_contains() { case "$OUT" in *"$2"*) ok "$1" ;; *) ko "$1" "$OUT" ;; esac; }
raw_not_contains() { case "$OUT" in *"$2"*) ko "$1" "$OUT" ;; *) ok "$1" ;; esac; }
exits_zero()   { [ "$STATUS" -eq 0 ] && ok "$1" || ko "$1" "code $STATUS"; }
non_empty()    { [ -n "$TEXT" ] && ok "$1" || ko "$1" "(vide)"; }

json() { # json <cwd> <used_percentage JSON>
  printf '{"model":{"display_name":"Opus 5.5"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":%s},"session_id":"test"}' "$1" "$2"
}

BRANCH_GLYPH=$(printf '\356\202\240')
SEP=$(printf '\356\202\260')

# Dépôts de test isolés de la config git de l'utilisateur (hooksPath, signature…).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# Dépôts de test : propre, modifié, HEAD détachée ; plus un dossier hors dépôt.
git_repo() {
  mkdir -p "$1"
  git -C "$1" init -q -b feature-x
  printf 'a\n' > "$1/f"
  git -C "$1" add f
  git -C "$1" -c user.name=t -c user.email=t@t commit -q -m init
}
git_repo "$WORK/propre"
git_repo "$WORK/modifie";  printf 'b\n' >> "$WORK/modifie/f"
git_repo "$WORK/non-suivi"; printf 'n\n' > "$WORK/non-suivi/nouveau"
git_repo "$WORK/detache";  git -C "$WORK/detache" checkout -q --detach
SHA=$(git -C "$WORK/detache" rev-parse --short HEAD)
mkdir -p "$WORK/hors-depot" "$WORK/home" "$WORK/propre/sous/dossier"
# Un dossier hors dépôt dont le nom ne diffère du dépôt que par une espace finale.
mkdir -p "$WORK/propre "

echo "Modèle et contexte"
run "$(json "$WORK/hors-depot" 42)"
exits_zero   "sort 0 sur une entrée complète"
contains     "affiche le nom du modèle"            "Opus 5.5"
contains     "affiche le pourcentage de contexte"  "42%"
run "$(json "$WORK/hors-depot" 41.6)"
contains     "arrondit un pourcentage flottant"    "42%"
run "$(json "$WORK/hors-depot" null)"
contains     "contexte null : marqueur --"         "--"
not_contains "contexte null : jamais 0%"           "0%"
run '{"model":{"display_name":"Opus 5.5"},"workspace":{"current_dir":"/"}}'
exits_zero   "sort 0 sans context_window"
contains     "context_window absent : marqueur --" "--"
not_contains "context_window absent : jamais 0%"   "0%"
run "$(json "$WORK/hors-depot" 1e30)"
contains     "pourcentage hors 0-100 : marqueur --" "--"
run '{"model":{"display_name":""},"workspace":{"current_dir":"/"}}'
contains     "nom de modèle vide : repli ?"        "?"
run '{"workspace":{"current_dir":"/"}}'
contains     "modèle absent : repli ?"             "?"
run "$(printf '{"model":{"display_name":"A\\nB"},"workspace":{"current_dir":"%s"},"context_window":{"used_percentage":90}}' "$WORK/hors-depot")"
contains     "saut de ligne dans le modèle : pas de décalage" "90%"
not_contains "saut de ligne dans le modèle : pas de B%" "B%"

echo "Couleur du contexte selon le seuil"
run_raw "$(json "$WORK/hors-depot" 30)"
raw_contains     "moins de 50 % : fond vert"       "${ESC}[30;42m"
raw_not_contains "moins de 50 % : pas de fond rouge" "${ESC}[30;41m"
run_raw "$(json "$WORK/hors-depot" 49)"
raw_contains     "49 % : encore vert"              "${ESC}[30;42m"
run_raw "$(json "$WORK/hors-depot" 50)"
raw_contains     "50 % : jaune"                    "${ESC}[30;43m"
raw_not_contains "50 % : plus vert"                "${ESC}[30;42m"
run_raw "$(json "$WORK/hors-depot" 79)"
raw_contains     "79 % : encore jaune"             "${ESC}[30;43m"
raw_not_contains "79 % : pas encore rouge"         "${ESC}[30;41m"
run_raw "$(json "$WORK/hors-depot" 80)"
raw_contains     "80 % : rouge"                    "${ESC}[30;41m"
raw_not_contains "80 % : plus jaune"               "${ESC}[30;43m"
run_raw "$(json "$WORK/hors-depot" 85)"
raw_contains     "80 % et plus : fond rouge"       "${ESC}[30;41m"
raw_not_contains "80 % et plus : pas de fond vert" "${ESC}[30;42m"

echo "Dossier"
run "$(json "$WORK/hors-depot" 10)"
contains     "affiche le nom du dossier courant"   "hors-depot"
not_contains "n'affiche pas le chemin complet"     "$WORK"
HOME="$WORK/home" run "$(json "$WORK/home" 10)"
contains     "le HOME s'affiche ~"                 "~"
not_contains "le HOME ne s'affiche pas en clair"   "home"
HOME="$WORK/home" run "$(json "$WORK/home/" 10)"
contains     "le HOME avec slash final s'affiche ~" "~"
run '{"cwd":"'"$WORK/hors-depot"'"}'
contains     "repli sur .cwd sans workspace"       "hors-depot"
run "$(printf '{"workspace":{"current_dir":"%s"}}' "$WORK/a$(printf '\\u001b')[31mROUGE")"
raw_not_contains "caractère de contrôle du chemin : jamais transmis" "${ESC}[31m"

echo "Git"
run "$(json "$WORK/propre" 10)"
contains     "affiche la branche"                  "feature-x"
contains     "affiche le glyphe de branche"        "$BRANCH_GLYPH"
run "$(json "$WORK/propre/sous/dossier" 10)"
contains     "sous-dossier d'un dépôt : branche"   "feature-x"
run "$(json "$WORK/propre " 10)"
not_contains "espace finale : pas la branche du voisin" "feature-x"
not_contains "arbre propre : pas d'astérisque"     "feature-x*"
run "$(json "$WORK/modifie" 10)"
contains     "arbre modifié : astérisque"          "feature-x*"
# Choix : seuls les fichiers suivis comptent (status -uno, rapide sur un gros dépôt).
run "$(json "$WORK/non-suivi" 10)"
contains     "fichier non suivi seul : branche"    "feature-x"
not_contains "fichier non suivi seul : pas d'astérisque" "feature-x*"
run "$(json "$WORK/detache" 10)"
contains     "HEAD détachée : SHA court"           "$SHA"
run "$(json "$WORK/hors-depot" 10)"
not_contains "hors dépôt : pas de segment git"     "$BRANCH_GLYPH"

echo "Style"
run_raw "$(json "$WORK/propre" 10)"
raw_contains     "séparateur powerline présent"    "$SEP"
case "$OUT" in *"$SEP${ESC}[0m") ok "flèche finale avant le reset" ;; *) ko "flèche finale avant le reset" "$OUT" ;; esac
for seq in "38;5;" "48;5;" "38;2;" "48;2;"; do
  raw_not_contains "16 couleurs seulement : pas de ${seq}" "${ESC}[${seq}"
done
case "$OUT" in *"${ESC}[9"[0-7]*|*"${ESC}[10"[0-7]*) ko "pas de couleurs vives 90-107" "$OUT" ;; *) ok "pas de couleurs vives 90-107" ;; esac

echo "Robustesse"
run_raw "$(json "$WORK/hors-depot" 10)"
case "$OUT" in *"${ESC}[0m") ok "termine par un reset des couleurs" ;; *) ko "termine par un reset des couleurs" "$OUT" ;; esac
run "ceci n'est pas du JSON"
exits_zero   "entrée illisible : sort 0"
non_empty    "entrée illisible : affiche quelque chose"
# PATH réduit à git seul : jq introuvable.
mkdir -p "$WORK/bin"; ln -s "$(command -v git)" "$WORK/bin/git"
OUT=$(printf '%s' "$(json "$WORK/propre" 10)" | PATH="$WORK/bin" /bin/sh "$SCRIPT"); STATUS=$?
TEXT=$OUT
exits_zero   "sans jq : sort 0"
contains     "sans jq : le signale"                "jq manquant"

printf '\n%d ok, %d échec(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
