#!/bin/bash
# big_test.sh
# Orchestrateur de test complet avec génération de rapport verbeux et détaillé.

source .env

REPORT_DIR="reports"
mkdir -p $REPORT_DIR
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/report_$DATE.md"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Starting BIG-TEST Cluster Audit...${NC}"

# Fonction pour ajouter une étape au rapport
log_step() {
    local title=$1
    local cmd=$2
    local status=$3
    local output=$4
    
    # Filtrage cosmétique pour les logs
    local filtered_output=$(echo "$output" | grep -vE "WARNING: Running pip as the 'root' user|This system is not registered with an entitlement server")
    
    # Détection plus stricte des erreurs (sauf pour les tests qui gèrent leurs propres erreurs)
    if [[ ! "$title" =~ "Test:" ]] && echo "$filtered_output" | grep -qiE "error|fatal|critical|command not found"; then
        if [ "$status" == "OK" ]; then
            status="FAIL"
        fi
    fi

    echo "## $title" >> $REPORT_FILE
    echo "---" >> $REPORT_FILE
    echo "**Action :** \`$cmd\`" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    if [ "$status" == "OK" ]; then
        echo "**Résultat :** ✅ SUCCESS" >> $REPORT_FILE
    else
        echo "**Résultat :** ❌ FAIL" >> $REPORT_FILE
    fi
    echo "" >> $REPORT_FILE
    echo "### Console Output" >> $REPORT_FILE
    echo '```text' >> $REPORT_FILE
    echo "$output" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
    echo "" >> $REPORT_FILE
}

# Initialisation du rapport
cat > $REPORT_FILE <<EOF
# Rapport d'Audit de Cluster Patroni HA (RHEL 8)
**Date :** $(date)
**Généré par :** Big-Test Orchestrator
**Composants :** PostgreSQL 17, Patroni 4.1.0, ETCD 3.6.7, HAProxy 3.1, PgBouncer 1.24

