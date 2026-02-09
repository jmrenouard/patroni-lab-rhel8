#!/bin/bash
# test_dck_etcd.sh
# Validation interne d'ETCD - Version Verbeuse

source .env
source ./scripts/tests/test_utils.sh

echo -e "🐳 [DOCKER-TEST] ETCD Internal Verification (Cluster Integrity)\n"

# Note: on passe les variables individuelles de certs car le splash $ETCD_AUTH_ARGS pose problème dans le python one-liner
ETCD_CERT_FLAGS="--cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key"

# 1. Quorum check
run_test "Santé du Cluster (Quorum etcd1-3)" \
    "docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT},https://etcd2:${INT_ETCD_CLIENT_PORT},https://etcd3:${INT_ETCD_CLIENT_PORT} ${ETCD_CERT_FLAGS} --user=root:${ETCD_ROOT_PASSWORD} endpoint health --cluster | grep -q 'is healthy'"

# 2. Member sync
run_test "Vérification du nombre de Membres (3 attendus)" \
    "python3 -c \"import subprocess; out = subprocess.check_output(['docker', 'exec', 'etcd1', 'etcdctl', '--endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT}', '--cacert=/certs/ca.crt', '--cert=/certs/etcd-client.crt', '--key=/certs/etcd-client.key', '--user=root:${ETCD_ROOT_PASSWORD}', 'member', 'list']); exit(0 if len(out.decode().splitlines()) == 3 else 1)\""

# Diagnostic final
print_diagnostics "ETCD (Interne)" \
    "docker exec etcd1 etcdctl ${ETCD_CERT_FLAGS} --user=root:\$ETCD_ROOT_PASSWORD member list"

print_summary "test_dck_etcd.sh"
exit $?
