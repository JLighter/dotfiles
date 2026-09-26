#!/usr/bin/env python3
"""Pre-commit : dans features.json, seul le champ `passes` peut changer.
Un humain qui modifie volontairement la liste committe avec --no-verify,
interdit à l'agent par les permissions du projet."""
import json, subprocess, sys

def load(ref):
    try:
        raw = subprocess.run(["git", "show", ref], capture_output=True, text=True, check=True).stdout
        return json.loads(raw)
    except subprocess.CalledProcessError:
        return None

staged = subprocess.run(["git", "diff", "--cached", "--name-only"], capture_output=True, text=True).stdout.split()
if "features.json" not in staged:
    sys.exit(0)

before, after = load("HEAD:features.json"), load(":features.json")
if before is None:
    sys.exit(0)  # premier commit de la liste

strip = lambda l: {x["id"]: {k: v for k, v in x.items() if k != "passes"} for x in l}
b, a = strip(before), strip(after)
errors = [f"{i} supprimée" for i in b if i not in a]
errors += [f"{i} ajoutée" for i in a if i not in b]
errors += [f"{i} modifiée hors passes" for i in b if i in a and a[i] != b[i]]
if errors:
    print("features.json : seul le champ passes peut changer.\n" + "\n".join(errors), file=sys.stderr)
    sys.exit(1)
