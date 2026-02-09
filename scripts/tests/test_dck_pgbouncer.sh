#!/bin/bash
# test_dck_pgbouncer.sh
# Validation interne de PgBouncer - Version Verbeuse

source .env
source ./scripts/tests/test_utils.sh

echo -e "🐳 [DOCKER-TEST] PgBouncer Internal Verification (Pooling & Routing)\n"

# 1. État du process
run_test "Vérification État du Processus (PgBouncer)" \
    "docker exec pgbouncer ps aux | grep -v grep | grep -q 'pgbouncer'"

# 2. Test Connection Pooling (RW)
run_test "Routage via Pooler RW (Port ${INT_PGBOUNCER_PORT})" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' pgbouncer psql -h localhost -p ${INT_PGBOUNCER_PORT} -U ${POSTGRES_USER} -d postgres_rw -c 'SELECT 1;' &> /dev/null"

# 3. Test Connection Pooling (RO)
run_test "Routage via Pooler RO (Port ${INT_PGBOUNCER_PORT})" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' pgbouncer psql -h localhost -p ${INT_PGBOUNCER_PORT} -U ${POSTGRES_USER} -d postgres_ro -c 'SELECT 1;' &> /dev/null"

# 4. NOUVEAU: Vérification de la configuration rendue
run_test "Vérification Fichier de Configuration (Rendered)" \
    "docker exec pgbouncer ls -l /etc/pgbouncer/pgbouncer.ini"

# Diagnostic final
print_diagnostics "PgBouncer" \
    "docker exec pgbouncer pgbouncer --version" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' pgbouncer psql -h localhost -p ${INT_PGBOUNCER_PORT} -U pgbouncer -d pgbouncer -c 'SHOW STATS;'"

print_summary "test_dck_pgbouncer.sh"
exit $?
