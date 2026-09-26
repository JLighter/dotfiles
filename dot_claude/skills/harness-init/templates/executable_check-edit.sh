#!/usr/bin/env bash
# PostToolUse sur Edit|Write : vérifie le seul fichier modifié.
# Silencieux si tout passe. Échecs sur stderr + exit 2 : seul ce contrat les rend visibles à Claude.
# Adapter les deux commandes à la stack (ruff/mypy, eslint/tsc, cargo clippy, ktlint…).
f=$(jq -r '.tool_input.file_path // empty')
[[ "$f" == *.ts || "$f" == *.tsx ]] || exit 0
rel=${f#"$CLAUDE_PROJECT_DIR"/}
out=$( { npx tsc --noEmit --incremental 2>&1 | grep -F "$rel"
         npx eslint "$f" --format unix 2>&1; } | head -20 )
[ -z "$out" ] && exit 0
echo "$out" >&2
exit 2
