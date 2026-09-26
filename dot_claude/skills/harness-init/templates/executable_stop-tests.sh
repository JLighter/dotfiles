#!/usr/bin/env bash
# Stop : refuse la fin de tour tant que la suite unitaire échoue.
# Garde : trois relances au plus par session, puis l'humain reprend. Compteur remis à zéro au succès.
input=$(cat); sid=$(jq -r .session_id <<<"$input")
c="${TMPDIR:-/tmp}/stop-$sid"; n=$(cat "$c" 2>/dev/null || echo 0)
[ "$n" -ge 3 ] && { rm -f "$c"; exit 0; }
fails=$(npm test --silent 2>&1 | grep -E 'FAIL|✕|Error' | head -15)
[ -z "$fails" ] && { rm -f "$c"; exit 0; }
echo $((n+1)) > "$c"
printf 'Tests en échec, tâche non terminée :\n%s\n' "$fails" >&2
exit 2
