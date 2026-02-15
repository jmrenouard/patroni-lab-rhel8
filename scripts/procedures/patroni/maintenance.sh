#!/bin/bash
# Script généré pour la procédure : Maintenance du Cluster Patroni
# Document source : documentation/procedures/patroni/maintenance.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Maintenance du Cluster Patroni (Pause/Resume)"

# 1. Activer le mode Maintenance (Pause)
log_info "Étape 1 : Activation du mode Maintenance (Pause)"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml pause"
docker exec node1 patronictl -c /etc/patroni.yml pause

# 2. Vérification du statut
log_info "Étape 2 : Vérification du statut du cluster"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
docker exec node1 patronictl -c /etc/patroni.yml list

log_info "INFO : Vous pouvez maintenant effectuer vos opérations de maintenance."
read -p "Une fois terminé, souhaitez-vous désactiver le mode Maintenance (Resume) ? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 3. Désactiver le mode Maintenance (Resume)
    log_info "Étape 3 : Désactivation du mode Maintenance (Resume)"
    # Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml resume"
    docker exec node1 patronictl -c /etc/patroni.yml resume
else
    log_warn "Le cluster reste en mode MAINTENANCE. N'oubliez pas de lancer 'patronictl resume' plus tard."
fi

log_info "✅ Procédure de maintenance traitée"
