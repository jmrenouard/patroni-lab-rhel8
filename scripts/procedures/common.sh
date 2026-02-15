#!/bin/bash

# Configuration commune pour les scripts de procédures

# 1. Chargement de l'environnement
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
fi

# 2. Configuration etcdctl
export ETCDCTL_API=${ETCDCTL_API:-3}
export ETCDCTL_ENDPOINTS=${ETCDCTL_ENDPOINTS:-"https://127.0.0.1:2379"}

# Chemins par défaut pour les certificats (peuvent être surchargés par .env)
export ETCDCTL_CACERT=${ETCDCTL_CACERT:-"/etc/etcd/ca.pem"}
export ETCDCTL_CERT=${ETCDCTL_CERT:-"/etc/etcd/cert.pem"}
export ETCDCTL_KEY=${ETCDCTL_KEY:-"/etc/etcd/key.pem"}

# 3. Fonctions d'aide
log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

check_etcdctl() {
    if ! command -v etcdctl &> /dev/null; then
        log_error "etcdctl n'est pas installé ou n'est pas dans le PATH."
        exit 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_warn "Ce script devrait probablement être exécuté en tant que root pour accéder aux certificats /etc/etcd/."
    fi
}

# Initialisation
# check_etcdctl  # Retiré de l'initialisation globale pour permettre l'utilisation par d'autres composants
# check_root
