#!/bin/bash
# Script généré pour la procédure : Gestion des Pools PgBouncer
# Document source : documentation/procedures/pgbouncer/pools.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

# Note: check_etcdctl est appelé dans common.sh, mais ici nous utilisons psql/docker.
# On pourrait ajouter une fonction check_psql dans common.sh à l'avenir.

log_info "Début de la procédure : Gestion des Pools PgBouncer"

# 1. Afficher les statistiques des pools
log_info "Étape 1 : Affichage des statistiques des pools"
# Alternative SSH : ssh ${PGBOUNCER_HOST} "psql -U postgres -p 6432 -h localhost -c 'SHOW POOLS' pgbouncer"
docker exec -i pgbouncer psql -U postgres -p 6432 -h localhost -c "SHOW POOLS" pgbouncer

# 2. Forcer le rechargement de la configuration
log_info "Étape 2 : Rechargement de la configuration"
# Alternative SSH : ssh ${PGBOUNCER_HOST} "psql -U postgres -p 6432 -h localhost -c 'RELOAD' pgbouncer"
docker exec -i pgbouncer psql -U postgres -p 6432 -h localhost -c "RELOAD" pgbouncer

log_info "✅ Procédure terminée avec succès"
