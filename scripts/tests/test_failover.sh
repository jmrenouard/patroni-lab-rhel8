#!/bin/bash
# test_failover.sh
# Validation de la Haute Disponibilité (Bascule automatique du Leader)

source .env
source ./scripts/tests/test_utils.sh

echo -e "🏁 [HA] Test de Bascule Automatique (Failover)...\n"

# 1. Identification du Leader Initial
run_test "Recherche du Leader Cluster (Initial)" \
    "docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -q 'Leader'"

LEADER=$(docker exec node1 patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")')

if [ -z "$LEADER" ]; then
    echo -e "${RED}❌ Pas de leader trouvé. Impossible de tester la bascule.${NC}"
    exit 1
fi

# 2. Provoquer la bascule
run_test "Simulation de panne: Arrêt du Leader actuel ($LEADER)" "docker stop $LEADER"

echo "⏳ Attente de l'élection d'un nouveau leader (20s)..."
sleep 20

# 3. Vérification du Nouveau Leader
# On essaye node2, si node2 était le leader on essaye node3 ou node1 (qui vient d'être coupé mais on check si un autre a pris)
NEW_LEADER=$(docker exec node2 patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")' || true)
if [ -z "$NEW_LEADER" ]; then
    NEW_LEADER=$(docker exec node3 patronictl -c /etc/patroni.yml list -f json | grep -oP '"Member":\s*"\K[^"]+(?=",\s*"Host":\s*"[^"]+",\s*"Role":\s*"Leader")' || true)
fi

run_test "Vérification Election Nouveau Leader" "[ -n \"$NEW_LEADER\" ] && [ \"$LEADER\" != \"$NEW_LEADER\" ]"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Failover réussi !${NC} $LEADER -> $NEW_LEADER"
else
    echo -e "${RED}❌ Échec de la bascule !${NC}"
    docker start $LEADER
    exit 1
fi

# 4. Réintégration
run_test "Réintégration de l'Ancien Leader ($LEADER)" "docker start $LEADER"
sleep 10
run_test "Vérification Santé Ancien Leader réintégré" "docker exec node1 patronictl -c /etc/patroni.yml list | grep -q \"$LEADER\""

# Diagnostic final
print_diagnostics "Failover HA" \
    "docker exec node1 patronictl -c /etc/patroni.yml list"

print_summary "test_failover.sh"
exit $?
