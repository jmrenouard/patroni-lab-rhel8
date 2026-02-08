#!/bin/bash
# test_dck_etcd.sh
# Validation interne d'ETCD

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🐳 [DOCKER-TEST] ETCD Internal Verification"

# Base command arguments for internal etcdctl
ETCD_AUTH_ARGS="--cacert=/certs/ca.crt"
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
    ETCD_AUTH_ARGS="$ETCD_AUTH_ARGS --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key"
fi

# 1. Quorum check (Port Interne ${INT_ETCD_CLIENT_PORT})
echo -n "⚙️ Cluster Health check... "
if docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT},https://etcd2:${INT_ETCD_CLIENT_PORT},https://etcd3:${INT_ETCD_CLIENT_PORT} \
    $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} endpoint health --cluster | grep -q "is healthy"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# 2. Member sync
echo -n "👥 Member list check... "
if [ $(docker exec etcd1 etcdctl --endpoints=https://etcd1:${INT_ETCD_CLIENT_PORT} $ETCD_AUTH_ARGS --user=root:${ETCD_ROOT_PASSWORD} member list | wc -l) -eq 3 ]; then
    echo -e "${GREEN}OK (3 nodes)${NC}"
else
    echo -e "${RED}FAIL (Cluster incomplet)${NC}"
fi
