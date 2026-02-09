#!/bin/bash
# test_haproxy.sh
# Validation de la couche Load Balancing (HAProxy) - Version Verbeuse

source .env
source ./scripts/tests/test_utils.sh

echo -e "🧪 [HAPROXY] Test de l'équilibrage de charge et de la santé des backends...\n"

# 1. Test Validité Configuration & Version
run_test "Vérification Configuration HAProxy" "docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg"
run_test "Vérification Version HAProxy" "docker exec haproxy haproxy -v | grep -q 'HAProxy version 3'"

# 2. Test Cluster Stats (HAProxy)
run_test "Accès API Stats (Port ${EXT_HAPROXY_STATS_PORT})" \
    "curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} https://localhost:${EXT_HAPROXY_STATS_PORT}/"

# 3. Test Écriture via HAProxy (RW)
run_test "Écriture SQL via RW (Port ${INT_HAPROXY_RW_PORT})" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' node1 psql 'host=haproxy port=${INT_HAPROXY_RW_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require' -c 'SELECT 1;' &> /dev/null"

# 4. Test Lecture via HAProxy (RO)
run_test "Lecture SQL via RO (Port ${INT_HAPROXY_RO_PORT})" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' node1 psql 'host=haproxy port=${INT_HAPROXY_RO_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require' -c 'SELECT 1;' &> /dev/null"

# 5. NOUVEAU: Vérification de l'état des Backends (via Stats CSV)
run_test "Vérification Santé Backend pg_primary (UP/Open)" \
    "curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} 'https://localhost:${EXT_HAPROXY_STATS_PORT}/;csv' | grep 'pg_primary,BACKEND,' | grep -q ',UP,'"

run_test "Vérification Santé Backend pg_replicas (UP/Open)" \
    "curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} 'https://localhost:${EXT_HAPROXY_STATS_PORT}/;csv' | grep 'pg_replicas,BACKEND,' | grep -q ',UP,'"

# Diagnostic final
print_diagnostics "HAProxy" \
    "docker exec haproxy haproxy -v" \
    "curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} 'https://localhost:${EXT_HAPROXY_STATS_PORT}/;csv' | cut -d',' -f1,2,18,19 | column -s',' -t"

print_summary "test_haproxy.sh"
exit $?
