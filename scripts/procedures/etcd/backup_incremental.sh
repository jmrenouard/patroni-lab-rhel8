#!/bin/bash
# Script généré pour la procédure : Sauvegarde Incrémentale
# Document source : documentation/procedures/etcd/backup_incremental.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

check_etcdctl

BACKUP_FULL_DB="${1:-backup_full.db}"

if [ ! -f "$BACKUP_FULL_DB" ]; then
    log_error "Fichier snapshot full '$BACKUP_FULL_DB' non trouvé."
    log_info "Usage: $0 [path_to_backup_full.db]"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_error "jq n'est pas installé. Veuillez l'installer pour parser le statut du snapshot."
    exit 1
fi

log_info "Début de la procédure : Sauvegarde incrémentale etcd"

# Étape 1 : Récupération de la révision
log_info "Étape 1 : Récupération de la révision depuis $BACKUP_FULL_DB"
if command -v etcdutl &> /dev/null; then
    LAST_REV=$(etcdutl snapshot status "$BACKUP_FULL_DB" --write-out=json | jq .revision)
else
    LAST_REV=$(etcdctl snapshot status "$BACKUP_FULL_DB" --write-out=json | jq .revision)
fi

log_info "Révision de départ : $LAST_REV"

# Étape 2 : Capture du flux incremental
LOG_FILE="etcd_incremental_$(date +%Y%m%d_%H%M%S).log"
log_info "Étape 2 : Capture du flux incremental vers $LOG_FILE (Appuyez sur Ctrl+C pour arrêter)"
log_info "Commande : etcdctl watch / --prefix --rev=$((LAST_REV + 1))"

# Alternative SSH : ssh ${ETCD_NODE} "etcdctl watch / --prefix --rev=$((LAST_REV + 1))"
etcdctl watch / --prefix --rev=$((LAST_REV + 1)) > "$LOG_FILE"
