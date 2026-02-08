#!/bin/bash
# Script généré pour la procédure : Restauration Incrémentale (Replay de log)
# Document source : documentation/procedures/etcd/restore_incremental.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

LOG_FILE=$1

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    log_error "Usage: $0 <etcd_incremental.log>"
    exit 1
fi

log_info "Début de la procédure : Rejeu des données (Incremental Restore) depuis $LOG_FILE"

# Étape 1 : Rejeu des données
# Note : Cette implémentation simplifiée suppose un format de log compatible avec un parsing basique.
# Un rejeu robuste complexe pourrait nécessiter un parser plus évolué.

while read -r line; do
    # Exemple de parsing simpliste (à adapter selon le format exact du log de watch)
    # Ici on suppose que le log contient des lignes type "PUT /key value"
    if [[ $line =~ ^PUT ]]; then
        key=$(echo "$line" | cut -d' ' -f2)
        value=$(echo "$line" | cut -d' ' -f3-)
        log_info "Replaying: PUT $key"
        etcdctl put "$key" "$value"
    fi
done < "$LOG_FILE"

log_info "✅ Rejeu terminé."
