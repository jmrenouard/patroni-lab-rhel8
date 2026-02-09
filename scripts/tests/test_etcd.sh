#!/bin/bash
# test_etcd.sh
# Validation de la couche ETCD (Sécurité, Quorum et Santé des Membres)

source .env
source ./scripts/tests/test_utils.sh

echo -e "🧪 [ETCD] Test de la couche ETCD (HTTPS, Quorum, Auth & Multi-nœuds)...\n"

# Préparation des arguments d'authentification
CURL_AUTH_ARGS=""
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    CURL_AUTH_ARGS="--cert /certs/etcd-client.crt --key /certs/etcd-client.key"
fi

ETCD_AUTH_ARGS="--cacert=/certs/ca.crt"
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    ETCD_AUTH_ARGS="$ETCD_AUTH_ARGS --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key"
fi

# 1. Test HTTPS Endpoint (Santé) via curl
run_test "Endpoint HTTPS Santé (etcd1)" \
    "docker exec etcd1 curl -s $CURL_AUTH_ARGS --cacert /certs/ca.crt https://etcd1:${INT_ETCD_CLIENT_PORT}/health | grep -q 'true'"

# 2. Test Quorum & Auth Root Cluster
run_test "Santé du Cluster & Quorum (Root Auth)" \
    "docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT},https://etcd2:${INT_ETCD_CLIENT_PORT},https://etcd3:${INT_ETCD_CLIENT_PORT} $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} endpoint health --cluster | grep -q 'is healthy'"

# 3. Vérification individuelle des membres (3 nœuds)
run_test "Vérification Presence Membre 1 (etcd1)" "docker exec etcd1 etcdctl $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} member list | grep -q 'etcd1'"
run_test "Vérification Presence Membre 2 (etcd2)" "docker exec etcd1 etcdctl $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} member list | grep -q 'etcd2'"
run_test "Vérification Presence Membre 3 (etcd3)" "docker exec etcd1 etcdctl $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} member list | grep -q 'etcd3'"

# 4. Test Utilisateur Patroni (Permissions)
run_test "Permissions Utilisateur Patroni (NAMESPACE/SCOPE)" \
    "docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT} $ETCD_AUTH_ARGS --user=${ETCD_PATRONI_USER}:${ETCD_PATRONI_PASSWORD} put ${NAMESPACE}${SCOPE}/test_key 'works' &> /dev/null"

# Diagnostic final
print_diagnostics "ETCD" \
    "docker exec etcd1 etcdctl $ETCD_AUTH_ARGS --user=root:\$ETCD_ROOT_PASSWORD member list" \
    "docker exec etcd1 etcdctl $ETCD_AUTH_ARGS --user=root:\$ETCD_ROOT_PASSWORD endpoint status --cluster -w table"

print_summary "test_etcd.sh"
exit $?
