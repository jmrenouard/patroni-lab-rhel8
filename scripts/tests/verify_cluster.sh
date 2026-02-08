#!/bin/bash
# verify_cluster.sh
# Orchestrateur global de validation du cluster HA.

# Chargement de l'environnement pour les ports
source .env

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "🧪 [VERIFY] Démarrage de la validation globale...\n"

# 1. Validation de l'environnement
./scripts/manage/check_env.sh
if [ $? -ne 0 ]; then echo -e "${RED}❌ Échec de la vérification .env${NC}"; exit 1; fi

# 2. Tests Externes (Modular)
chmod +x scripts/tests/test_*.sh

echo "--- 🛠️  Tests Externes ---"
./scripts/tests/test_etcd.sh || { echo -e "${RED}❌ Échec ETCD${NC}"; exit 1; }
./scripts/tests/test_patroni.sh || { echo -e "${RED}❌ Échec Patroni/PG${NC}"; exit 1; }
./scripts/tests/test_haproxy.sh || { echo -e "${RED}❌ Échec HAProxy${NC}"; exit 1; }

# 3. Tests Internes (Docker Exec)
echo -e "\n--- 🐳 Tests Internes (Containers) ---"
./scripts/tests/test_dck_etcd.sh || { echo -e "${RED}❌ Échec Interne ETCD${NC}"; exit 1; }
./scripts/tests/test_dck_patroni.sh || { echo -e "${RED}❌ Échec Interne Patroni${NC}"; exit 1; }
./scripts/tests/test_dck_haproxy.sh || { echo -e "${RED}❌ Échec Interne HAProxy${NC}"; exit 1; }
./scripts/tests/test_dck_pgbouncer.sh || { echo -e "${RED}❌ Échec Interne PgBouncer${NC}"; exit 1; }

# 4. Test de Charge Rapide (Stress Test)
echo -e "\n--- ⚡ Test de Charge Rapide (Stress) ---"
python3 scripts/tests/stress_test.py --type haproxy --host localhost --port ${EXT_HAPROXY_RW_PORT} --threads 2 --max-req 5 --delay 0.1

# 5. Test de Bascule (Failover)
echo -e "\n--- 🏁 [HA] Test de bascule (Failover) ---"
LEADER=$(docker exec node1 curl -s -k -u ${PATRONI_API_USER}:${PATRONI_API_PASSWORD} https://localhost:${INT_PATRONI_PORT}/primary | grep -oP '(?<="name":")[^"]+')

if [ -z "$LEADER" ]; then
    echo -e "${RED}❌ Impossible de trouver le Leader actuel.${NC}"
    exit 1
fi

echo -e "Leader actuel : ${GREEN}$LEADER${NC}. Arrêt..."
docker stop $LEADER
sleep 15

NEW_LEADER=$(docker exec node1 curl -s -k -u ${PATRONI_API_USER}:${PATRONI_API_PASSWORD} https://localhost:${INT_PATRONI_PORT}/primary | grep -oP '(?<="name":")[^"]+')

if [ -n "$NEW_LEADER" ] && [ "$LEADER" != "$NEW_LEADER" ]; then
    echo -e "${GREEN}✅ Failover réussi !${NC} Nouveau leader : ${GREEN}$NEW_LEADER${NC}"
    docker start $LEADER
    sleep 10
    echo -e "${GREEN}✅ Ancien leader $LEADER réintégré.${NC}"
else
    echo -e "${RED}❌ Échec critique du Failover !${NC}"
    docker start $LEADER
    exit 1
fi

echo -e "\n${GREEN}🏆 TOUS LES MUST-HAVE SONT VALIDÉS SUR LE CLUSTER${NC}"
