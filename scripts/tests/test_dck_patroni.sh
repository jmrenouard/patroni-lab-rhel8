#!/bin/bash
# test_dck_patroni.sh
# Validation interne de Patroni et PostgreSQL - Version Verbeuse

source .env
source ./scripts/tests/test_utils.sh

echo -e "🐳 [DOCKER-TEST] Patroni/PG Internal Verification (Supervisor & Ports)\n"

# 1. État du process Supervisor
run_test "Vérification État du Processus (Supervisord)" \
    "docker exec node1 ps aux | grep -v grep | grep -q 'supervisord'"

# 2. Vérification des ports d'écoute
run_test "Vérification Écoute Port PostgreSQL (5432)" "docker exec node1 netstat -tunl | grep -q ':5432 '"
run_test "Vérification Écoute Port Patroni API (8008)" "docker exec node1 netstat -tunl | grep -q ':8008 '"

# 3. Log Error Check
run_test "Vérification des erreurs critiques dans les logs Patroni" \
    "! docker exec node1 tail -n 50 /var/log/supervisor/patroni.err.log | grep -qi 'error\|critical'"

# Diagnostic final
print_diagnostics "Patroni/PG (Interne)" \
    "docker exec node1 supervisorctl status" \
    "docker exec node1 netstat -tunlp"

print_summary "test_dck_patroni.sh"
exit $?