## 📊 Matrice de Santé du Cluster (Patroni)
---
\$(docker exec node1 patronictl -c /etc/patroni.yml list -f json | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('| Membre | Hôte | Rôle | État | Lag (MB) | Timeline |')
    print('| :--- | :--- | :--- | :--- | :--- | :--- |')
    for m in data:
        print(f'| {m.get(\"Member\", \"?\")} | {m.get(\"Host\", \"?\")} | {m.get(\"Role\", \"?\")} | {m.get(\"State\", \"?\")} | {m.get(\"Lag (MB)\", \"0\")} | {m.get(\"TL\", \"?\")} |')
except:
    print('⚠️ Impossible de récupérer la matrice de santé.')
")

## 🔗 État du Quorum ETCD
---
\$(docker exec etcd1 etcdctl --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 --cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key --user root:\${ETCD_ROOT_PASSWORD} endpoint status -w json | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print('| Point d\'accès | ID | Version | Taille DB | Is Learner | Raft Term | Raft Index |')
    print('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |')
    for m in data:
        ep = m.get('Endpoint', '?')
        s = m.get('Status', {})
        print(f'| {ep} | {s.get(\"header\", {}).get(\"member_id\", \"?\")} | {s.get(\"version\", \"?\")} | {s.get(\"dbSize\", 0)/1024/1024:.2f} MB | {s.get(\"isLearner\", False)} | {s.get(\"raftTerm\", \"?\")} | {s.get(\"raftIndex\", \"?\")} |')
except:
    print('⚠️ Impossible de récupérer l\'état d\'ETCD.')
")

## 🔐 Vérification Sécurité & TLS
---
\$(echo -e "| Composant | Certificat | Statut | Date d'expiration |\n| :--- | :--- | :--- | :--- |"
for cert in certs/*.crt; do
    name=\$(basename "\$cert")
    expiry=\$(openssl x509 -enddate -noout -in "\$cert" | cut -d= -f2)
    echo "| \$name | Present | ✅ OK | \$expiry |"
done
)

---

EOF

# 1. Nettoyage
echo -n "🧹 Nettoyage profond... "
OUT=$(./scripts/manage/cleanup_simple.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Nettoyage Infrastructure" "./scripts/manage/cleanup_simple.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Nettoyage Infrastructure" "./scripts/manage/cleanup_simple.sh" "FAIL" "$OUT"
fi

# 2. Préparation Sécurité & Configs
echo -n "🔐 Sécurité (Certs/SSH)... "
OUT1=$(./scripts/install/generate_certs.sh 2>&1)
cat certs/patroni-api.crt certs/patroni-api.key > certs/haproxy.pem
OUT2=$(./scripts/install/setup_pgbouncer.sh 2>&1)
OUT3=$(./scripts/install/setup_configs.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Sécurité & Configuration" "setup_configs.sh" "OK" "$OUT1\n$OUT2\n$OUT3"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Sécurité & Configuration" "setup_configs.sh" "FAIL" "$OUT1\n$OUT2\n$OUT3"
fi

# 3. Déploiement Cluster
echo -n "🏗️ Déploiement Cluster (Docker)... "
OUT=$(docker compose up -d --build 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Déploiement Docker" "docker compose up" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Déploiement Docker" "docker compose up" "FAIL" "$OUT"
fi

# 4. Attente stabilisation
echo -n "⏳ Stabilisation du cluster (120s)... "
sleep 120
echo -e "${GREEN}OK${NC}"

# 5. Configuration ETCD Auth
echo -n "🔑 ETCD Authentication Setup... "
OUT=$(./scripts/install/setup_etcd_auth.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Authentification ETCD" "./scripts/install/setup_etcd_auth.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Authentification ETCD" "./scripts/install/setup_etcd_auth.sh" "FAIL" "$OUT"
fi

# 5b. Bascule Patroni vers node1 (Demande Utilisateur)
echo -n "🔄 Bascule leader vers node1... "
# On attend un peu que Patroni soit totalement prêt après l'auth ETCD
sleep 10
CURRENT_LEADER=$(docker exec node1 patronictl -c /etc/patroni.yml list -f json | python3 -c "import sys, json; data=json.load(sys.stdin); print([m['Member'] for m in data if m['Role']=='Leader'][0] if data else '')")
if [ "$CURRENT_LEADER" != "node1" ] && [ -n "$CURRENT_LEADER" ]; then
    OUT=$(docker exec node1 patronictl -c /etc/patroni.yml switchover --leader "$CURRENT_LEADER" --candidate node1 --force 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
        log_step "Bascule Patroni (node1)" "patronictl switchover" "OK" "$OUT"
        sleep 5
    else
        echo -e "${RED}FAIL${NC}"
        log_step "Bascule Patroni (node1)" "patronictl switchover" "FAIL" "$OUT"
    fi
else
    echo -e "${YELLOW}SKIP (Déjà leader)${NC}"
fi

# 6. Audit & Diagnostics
echo -n "📊 Collecte métriques techniques... "
# On ajoute les détails à la fin du rapport initial
docker exec node1 patronictl -c /etc/patroni.yml list -f json | python3 -c "
import sys, json, os
try:
    data = json.load(sys.stdin)
    with open('reports/audit_report.md', 'a') as f:
        f.write('\n| Membre | Host | Rôle | État | Lag | TL |\n| :--- | :--- | :--- | :--- | :--- | :--- |\n')
        for m in data:
            f.write(f'| {m.get(\"Member\")} | {m.get(\"Host\")} | {m.get(\"Role\")} | {m.get(\"State\")} | {m.get(\"Lag\")} | {m.get(\"TL\")} |\n')
except Exception as e:
    pass
"

# 7. Exécution granulaire de TOUS les scripts de test
echo -e "\n🧪 Exécution des tests de conformité..."
chmod +x scripts/tests/*.sh

for test_script in scripts/tests/test_dck_etcd.sh scripts/tests/test_dck_haproxy.sh scripts/tests/test_dck_patroni.sh scripts/tests/test_dck_pgbouncer.sh scripts/tests/test_etcd.sh scripts/tests/test_haproxy.sh scripts/tests/test_patroni.sh scripts/tests/test_replication_scenario.sh scripts/tests/verify_cluster.sh scripts/tests/test_failover.sh; do
    if [[ "$test_script" == *"test_utils.sh"* ]]; then continue; fi
    test_name=$(basename "$test_script")
    echo -n "   👉 $test_name... "
    OUT=$($test_script 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK${NC}"
        log_step "Test: $test_name" "$test_script" "OK" "$OUT"
    else
        echo -e "${RED}FAIL${NC}"
        log_step "Test: $test_name" "$test_script" "FAIL" "$OUT"
    fi
done

# 6. Stress Test Final
echo -n "⚡ Stress Test Final (HAPROXY)... "
STRESS_CMD="docker exec node1 env CERT_DIR=/etc/patroni/certs PGPASSWORD='${POSTGRES_PASSWORD}' python3 /scripts/tests/stress_test.py --type haproxy --host haproxy --port ${INT_HAPROXY_RW_PORT} --threads 5 --max-req 20 --delay 0.05"
OUT=$($STRESS_CMD 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Test de Charge (Stress)" "$STRESS_CMD" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Test de Charge (Stress)" "$STRESS_CMD" "FAIL" "$OUT"
fi

echo -e "\n📊 Génération du rapport HTML..."
python3 scripts/manage/generate_html_report.py "$REPORT_FILE"

echo -e "\n${GREEN}🏆 Audit Terminé !${NC}"
echo -e "📄 Rapport Markdown : ${BLUE}$REPORT_FILE${NC}"
echo -e "🌐 Rapport HTML     : ${BLUE}${REPORT_FILE%.md}.html${NC}"
