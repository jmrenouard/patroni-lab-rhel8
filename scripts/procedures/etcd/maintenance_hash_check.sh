#!/bin/bash
# Script généré pour la procédure : Vérification de corruption (Hash Check)
# Document source : documentation/procedures/etcd/maintenance_hash_check.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

log_info "Début de la procédure : Vérification de corruption (Hash Check)"

# Étape 1 : Vérification des hashs
log_info "Étape 1 : Vérification des hashs pour les endpoints : $ETCDCTL_ENDPOINTS"
# Alternative SSH : ssh ${ETCD_NODE} "etcdctl check hash --endpoints=\"$ETCDCTL_ENDPOINTS\""
etcdctl check hash --endpoints="$ETCDCTL_ENDPOINTS"

log_info "✅ Vérification des hashs terminée."
