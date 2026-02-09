#!/bin/bash
# scripts/tests/test_replication_scenario.sh
# End-to-end replication test: Create, Insert, Wait, Verify, Drop, Verify.
# To be executed through HAProxy and PgBouncer.

set -euo pipefail

# Source environment and utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PARENT_DIR"

if [ -f .env ]; then
    source .env
fi
source scripts/tests/test_utils.sh

# Use local certs for host-side psql
export PGSSLMODE=require
export PGSSLCERT="./certs/postgresql-client.crt"
export PGSSLKEY="./certs/postgresql-client.key"
export PGSSLROOTCERT="./certs/ca.crt"
export PGPASSWORD="${POSTGRES_PASSWORD}"

# Helper to run the scenario
# Usage: run_scenario "Label" "RW_HOST" "RW_PORT" "RO_HOST" "RO_PORT" "RW_DB" "RO_DB"
run_scenario() {
    local label="$1"
    local rw_host="$2"
    local rw_port="$3"
    local ro_host="$4"
    local ro_port="$5"
    local rw_db="$6"
    local ro_db="$7"

    # On utilise les variables d'environnement explicites pour docker exec
    local psql_cmd="docker exec -e PGSSLMODE=require -e PGSSLCERT=/certs/postgresql-client.crt -e PGSSLKEY=/certs/postgresql-client.key -e PGSSLROOTCERT=/certs/ca.crt -e PGPASSWORD=${POSTGRES_PASSWORD} node1 psql"

    # 1. Nettoyage initial (si nécessaire)
    $psql_cmd -h "$rw_host" -p "$rw_port" -U postgres -d "$rw_db" -c "DROP TABLE IF EXISTS test_replication;" >/dev/null 2>&1 || true

    # 2. Création de la table sur le Primaire
    run_test "[$label] Création de la table test_replication" \
        "$psql_cmd -h $rw_host -p $rw_port -U postgres -d $rw_db -c \"CREATE TABLE test_replication (id serial PRIMARY KEY, val text);\""

    # 3. Insertion de 10 lignes
    run_test "[$label] Insertion de 10 lignes" \
        "for i in {1..10}; do $psql_cmd -h $rw_host -p $rw_port -U postgres -d $rw_db -c \"INSERT INTO test_replication (val) VALUES ('data_\$i');\" >/dev/null; done"

    # 4. Attente de 2 secondes pour la réplication
    echo -n "   ⏳ Attente de 2 secondes... "
    sleep 2
    echo "OK"

    # 5. Lecture sur les Replicas
    run_test "[$label] Vérification des 10 lignes sur les Réplicas" \
        "RES=\$($psql_cmd -h $ro_host -p $ro_port -U postgres -d $ro_db -t -c 'SELECT count(*) FROM test_replication;' | tr -d ' '); [ \"\$RES\" == \"10\" ]"

    # 6. Suppression de la table sur le Primaire
    run_test "[$label] Suppression de la table" \
        "$psql_cmd -h $rw_host -p $rw_port -U postgres -d $rw_db -c 'DROP TABLE test_replication;'"

    # 7. Vérification finale sur les Réplicas
    run_test "[$label] Vérification de la non-présence sur les Réplicas" \
        "! $psql_cmd -h $ro_host -p $ro_port -U postgres -d $ro_db -c 'SELECT 1 FROM test_replication;' >/dev/null 2>&1"
}

# --- EXÉCUTION ---

# TEST 1: Via HAProxy directement (Utilisation des noms de conteneurs et ports internes)
run_scenario "HAProxy Direct" "haproxy" "${INT_HAPROXY_RW_PORT}" "haproxy" "${INT_HAPROXY_RO_PORT}" "postgres" "postgres"

# TEST 2: Via PgBouncer
run_scenario "PgBouncer" "pgbouncer" "${INT_PGBOUNCER_PORT}" "pgbouncer" "${INT_PGBOUNCER_PORT}" "postgres_rw" "postgres_ro"

# Final Summary
print_summary "Scénario de Réplication"
