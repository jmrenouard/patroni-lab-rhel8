#!/bin/bash
# scripts/manage/status.sh
# Check comprehensive status of cluster components (etcd, patroni, postgres, haproxy, pgbouncer)
# Supports target filtering: ./status.sh [all|etcd|patroni|postgres|haproxy|pgbouncer]

set -euo pipefail

# Source environment variables if available
if [ -f .env ]; then
    source .env
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET=${1:-all}

log_header() {
    echo -e "\n${BLUE}================================================================${NC}"
    echo -e "${BLUE}🔍 STATUT: $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

log_data() {
    local title=$1
    shift
    echo -e "\n   ${BLUE}[ $title ]${NC}"
    local out
    # Capture et nettoyage des warnings ETCD cosmétiques
    if out=$( "$@" 2>&1 | grep -v '{"level":"warn"' ); then
        if [ -z "$out" ]; then
            echo -e "   ${YELLOW}(Pas de données disponibles)${NC}"
        else
            # Unification du format : On tente d'afficher proprement
            if echo "$out" | grep -q "^[\[{]"; then
                # Si JSON (Configuration), on transforme en liste de paramètres
                echo "$out" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    def print_kv(d, indent=0):
        for k, v in d.items():
            if isinstance(v, dict):
                print(' ' * indent + f'{k}:')
                print_kv(v, indent + 2)
            else:
                print(' ' * indent + f'{k:<25} : {v}')
    print_kv(data)
except:
    print(sys.stdin.read())
" | sed 's/^/   /'
            else
                # Pour les tables, on s'assure d'une indentation propre
                echo "$out" | sed 's/^/   /'
            fi
        fi
    else
        local exit_code=$?
        echo -e "   ${RED}ERREUR (Code $exit_code) : $out${NC}" | sed 's/^/   /'
    fi
}

# Helper: Probe port via nc
check_port() {
    local port=$1
    local name=$2
    printf "   👉 %-30s (port %s) : " "$name" "$port"
    if nc -z -w 2 "localhost" "$port" 2>/dev/null; then
        echo -e "${GREEN}OUVERT${NC}"
    else
        echo -e "${RED}FERMÉ${NC}"
    fi
}

# Helper: Handshake TLS via host-side openssl
check_tls() {
    local port=$1
    local name=$2
    printf "   🔐 TLS Handshake %-22s (port %s) : " "$name" "$port"
    if timeout 2 openssl s_client -connect "localhost:$port" -CAfile ./certs/ca.crt </dev/null 2>/dev/null | grep -q "CONNECTED"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ÉCHEC${NC}"
    fi
}

# --- ETCD ---
status_etcd() {
    log_header "ÉCOSYSTÈME ETCD (HTTPS/QUORUM)"
    check_port "${EXT_ETCD_CLIENT_PORT_ETCD1}" "API Client Master"
    
    local etcd_cmd="docker exec -e ETCDCTL_API=3 etcd1 etcdctl --cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key --user=root:${ETCD_ROOT_PASSWORD}"

    log_data "ÉTAT DE SANTÉ DES ENDPOINTS" $etcd_cmd endpoint status -w table
    log_data "LISTE DES MEMBRES DU QUORUM" $etcd_cmd member list -w table
}

# --- PATRONI ---
status_patroni() {
    log_header "HA PATRONI / POSTGRESQL (AUTO-FAILOVER)"
    check_port "${EXT_PATRONI_PORT_NODE1}" "API Rest Patroni"
    check_port "${EXT_PG_PORT_NODE1}" "PostgreSQL Principal"
    
    log_data "TOPOLOGIE DU CLUSTER" docker exec node1 patronictl -c /etc/patroni.yml list
    log_data "CONFIGURATION DYNAMIQUE DU CLUSTER" curl -s -k -u "${PATRONI_API_USER}:${PATRONI_API_PASSWORD}" \
        https://localhost:"${EXT_PATRONI_PORT_NODE1}"/config
}

# --- HAPROXY ---
status_haproxy() {
    log_header "POURTOUR HAPROXY (ENTRYPOINTS)"
    check_port "${EXT_HAPROXY_RW_PORT}" "Point d'Entrée RW"
    check_port "${EXT_HAPROXY_STATS_PORT}" "Interface Statistiques"
    check_tls "${EXT_HAPROXY_RW_PORT}" "Flux SQL Sécurisé"
    
    # Unification format HAProxy (CSV to Aligned Table)
    log_data "STATISTIQUES DES BACKENDS" bash -c "curl -s -k -u \"${ADMIN_HAPROXY_USER}:${ADMIN_HAPROXY_PASSWORD}\" \"https://localhost:${EXT_HAPROXY_STATS_PORT}/;csv\" | sed 's/^# //;s/,$//' | cut -d, -f1,2,18,19 | column -s, -t"
}

# --- PGBOUNCER ---
status_pgbouncer() {
    log_header "POOLER PGBOUNCER (SESSION/CONNEXION)"
    check_port "${EXT_PGBOUNCER_PORT}" "Port Pooler Interne"
    
    log_data "ÉTAT DES POOLS ACTIFS" docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" pgbouncer psql -U postgres -p 6432 -h localhost -c "SHOW POOLS" pgbouncer
}

case $TARGET in
    etcd) status_etcd ;;
    patroni|postgres|postgresql) status_patroni ;;
    haproxy) status_haproxy ;;
    pgbouncer) status_pgbouncer ;;
    all)
        status_etcd
        status_patroni
        status_haproxy
        status_pgbouncer
        ;;
    *)
        echo "Usage: $0 [all|etcd|patroni|haproxy|pgbouncer]"
        exit 1
        ;;
esac
