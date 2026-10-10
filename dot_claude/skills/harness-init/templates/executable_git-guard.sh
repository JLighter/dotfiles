#!/usr/bin/env bash
# PreToolUse sur Bash : refuse les commandes git qui sautent les hooks git (--no-verify, commit -n, core.hooksPath forcé)
# ou qui réécrivent l'historique distant (push --force ou -f ; --force-with-lease reste permis).
# Une règle deny de permissions ne suffit pas : elle ne filtre pas les drapeaux d'une commande.
# Garde-fou pour l'agent, pas barrière : un humain passe outre. La barrière est la CI et la protection de branche.
# Les chaînes entre guillemets (messages de commit) sont retirées : un « -n » dans un message n'est pas un drapeau.
cmd=$(jq -r '.tool_input.command // empty' | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
grep -qE '(^|[;&|(]|[[:space:]])git[[:space:]]' <<<"$cmd" || exit 0
refuse() { echo "Refusé : $1" >&2; exit 2; }
grep -qE -- '--no-verify|core\.hooksPath' <<<"$cmd" \
  && refuse "les hooks git (gitleaks, message de commit) ne se sautent pas. Corriger la cause signalée par le hook."
grep -qE -- 'commit([[:space:]].*)?[[:space:]]-[A-Za-z]*n[A-Za-z]*([[:space:]]|$)' <<<"$cmd" \
  && refuse "commit -n saute les hooks git. Corriger la cause signalée par le hook."
grep -qE -- 'push([[:space:]].*)?[[:space:]](--force([[:space:]]|$)|-[A-Za-z]*f[A-Za-z]*([[:space:]]|$))' <<<"$cmd" \
  && refuse "push forcé. Demander à l'humain, ou utiliser --force-with-lease sur une branche personnelle."
exit 0
