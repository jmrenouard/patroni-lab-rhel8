#!/bin/bash
# Script généré pour la procédure : Retrait propre d'un nœud
# Document source : documentation/procedures/etcd/member_remove.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

MEMBER_ID=$1

if [ -z "$MEMBER_ID" ]; then
    log_info "Étape 1 : Identification des membres"
    etcdctl member list -w table
    echo ""
    log_error "Usage: $0 <MEMBER_ID>"
    exit 1
fi

log_info "Début de la procédure : Retrait du membre $MEMBER_ID"

# Étape 2 : Retrait logique
log_info "Étape 2 : Retrait logique du membre du cluster"
# Alternative SSH : ssh ${ETCD_NODE} "etcdctl member remove $MEMBER_ID"
etcdctl member remove "$MEMBER_ID"

# Étape 3 : Arrêt physique
log_info "Étape 3 : N'oubliez pas d'arrêter physiquement le service sur le nœud retiré :"
log_info "sudo systemctl stop etcd"

log_info "✅ Procédure de retrait lancée."
