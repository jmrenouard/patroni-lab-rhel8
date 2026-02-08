#!/bin/bash
# Script généré pour la procédure : Réinitialisation d'un Nœud Zombie
# Document source : documentation/procedures/etcd/member_reset_zombie.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

ZOMBIE_ID=$1
NEW_NAME=$2
PEER_URLS=$3

if [ -z "$ZOMBIE_ID" ] || [ -z "$NEW_NAME" ] || [ -z "$PEER_URLS" ]; then
    log_error "Usage: $0 <ZOMBIE_ID> <MEMBER_NAME> <PEER_URLS>"
    log_info "Exemple: $0 8e9e05f521f7a2f9 etcd1 https://10.0.0.1:2380"
    exit 1
fi

log_info "Début de la procédure : Réinitialisation du nœud zombie $ZOMBIE_ID"

# Étape 1 : Retrait logique
log_info "Étape 1 : Retrait logique du cluster"
etcdctl member remove "$ZOMBIE_ID"

# Étape 2 : Nettoyage local (Informationnel/Local)
log_info "Étape 2 : Nettoyage local des données (à faire sur le nœud zombie) :"
log_warn "sudo rm -rf /var/lib/etcd/*"

# Étape 3 : Ré-ajout
log_info "Étape 3 : Ré-ajout du membre au cluster"
etcdctl member add "$NEW_NAME" --peer-urls="$PEER_URLS"

# Étape 4 : Relance propre
log_info "Étape 4 : Relance du service sur le nœud zombie avec :"
log_info "export ETCD_INITIAL_CLUSTER_STATE=existing"
log_info "sudo systemctl start etcd"

log_info "✅ Procédure de réinitialisation initiée."
