#!/bin/bash
# test_dck_haproxy.sh
# Validation interne de HAProxy

source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🐳 [DOCKER-TEST] HAProxy Internal Verification"

# 1. État du process
echo -n "⚙️ Process status (haproxy)... "
if docker exec haproxy ps aux | grep -v grep | grep -q "haproxy"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# 2. Test Stats API avec les nouveaux identifiants
echo -n "📊 Stats API Auth check (Port ${INT_HAPROXY_STATS_PORT})... "
if docker exec haproxy curl -s -k -u ${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD} https://localhost:${INT_HAPROXY_STATS_PORT}/ | grep -q "HAProxy"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL (Auth ou Port)${NC}"
fi
