#!/usr/bin/env bash
# Hook SessionStart : sa sortie est ajoutée au contexte. Rester court.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f features.json ] || exit 0

echo "## État du projet (injecté par le hook SessionStart)"
python3 - <<'PY'
import json
f = json.load(open("features.json"))
done = sum(1 for x in f if x.get("passes"))
todo = sorted((x for x in f if not x.get("passes")), key=lambda x: x.get("priority", 99))
print(f"Fonctionnalités : {done}/{len(f)} terminées.")
if todo:
    n = todo[0]
    print(f"Prochaine : {n['id']} — {n['description']}")
PY
echo
echo "### Dernière session"
awk '/^## Session/{n++} n==1' claude-progress.md 2>/dev/null | head -15
echo
echo "### Derniers commits"
git log --oneline -8 2>/dev/null
echo
echo "Suivre le skill reprise : ouverture, une seule fonctionnalité, clôture."
