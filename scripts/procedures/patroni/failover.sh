#!/bin/bash
# Script généré pour la procédure : Bascule Automatique (Failover)
# Document source : documentation/procedures/patroni/failover.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Monitoring et Force Failover Patroni"

# 1. Détection d'un Failover en cours
log_info "Étape 1 : Vérification de l'état du cluster"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
docker exec node1 patronictl -c /etc/patroni.yml list

# 2. Forcer un Failover (Urgence)
log_warn "⚠️ ATTENTION : Forcer un failover peut entraîner une perte de données."
read -p "Souhaitez-vous forcer un failover ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Exécution du failover d'urgence..."
    # Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml failover"
    docker exec -it node1 patronictl -c /etc/patroni.yml failover
else
    log_info "Action annulée."
fi

log_info "✅ Procédure terminée"
