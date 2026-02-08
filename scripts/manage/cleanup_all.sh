#!/bin/bash
# cleanup_all.sh
# Nettoyage complet de l'infrastructure.

echo "🗑️ Nettoyage de l'infrastructure..."

docker compose down -v
docker rmi patroni-rhel8:latest haproxy:latest patroni-rhel8-postgresql patroni-rhel8-etcd patroni-rhel8-base || true

echo "✅ Nettoyage terminé."
