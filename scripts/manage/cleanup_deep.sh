#!/bin/bash
# cleanup_deep.sh
# Nettoyage profond : suppression des images et des assets générés.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧨 Nettoyage profond en cours..."

# 1. Nettoyage simple d'abord
"$SCRIPT_DIR/cleanup_simple.sh"

echo "🧹 Suppression des images Docker du projet..."
# Liste des images du projet définies dans le Makefile ou docker-compose
IMAGES=(
    "patroni-rhel8-base"
    "patroni-rhel8-etcd"
    "patroni-rhel8-postgresql"
    "patroni-rhel8-haproxy"
    "patroni-rhel8-pgbouncer"
    "patroni-rhel8" # Ancienne version potentielle
    "haproxy"       # Ancienne version potentielle
)

for img in "${IMAGES[@]}"; do
    if docker image inspect "$img:latest" >/dev/null 2>&1; then
        echo "Removing image $img:latest"
        docker rmi "$img:latest" || true
    fi
done

echo "📂 Suppression des assets générés..."
cd "$PROJECT_ROOT"
rm -rf ssh/ certs/ reports/ rpms_urls.txt wheels/ build.log
mkdir -p reports/

echo "✨ Nettoyage profond terminé."
