#!/bin/bash
# test_dck_pgbouncer.sh
# Validation interne de PgBouncer

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🐳 [DOCKER-TEST] PgBouncer Internal Verification"

# 1. État du process
echo -n "⚙️ Process status (pgbouncer)... "
if docker exec pgbouncer ps aux | grep -v grep | grep -q "pgbouncer"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# 2. Test Connection Pooling (RW)
echo -n "🔌 Connection via Pooler (RW - Port ${INT_PGBOUNCER_PORT})... "
if docker exec pgbouncer psql -h localhost -p ${INT_PGBOUNCER_PORT} -U ${POSTGRES_USER} -d postgres_rw -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Routage RW via Pooler)${NC}"
fi

# 3. Test Connection Pooling (RO)
echo -n "🔌 Connection via Pooler (RO - Port ${INT_PGBOUNCER_PORT})... "
if docker exec pgbouncer psql -h localhost -p ${INT_PGBOUNCER_PORT} -U ${POSTGRES_USER} -d postgres_ro -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Routage RO via Pooler)${NC}"
fi
