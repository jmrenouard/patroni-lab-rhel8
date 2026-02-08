#!/bin/bash
# test_haproxy.sh
# Validation de la couche Load Balancing (HAProxy)

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 [HAPROXY] Test de l'équilibrage de charge..."

# 1. Test Cluster Stats (HAProxy)
echo -n "📊 API Stats (Port ${EXT_HAPROXY_STATS_PORT})... "
if curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} https://localhost:${EXT_HAPROXY_STATS_PORT}/; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Auth ou Port)${NC}"
fi

# 2. Test Écriture via HAProxy
echo -n "✍️  Écriture SQL via RW (Port ${EXT_HAPROXY_RW_PORT})... "
if docker exec node1 psql "host=haproxy port=${INT_HAPROXY_RW_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require" -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Accès RW)${NC}"
fi

# 3. Test Lecture via HAProxy
echo -n "📖 Lecture SQL via RO (Port ${EXT_HAPROXY_RO_PORT})... "
if docker exec node1 psql "host=haproxy port=${INT_HAPROXY_RO_PORT} user=${POSTGRES_USER} dbname=postgres sslmode=require" -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Accès RO)${NC}"
fi
