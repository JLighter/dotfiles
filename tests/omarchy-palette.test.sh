#!/bin/bash
# Garde-fou : les plugins omarchy-shell versionnés lisent la palette par
# `Commons.Color`, jamais par `Color` nu.
#
# Depuis Qt 6.12, QtQuick exporte son propre singleton `Color` (QQuickColor).
# Dans un fichier qui importe QtQuick et qs.Commons, le nom `Color` désigne
# celui de Qt : `Color.bar`, `Color.tooltip`… valent undefined et le shell
# peint en noir. Correctif upstream : omacom/omarchy#14553, qui importe
# `qs.Commons as Commons` et qualifie chaque référence.
#
# Lancement : bash tests/omarchy-palette.test.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLUGINS="$ROOT/dot_config/omarchy/plugins"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-palette-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n%s\n' "$1" "$2"; }

# Références nues au singleton : le mot `Color` non précédé d'un identifiant ou
# d'un point, suivi ou non d'un accès (`Color.bar`, `target: Color`). Ignore les
# lignes de commentaire et la mention du fichier Color.qml.
unqualified() { # <fichier>...
  grep -nHP '^(?!\s*//).*(?<![\w.])Color\b(?!\.qml\b)' "$@"
}

# Un fichier qui écrit `Commons.Color` doit déclarer l'espace de noms.
missing_alias() { # <fichier>...
  local f
  for f in "$@"; do
    grep -qP '(?<![\w.])Commons\.Color\b' "$f" || continue
    grep -qP '^\s*import\s+qs\.Commons\s+as\s+Commons\s*$' "$f" || echo "$f"
  done
}

# --- Le détecteur lui-même (négatif d'abord : il doit voir le défaut) -------

cat >"$WORK/Bare.qml" <<'EOF'
import QtQuick
import qs.Commons
Item { property color c: Color.bar.text }
EOF
cat >"$WORK/BareValue.qml" <<'EOF'
import QtQuick
import qs.Commons
Item { Connections { target: Color } }
EOF
cat >"$WORK/Qualified.qml" <<'EOF'
import QtQuick
import qs.Commons
import qs.Commons as Commons
// Lié à la section [menu] via Color.qml.
Item {
  property color c: Commons.Color.bar.text
  property color d: borderColor.darker
  Behavior on c { ColorAnimation { duration: 100 } }
}
EOF
cat >"$WORK/NoAlias.qml" <<'EOF'
import QtQuick
import qs.Commons
Item { property color c: Commons.Color.bar.text }
EOF

if [[ -n $(unqualified "$WORK/Bare.qml") ]]; then
  ok "détecteur : signale Color.bar nu"
else
  ko "détecteur : signale Color.bar nu" "  aucune ligne signalée"
fi

if [[ -n $(unqualified "$WORK/BareValue.qml") ]]; then
  ok "détecteur : signale le singleton Color passé en valeur"
else
  ko "détecteur : signale le singleton Color passé en valeur" "  aucune ligne signalée"
fi

out=$(unqualified "$WORK/Qualified.qml")
if [[ -z $out ]]; then
  ok "détecteur : ignore Commons.Color, borderColor, ColorAnimation et Color.qml en commentaire"
else
  ko "détecteur : ignore Commons.Color, borderColor, ColorAnimation et Color.qml en commentaire" "$out"
fi

if [[ -n $(missing_alias "$WORK/NoAlias.qml") ]]; then
  ok "détecteur : signale Commons.Color sans import qs.Commons as Commons"
else
  ko "détecteur : signale Commons.Color sans import qs.Commons as Commons" "  aucun fichier signalé"
fi

if [[ -z $(missing_alias "$WORK/Qualified.qml") ]]; then
  ok "détecteur : accepte Commons.Color avec son import"
else
  ko "détecteur : accepte Commons.Color avec son import" "  fichier signalé à tort"
fi

# --- Les plugins versionnés ---------------------------------------------------

mapfile -t files < <(find "$PLUGINS" -type f \( -name '*.qml' -o -name '*.js' \) | sort)

if (( ${#files[@]} > 0 )); then
  ok "plugins : ${#files[@]} fichiers QML/JS trouvés"
else
  ko "plugins : fichiers QML/JS trouvés" "  aucun fichier sous $PLUGINS"
fi

out=$(unqualified "${files[@]}" | sed "s|^$ROOT/|  |")
if [[ -z $out ]]; then
  ok "plugins : aucune référence Color. nue"
else
  ko "plugins : aucune référence Color. nue" "$out"
fi

out=$(missing_alias "${files[@]}" | sed "s|^$ROOT/|  |")
if [[ -z $out ]]; then
  ok "plugins : chaque Commons.Color a son import qs.Commons as Commons"
else
  ko "plugins : chaque Commons.Color a son import qs.Commons as Commons" "$out"
fi

printf '\n%d ok, %d échec(s)\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
