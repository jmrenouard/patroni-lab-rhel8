#!/bin/bash
# Script généré pour la procédure : Remplacement d'un nœud (Swap)
# Document source : documentation/procedures/etcd/member_swap.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

OLD_ID=$1
NEW_NAME=$2
NEW_PEER_URLS=$3

if [ -z "$OLD_ID" ] || [ -z "$NEW_NAME" ] || [ -z "$NEW_PEER_URLS" ]; then
    log_error "Usage: $0 <OLD_ID> <NEW_NAME> <NEW_PEER_URLS>"
    log_info "Exemple: $0 8e9e05f521f7a2f9 etcd-new https://10.0.0.10:2380"
    exit 1
fi

log_info "Début de la procédure : Remplacement du nœud $OLD_ID par $NEW_NAME"

# Étape 1 : Retrait de l'ancien
log_info "Étape 1 : Retrait de l'ancien membre $OLD_ID"
etcdctl member remove "$OLD_ID"

# Étape 2 : Ajout du nouveau
log_info "Étape 2 : Ajout du nouveau membre $NEW_NAME ($NEW_PEER_URLS)"
etcdctl member add "$NEW_NAME" --peer-urls="$NEW_PEER_URLS"

# Étape 3 : Initialisation
log_info "Étape 3 : Démarrez le nouveau nœud avec :"
log_info "export ETCD_INITIAL_CLUSTER_STATE=existing"
log_info "sudo systemctl start etcd"

log_info "✅ Procédure de swap initiée."
