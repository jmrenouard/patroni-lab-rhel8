#!/bin/bash
# Script généré pour la procédure : Mise à jour Système ou Binaires
# Document source : documentation/procedures/etcd/update_system.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

TARGET_ID=$1

if [ -z "$TARGET_ID" ]; then
    log_info "Identification du leader actuel :"
    etcdctl endpoint status --cluster -w table | grep "true" || true
    echo ""
    log_error "Usage: $0 <MEMBER_ID_NON_MAINTENANCE_TO_RECEIVE_LEADERSHIP>"
    exit 1
fi

log_info "Début de la procédure : Mise à jour séquentielle etcd"

# Étape 1 : Transfert du leadership
log_info "Étape 1 : Transfert du leadership vers $TARGET_ID (si leader local)"
# Alternative SSH : ssh ${ETCD_NODE} "etcdctl move-leader $TARGET_ID"
etcdctl move-leader "$TARGET_ID" || log_warn "Le transfert a échoué (peut-être déjà sur le bon nœud ou erreur de connectivité)."

# Étape 2 : Arrêt du service local
log_info "Étape 2 : Arrêt du service local pour mise à jour"
log_info "Commande suggérée : sudo systemctl stop etcd"

# Étape 3 : Mise à jour
log_info "Étape 3 : Appliquez les mises à jour (dnf update ou replace binaries)"

# Étape 4 : Redémarrage
log_info "Étape 4 : Redémarrez le service :"
log_info "Commande suggérée : sudo systemctl start etcd"

# Étape 5 : Vérification santé
log_info "Étape 5 : Vérification de la santé du membre"
etcdctl endpoint health

log_info "✅ Mise à jour terminée pour ce nœud."
