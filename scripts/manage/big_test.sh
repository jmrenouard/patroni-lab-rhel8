#!/bin/bash
# big_test.sh
# Orchestrateur de test complet avec génération de rapport.

source .env

REPORT_DIR="reports"
mkdir -p $REPORT_DIR
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$REPORT_DIR/report_$DATE.md"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Démarrage du BIG-TEST...${NC}"

# Fonction pour ajouter une étape au rapport
log_step() {
    local title=$1
    local cmd=$2
    local status=$3
    local output=$4
    
    echo "## $title" >> $REPORT_FILE
    echo "**Commande :** \`$cmd\`" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    if [ "$status" == "OK" ]; then
        echo "**Résultat :** ✅ SUCCESS" >> $REPORT_FILE
    else
        echo "**Résultat :** ❌ FAIL" >> $REPORT_FILE
    fi
    echo "" >> $REPORT_FILE
    echo "### Output" >> $REPORT_FILE
    echo '```text' >> $REPORT_FILE
    echo "$output" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "---" >> $REPORT_FILE
}

# Initialisation du rapport
cat > $REPORT_FILE <<EOF
# Rapport d'Audit de Cluster Patroni HA
**Date :** $(date)
**Configuration :** RHEL 8, PostgreSQL 17, Patroni 4.1.0, ETCD 3.6.7

---

EOF

# 1. Nettoyage
echo -n "🧹 Nettoyage... "
OUT=$(./scripts/manage/cleanup_all.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Nettoyage" "./scripts/cleanup_all.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Nettoyage" "./scripts/cleanup_all.sh" "FAIL" "$OUT"
fi

# 2. Génération de certificats et clés
echo -n "🔑 Sécurité (Certs/SSH)... "
OUT=$(./scripts/install/generate_certs.sh 2>&1)
cat certs/patroni-api.crt certs/patroni-api.key > certs/haproxy.pem
./scripts/install/setup_pgbouncer.sh >> /dev/null
./scripts/install/setup_configs.sh >> /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Sécurité" "./scripts/generate_certs.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Sécurité" "./scripts/generate_certs.sh" "FAIL" "$OUT"
fi

# 3. Construction et Démarrage
echo -n "🏗️  Build & Up... "
OUT=$(make rebuild-all 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Build & Up" "make rebuild-all" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Build & Up" "make rebuild-all" "FAIL" "$OUT"
fi

echo "⏳ Attente de stabilisation (60s)..."
sleep 60

# 4. Configuration ETCD Auth
echo -n "🔐 ETCD Auth... "
OUT=$(./scripts/install/setup_etcd_auth.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "ETCD Auth" "./scripts/setup_etcd_auth.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "ETCD Auth" "./scripts/setup_etcd_auth.sh" "FAIL" "$OUT"
fi

# 5. Validation Globale
echo -n "🧪 Vérification Globale... "
OUT=$(./scripts/tests/verify_cluster.sh 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Vérification Globale" "./scripts/verify_cluster.sh" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Vérification Globale" "./scripts/verify_cluster.sh" "FAIL" "$OUT"
fi

# 6. Stress Test Final
echo -n "⚡ Stress Test (HAPROXY)... "
OUT=$(python3 scripts/tests/stress_test.py --type haproxy --host localhost --port ${EXT_HAPROXY_RW_PORT} --threads 5 --max-req 20 --delay 0.05 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}OK${NC}"
    log_step "Stress Test" "stress_test.py" "OK" "$OUT"
else
    echo -e "${RED}FAIL${NC}"
    log_step "Stress Test" "stress_test.py" "FAIL" "$OUT"
fi

echo -e "\n${YELLOW}🏁 BIG-TEST Terminé. Rapport disponible : ${GREEN}$REPORT_FILE${NC}"
