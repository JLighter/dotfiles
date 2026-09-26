#!/usr/bin/env bash
# Amène l'environnement à un état connu. Idempotent. Sort en erreur si le smoke test échoue.
set -euo pipefail
cd "$(dirname "$0")"

# 1. Dépendances (adapter à la stack)
[ -f package.json ] && npm ci --silent

# 2. Services (adapter : base de données, serveur de dev)
# docker compose up -d db
# npm run dev > .dev.log 2>&1 &

# 3. Smoke test : la plus petite vérification qui prouve que l'environnement tourne
# curl -sf http://localhost:3000/health > /dev/null
echo "init.sh : environnement prêt"
