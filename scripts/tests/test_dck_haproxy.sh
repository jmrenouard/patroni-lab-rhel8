#!/bin/bash
# test_dck_haproxy.sh
# Validation interne de HAProxy - Version Verbeuse

source .env
source ./scripts/tests/test_utils.sh

echo -e "🐳 [DOCKER-TEST] HAProxy Internal Verification\n"

# 1. État du process
run_test "Vérification État du Processus (HAProxy)" \
    "docker exec haproxy ps aux | grep -v grep | grep -q 'haproxy'"

# 2. Test Stats API Interne
run_test "Vérification Auth API Stats (Interne: ${INT_HAPROXY_STATS_PORT})" \
    "docker exec haproxy curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} https://localhost:${INT_HAPROXY_STATS_PORT}/ | grep -q 'HAProxy'"

# Diagnostic final
print_diagnostics "HAProxy (Interne)" \
    "docker exec haproxy haproxy -v" \
    "docker exec haproxy ls -l /usr/local/etc/haproxy/haproxy.cfg"

print_summary "test_dck_haproxy.sh"
exit $?
