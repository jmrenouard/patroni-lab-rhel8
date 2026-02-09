#!/bin/bash
# cleanup_simple.sh
# Nettoyage simple : supprime les conteneurs, volumes et réseaux.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🗑️  Nettoyage simple (conteneurs, volumes, réseaux)..."

cd "$PROJECT_ROOT"
if [ -f "docker-compose.yml" ]; then
    docker compose down -v
else
    echo "⚠️  docker-compose.yml non trouvé dans $PROJECT_ROOT"
fi

echo "✅ Nettoyage simple terminé."
