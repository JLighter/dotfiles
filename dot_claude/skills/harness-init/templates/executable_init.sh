#!/usr/bin/env bash
# Amène un clone à un état connu, sur un poste comme en CI ($CI non vide). Idempotent.
# Sort en 1 avec un message si un outil manque, si une étape échoue ou si le smoke test échoue.
#   ./init.sh               tout
#   ./init.sh --hooks-only  hooks git seulement (script prepare d'un projet Node ; n'appelle jamais npm)
set -euo pipefail
cd "$(dirname "$0")"

# Outils de la stack : exigés partout, CI comprise (adapter : node npm, python3 uv, cargo…).
STACK_TOOLS=(git)
# Outils de poste : hooks Claude Code et pre-commit, jamais exigés en CI.
DEV_TOOLS=(jq pre-commit)

fail() { echo "init.sh : $*" >&2; exit 1; }

# $1 = options de pre-commit install ; renvoie 1 avec le message de pre-commit sur stderr.
# Chaque commande porte son || return 1 : appelée avec ||, la fonction ne profite pas de set -e.
install_hooks() {
  [ -n "${CI:-}" ] && return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  if [ -n "$(git config --get core.hooksPath || true)" ]; then
    echo "init.sh : core.hooksPath est défini ($(git config --get core.hooksPath)) ; pre-commit refuse d'installer ses hooks. Lever avec : git config --unset core.hooksPath" >&2
    return 1
  fi
  pre-commit install $1 >/dev/null || return 1
  pre-commit install --hook-type commit-msg >/dev/null || return 1
}

if [ "${1:-}" = "--hooks-only" ]; then
  # Appelé pendant npm install : avertir sans casser l'installation.
  if [ -z "${CI:-}" ] && ! command -v pre-commit >/dev/null; then
    echo "init.sh : pre-commit absent, hooks git non installés. Lancer ./init.sh." >&2
    exit 0
  fi
  install_hooks "" || echo "init.sh : hooks git non installés. Lancer ./init.sh." >&2
  exit 0
fi

missing=()
for t in "${STACK_TOOLS[@]}"; do command -v "$t" >/dev/null || missing+=("$t"); done
if [ -z "${CI:-}" ]; then
  for t in "${DEV_TOOLS[@]}"; do command -v "$t" >/dev/null || missing+=("$t"); done
fi
[ "${#missing[@]}" -eq 0 ] || fail "outils manquants : ${missing[*]}"

# Dépendances (adapter). En CI, npm ci déclenche prepare, qui ne fait rien puisque $CI est posé.
if [ -f package.json ]; then
  [ -f package-lock.json ] || fail "package-lock.json absent : le créer avec npm install, puis le committer"
  npm ci --no-audit --no-fund || fail "npm ci a échoué (voir ci-dessus)"
fi

# Documentation en wiki de forge (variante wiki seulement). Le wiki n'existe qu'après sa première page.
# if [ -z "${CI:-}" ]; then
#   if [ -d .wiki ]; then git -C .wiki pull -q; else git clone -q <url>.wiki.git .wiki \
#     || fail "wiki introuvable : créer sa première page dans l'interface de la forge"; fi
# fi

# --install-hooks prépare aussi l'environnement de chaque hook (gitleaks) : le premier commit ne télécharge plus rien.
install_hooks --install-hooks || fail "hooks git non installés"

# Smoke test : la plus petite vérification qui prouve que l'environnement tourne.
# Pas de processus long ici : il resterait orphelin en CI.
# npm run build --silent || fail "build en échec"
echo "init.sh : environnement prêt"
