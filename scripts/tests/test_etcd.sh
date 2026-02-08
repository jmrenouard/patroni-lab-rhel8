#!/bin/bash
# test_etcd.sh
# Validation de la couche ETCD (Sécurité et Quorum)

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 [ETCD] Test de la couche ETCD (HTTPS & Auth)..."

# 1. Test HTTPS Endpoint (Santé) via curl
echo -n "🌐 Test HTTPS (Port ${INT_ETCD_CLIENT_PORT})... "
CURL_AUTH_ARGS=""
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    CURL_AUTH_ARGS="--cert /certs/etcd-client.crt --key /certs/etcd-client.key"
fi
if docker exec etcd1 curl -s $CURL_AUTH_ARGS --cacert /certs/ca.crt https://etcd1:${INT_ETCD_CLIENT_PORT}/health | grep -q "true"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (TLS erroné)${NC}"
fi

# Base command arguments
ETCD_AUTH_ARGS="--cacert=/certs/ca.crt"
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    ETCD_AUTH_ARGS="$ETCD_AUTH_ARGS --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key"
fi

# 2. Test Quorum & Auth Root
echo -n "🔐 Test Authentification Root & Quorum... "
if docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT},https://etcd2:${INT_ETCD_CLIENT_PORT},https://etcd3:${INT_ETCD_CLIENT_PORT} \
    $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} endpoint health --cluster | grep -q "is healthy"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# 3. Test Utilisateur Patroni (Permissions)
echo -n "👤 Test Utilisateur Patroni (R/W sur ${NAMESPACE}${SCOPE})... "
if docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT} \
    $ETCD_AUTH_ARGS --user=${ETCD_PATRONI_USER}:${ETCD_PATRONI_PASSWORD} \
    put ${NAMESPACE}${SCOPE}/test_key "works" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Permissions DS)${NC}"
fi
