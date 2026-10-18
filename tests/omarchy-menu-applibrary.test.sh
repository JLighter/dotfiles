#!/bin/bash
# Repli AppLibrary du plugin local.menu (UPSTREAM.md, « Couche 3 »).
#
# Omarchy 4.0.4/4.0.5 donne appLibrary null aux menus tiers
# (omacom/omarchy#15360) : local.menu charge alors une copie de
# shell/services/AppLibrary.qml et AppSearch.js. Ce test vérifie que :
#   - la copie se charge dès que l'hôte ne fournit rien ;
#   - les copies restent conformes à celles de l'Omarchy installé ;
#   - le repli disparaît quand l'hôte est corrigé (PR omacom/omarchy#15692) :
#     l'échec dit alors de retirer la couche.
#
# Les deux derniers points lisent l'Omarchy installé et sont sautés sans lui.
#
# Lancement : bash tests/omarchy-menu-applibrary.test.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MENU="$ROOT/dot_config/omarchy/plugins/local.menu"
HOST="${OMARCHY_PATH:-/usr/share/omarchy}/shell"

PASS=0
FAIL=0
SKIP=0

ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
ko() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n%s\n' "$1" "$2"; }
skip() { SKIP=$((SKIP + 1)); printf 'skip %s\n' "$1"; }

# --- Sélection dans Menu.qml ---------------------------------------------------

if grep -qP '^\s*readonly property var appLibrary: hostAppLibrary \|\| localAppLibrary\.item\s*$' "$MENU/Menu.qml"; then
  ok "Menu.qml : la bibliothèque de l'hôte prime sur la copie"
else
  ko "Menu.qml : la bibliothèque de l'hôte prime sur la copie" "  liaison appLibrary introuvable"
fi

# La copie ne doit pas attendre l'injection de shell : sous 4.0.5, shell vaut
# encore null quand le menu s'ouvre, et la liste Apps reste vide (constaté le
# 2026-10-18 avec `active: !!root.shell && …`).
if grep -qP '^\s*active: !root\.hostAppLibrary\s*$' "$MENU/Menu.qml"; then
  ok "Menu.qml : la copie se charge dès que l'hôte ne fournit rien, sans attendre shell"
else
  ko "Menu.qml : la copie se charge dès que l'hôte ne fournit rien, sans attendre shell" \
    "  attendu : active: !root.hostAppLibrary"
fi

# --- Conformité à l'Omarchy installé -------------------------------------------

if [[ ! -f $HOST/shell.qml ]]; then
  skip "copies conformes à l'hôte (Omarchy absent)"
  skip "hôte encore bogué (Omarchy absent)"
else
  for f in AppLibrary.qml AppSearch.js; do
    if cmp -s "$MENU/$f" "$HOST/services/$f"; then
      ok "$f : copie conforme à $HOST/services/$f"
    else
      ko "$f : copie conforme à $HOST/services/$f" \
        "  l'hôte a changé : recopier le fichier (UPSTREAM.md, Couche 3)"
    fi
  done

  # Le bug : manifestHasKind teste Array.isArray(manifest.kinds). La PR #15692
  # le remplace par Util.manifestHasKind, qui accepte les séquences QML.
  if grep -qF 'Array.isArray(manifest.kinds)' "$HOST/shell.qml" \
     && ! grep -qF 'Util.manifestHasKind' "$HOST/shell.qml"; then
    ok "hôte encore bogué : le repli reste nécessaire"
  else
    ko "hôte encore bogué : le repli reste nécessaire" \
      "  l'hôte semble corrigé : retirer la couche 3 (voir UPSTREAM.md)"
  fi
fi

printf '\n%d ok, %d échec(s), %d sauté(s)\n' "$PASS" "$FAIL" "$SKIP"
(( FAIL == 0 ))
