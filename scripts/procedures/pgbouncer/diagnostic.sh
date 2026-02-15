#!/bin/bash
# Script généré pour la procédure : Diagnostic de Santé PgBouncer
# Document source : documentation/procedures/pgbouncer/diagnostic.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Diagnostic de Santé PgBouncer"

# 1. Connexion à la console d'administration
log_info "Étape 1 : Vérification de la console d'administration (SHOW CONFIG)"
# Alternative SSH : ssh ${PGBOUNCER_HOST} "psql -U postgres -p 6432 -h localhost -c 'SHOW CONFIG' pgbouncer"
docker exec -i pgbouncer psql -U postgres -p 6432 -h localhost -c "SHOW CONFIG" pgbouncer || log_warn "Échec de connexion à la console PgBouncer"

# 3. Test de connectivité applicative
log_info "Étape 3 : Test de connectivité applicative (postgres_rw)"
# Note: psql doit être installé localement.
if command -v psql &> /dev/null; then
    psql "host=localhost port=6432 dbname=postgres_rw user=postgres" -c "SELECT now();" || log_warn "Échec de connexion au pool postgres_rw"
else
    log_warn "psql n'est pas installé, test de connexion ignoré."
fi

# 4. Analyse des logs (Rappel)
log_info "Note : Pour l'analyse des logs en temps réel, exécutez :"
log_info "docker logs pgbouncer -f"

log_info "✅ Diagnostic PgBouncer terminé"
