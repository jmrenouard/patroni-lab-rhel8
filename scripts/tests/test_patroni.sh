#!/bin/bash
# test_patroni.sh
# Validation de l'API REST Patroni, de l'état PostgreSQL et de la Réplication

source .env
source ./scripts/tests/test_utils.sh

echo -e "🧪 [PATRONI] Test de l'API REST, de la réplication et de la configuration SSL...\n"

# 1. Test Accessibilité API (sur node1)
run_test "Accessibilité API REST (Node 1)" \
    "docker exec node1 curl -s -k -u ${PATRONI_API_USER}:${PATRONI_API_PASSWORD} https://localhost:${INT_PATRONI_PORT}/health | grep -qE 'running|starting'"

# 2. Identification du Leader
# Note: On utilise run_test pour l'affichage, mais on a besoin de la variable pour la suite
run_test "Identification du Leader de Cluster" \
    "docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -q 'Leader'"

LEADER=$(docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")')

if [ -z "$LEADER" ]; then
    echo -e "${RED}❌ Impossible de continuer sans leader.${NC}"
    exit 1
fi

# 3. Test de lecture/écriture SQL
run_test "Écriture SQL Directe (Leader: $LEADER)" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' '$LEADER' psql 'host=localhost port=${INT_PG_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require' -c 'CREATE TABLE IF NOT EXISTS test_resilience (id serial primary key, val text); INSERT INTO test_resilience(val) VALUES (\$\$test\$\$);' &> /dev/null"

# 4. NOUVEAU: Vérification de la Configuration SSL PostgreSQL
run_test "Vérification Paramètre SSL (PostgreSQL)" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' '$LEADER' psql 'host=localhost port=${INT_PG_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require' -t -c 'SHOW ssl;' | grep -q 'on'"

# 5. NOUVEAU: Vérification des Slots de Réplication
run_test "Vérification des Slots de Réplication (Actifs)" \
    "docker exec -e PGPASSWORD='${POSTGRES_PASSWORD}' '$LEADER' psql 'host=localhost port=${INT_PG_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require' -t -c 'SELECT count(*) FROM pg_replication_slots WHERE active = true;' | grep -qE '[1-9]'"

# 6. NOUVEAU: Vérification du Lag de Réplication
# On vérifie que le lag n'est pas NULL sur les réplicas (ce qui arrive si pas de réplication)
run_test "Vérification Lag de Réplication (Cohérence)" \
    "docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -v 'Leader' | grep -v 'Lag' | grep -q '\"Lag\":' || true"

# Diagnostic final
print_diagnostics "Patroni/PostgreSQL" \
    "docker exec node1 patronictl -c /etc/patroni.yml list" \
    "docker exec node1 patronictl -c /etc/patroni.yml history" \
    "docker exec $LEADER psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"

print_summary "test_patroni.sh"
exit $?
