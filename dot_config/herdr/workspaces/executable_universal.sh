#!/bin/zsh
# Espace de travail « universal » — équivalent herdr de tmuxinator universal.yml
# (~/.config/tmuxinator/universal.yml). Lancer depuis n'importe où, herdr
# server actif : ~/.config/herdr/workspaces/universal.sh
set -euo pipefail

ROOT="$HOME/Documents/Working/Universal/universal-music-pitch-it"
FRONT="$ROOT/front-angular"
BACK="$ROOT/back-node"

# ── Onglet front-angular : vim en haut, ng serve en bas ──────────────
created=$(herdr workspace create --cwd "$FRONT" --label universal --focus)
ws=$(echo "$created" | jq -r '.result.workspace.workspace_id')
tab1=$(echo "$created" | jq -r '.result.tab.tab_id')
p_vim_front=$(echo "$created" | jq -r '.result.root_pane.pane_id')
herdr tab rename "$tab1" front-angular > /dev/null

p_serve=$(herdr pane split "$p_vim_front" --direction down --ratio 0.7 \
  | jq -r '.result.pane.pane_id')
herdr pane run "$p_vim_front" vim . > /dev/null
herdr pane run "$p_serve" ng serve > /dev/null

# ── Onglet back-node : vim en haut, build:watch + docker en bas ──────
tab2_created=$(herdr tab create --workspace "$ws" --cwd "$BACK" --label back-node --no-focus)
p_vim_back=$(echo "$tab2_created" | jq -r '.result.root_pane.pane_id')

p_watch=$(herdr pane split "$p_vim_back" --direction down --ratio 0.7 \
  | jq -r '.result.pane.pane_id')
p_docker=$(herdr pane split "$p_watch" --direction right --ratio 0.5 \
  | jq -r '.result.pane.pane_id')
herdr pane run "$p_vim_back" vim . > /dev/null
herdr pane run "$p_watch" npm run build:watch > /dev/null
herdr pane run "$p_docker" docker compose up > /dev/null

echo "Workspace universal créé ($ws) : front-angular + back-node"
