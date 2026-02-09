#!/bin/bash
# verify_cluster.sh
# Orchestrateur global de validation du cluster HA - Version Haute Visibilité

source .env
source ./scripts/tests/test_utils.sh

echo -e "${YELLOW}================================================================${NC}"
echo -e "${YELLOW}🧪 [VERIFY] Démarrage de la validation globale du cluster HA${NC}"
echo -e "${YELLOW}================================================================${NC}\n"

# Attente supplémentaire pour s'assurer que tout est prêt
echo "⏳ Waiting 30s for services to be fully Operational..."
sleep 30

# 1. Validation de l'environnement
run_test "Vérification de l'environnement (.env)" "./scripts/manage/check_env.sh"

# 2. Tests Externes
echo -e "\n--- 🛠️  Tests Externes (Connectivity & Quorum) ---"
chmod +x scripts/tests/test_*.sh
./scripts/tests/test_etcd.sh; FAILURES=$((FAILURES + $?))
./scripts/tests/test_patroni.sh; FAILURES=$((FAILURES + $?))
./scripts/tests/test_haproxy.sh; FAILURES=$((FAILURES + $?))

# 3. Tests Internes
echo -e "\n--- 🐳 Tests Internes (Containers Status) ---"
./scripts/tests/test_dck_etcd.sh; FAILURES=$((FAILURES + $?))
./scripts/tests/test_dck_patroni.sh; FAILURES=$((FAILURES + $?))
./scripts/tests/test_dck_haproxy.sh; FAILURES=$((FAILURES + $?))
./scripts/tests/test_dck_pgbouncer.sh; FAILURES=$((FAILURES + $?))

# 4. Test de Charge Rapide
echo -e "\n--- ⚡ Test de Charge Rapide (Stress) ---"
run_test "Exécution Stress Test (2 threads, 10 requêtes)" \
    "docker exec node1 env CERT_DIR=/etc/patroni/certs PGPASSWORD='${POSTGRES_PASSWORD}' python3 /scripts/tests/stress_test.py --type haproxy --host haproxy --port ${INT_HAPROXY_RW_PORT} --threads 2 --max-req 5 --delay 0.1"

# 5. Test de Bascule (Failover)
echo -e "\n--- 🏁 [HA] Test de bascule (Failover) ---"

LEADER=$(docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")')

if [ -n "$LEADER" ]; then
    run_test "Basculement: Arrêt du Leader actuel ($LEADER)" "docker stop $LEADER"
    echo "⏳ Attente de l'élection d'un nouveau leader (20s)..."
    sleep 20
    
    # Trouver un nœud survivant pour vérifier le statut
    SURVIVOR=""
    for node in node1 node2 node3; do
        if [ "$node" != "$LEADER" ]; then
            if docker ps --format '{{.Names}}' | grep -q "^$node$"; then
                SURVIVOR=$node
                break
            fi
        fi
    done

    if [ -n "$SURVIVOR" ]; then
        NEW_LEADER=$(docker exec $SURVIVOR patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")' || true)
        
        if [ -n "$NEW_LEADER" ] && [ "$LEADER" != "$NEW_LEADER" ]; then
            echo -e "   [RESULT] ${GREEN}✅ Failover réussi !${NC} Nouveau leader : ${GREEN}$NEW_LEADER${NC}"
            run_test "Réintégration de l'ancien leader ($LEADER)" "docker start $LEADER"
        else
            echo -e "   [RESULT] ${RED}❌ Échec critique du Failover !${NC}"
            docker start $LEADER
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo -e "   [RESULT] ${RED}❌ Pas de survivant trouvé pour vérifier le nouveau leader !${NC}"
        docker start $LEADER
        FAILURES=$((FAILURES + 1))
    fi
else
    echo -e "${RED}❌ Pas de leader trouvé pour le test de failover.${NC}"
    FAILURES=$((FAILURES + 1))
fi

echo -e "\n${YELLOW}================================================================${NC}"
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}🏆 TOUS LES TESTS SONT AU VERT - CLUSTER OPÉRATIONNEL${NC}"
else
    echo -e "${RED}⚠️  CERTAINS TESTS ONT ÉCHOUÉ ($FAILURES ÉCHECS)${NC}"
fi
echo -e "${YELLOW}================================================================${NC}"

exit $FAILURES
