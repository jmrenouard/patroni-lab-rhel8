#!/bin/bash
# Script généré pour la procédure : Sauvegarde à chaud (Snapshot Full)
# Document source : documentation/procedures/etcd/backup_full.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).db"

log_info "Début de la procédure : Sauvegarde complète etcd"

# Étape 1 : Export du snapshot
log_info "Étape 1 : Export du snapshot vers $BACKUP_FILE"
# Alternative SSH : ssh ${ETCD_NODE} "etcdctl snapshot save $BACKUP_FILE"
etcdctl snapshot save "$BACKUP_FILE"

# Étape 2 : Vérification d'intégrité
log_info "Étape 2 : Vérification d'intégrité du snapshot"
if command -v etcdutl &> /dev/null; then
    etcdutl snapshot status "$BACKUP_FILE" -w table
else
    etcdctl snapshot status "$BACKUP_FILE" -w table
fi

log_info "✅ Sauvegarde terminée avec succès : $BACKUP_FILE"
