#!/bin/bash
# test_patroni.sh
# Validation de l'API REST Patroni et de l'état PostgreSQL

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 [PATRONI] Test de l'API REST et de la réplication..."

# 1. Test Accessibilité API (sur node1)
echo -n "🌐 API REST (Node 1 - Port ${INT_PATRONI_PORT})... "
if docker exec node1 curl -s -k -u ${PATRONI_API_USER}:${PATRONI_API_PASSWORD} https://localhost:${INT_PATRONI_PORT}/health | grep -q "running"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Auth ou TLS)${NC}"
fi

# 2. Identification du Leader
echo -n "👑 Recherche du Cluster Leader... "
LEADER=$(docker exec node1 curl -s -k -u ${PATRONI_API_USER}:${PATRONI_API_PASSWORD} https://localhost:${INT_PATRONI_PORT}/primary | grep -oP '(?<="name":")[^"]+')
if [ -n "$LEADER" ]; then
    echo -e "${GREEN}$LEADER${NC}"
else
    echo -e "${RED}FAIL (Pas de leader trouvé)${NC}"
fi

# 3. Test de lecture/écriture SQL (via container)
echo -n "🐘 Test Écriture SQL (Direct)... "
if docker exec $LEADER psql -p ${INT_PG_PORT} -U ${POSTGRES_USER} -d postgres -c "CREATE TABLE IF NOT EXISTS test_resilience (id serial primary key, val text); INSERT INTO test_resilience(val) VALUES ('test');" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Écriture PG)${NC}"
fi
