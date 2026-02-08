#!/bin/bash
# test_dck_patroni.sh
# Validation interne de Patroni et PostgreSQL

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🐳 [DOCKER-TEST] Patroni/PG Internal Verification"

# 1. État du process Supervisor
echo -n "⚙️ Process status (supervisord)... "
if docker exec node1 ps aux | grep -v grep | grep -q "supervisord"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# 2. Vérification des ports d'écoute (Interne)
echo -n "🔌 Port Check (PG: ${INT_PG_PORT}, Patroni: ${INT_PATRONI_PORT})... "
# Conversion des ports en hexa (5432 -> 1538, 8008 -> 1F48)
if docker exec node1 grep -q "1538" /proc/net/tcp && \
   docker exec node1 grep -q "1F48" /proc/net/tcp; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Ports non écoutés)${NC}"
fi

# 3. Log Errors
echo -n "📜 Log Error Check (Patroni)... "
if ! docker exec node1 tail -n 50 /var/log/supervisor/patroni.err.log | grep -qi "error\|critical"; then
    echo -e "${GREEN}OK (No critical errors)${NC}"
else
    echo -e "${YELLOW}WARNING (Check logs)${NC}"
fi
