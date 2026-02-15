#!/bin/bash
# Script généré pour la procédure : Restauration Full (Disaster Recovery)
# Document source : documentation/procedures/etcd/restore_full.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

# Note: check_etcdctl n'est pas strictement requis car on utilise etcdutl, 
# mais il est bon de l'avoir pour le contexte.
check_etcdctl

BACKUP_DB=$1
NAME=$2
INITIAL_CLUSTER=$3
INITIAL_CLUSTER_TOKEN=$4
INITIAL_ADVERTISE_PEER_URLS=$5
DATA_DIR=${6:-"/var/lib/etcd_new"}

if [ -z "$BACKUP_DB" ] || [ -z "$NAME" ] || [ -z "$INITIAL_CLUSTER" ]; then
    log_error "Usage: $0 <backup.db> <node_name> <initial_cluster> [token] [advertise_peer_urls] [data_dir]"
    log_info "Exemple: $0 backup.db infra0 infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380 etcd-cluster-1 https://10.0.1.10:2380 /var/lib/etcd_new"
    exit 1
fi

if ! command -v etcdutl &> /dev/null; then
    log_error "etcdutl est requis pour la restauration du snapshot."
    exit 1
fi

log_info "Début de la procédure : Restauration Full etcd"

# Étape 1 : Arrêt du cluster
log_info "Étape 1 : Assurez-vous que etcd est arrêté sur TOUS les nœuds :"
log_info "sudo systemctl stop etcd"

# Étape 2 : Restauration
log_info "Étape 2 : Restauration du snapshot $BACKUP_DB dans $DATA_DIR"
# Alternative SSH : ssh ${ETCD_NODE} "etcdutl snapshot restore $BACKUP_DB --name $NAME --initial-cluster $INITIAL_CLUSTER --initial-cluster-token ${INITIAL_CLUSTER_TOKEN:-etcd-cluster-token} --initial-advertise-peer-urls ${INITIAL_ADVERTISE_PEER_URLS:-https://127.0.0.1:2380} --data-dir $DATA_DIR"
etcdutl snapshot restore "$BACKUP_DB" \
  --name "$NAME" \
  --initial-cluster "$INITIAL_CLUSTER" \
  --initial-cluster-token "${INITIAL_CLUSTER_TOKEN:-etcd-cluster-token}" \
  --initial-advertise-peer-urls "${INITIAL_ADVERTISE_PEER_URLS:-https://127.0.0.1:2380}" \
  --data-dir "$DATA_DIR"

# Étape 3 : Redémarrage
log_info "Étape 3 : Relancez le service sur chaque nœud une fois restauré :"
log_info "sudo systemctl start etcd"

log_info "✅ Restauration terminée localement dans $DATA_DIR."
