#!/bin/bash
# Script généré pour la procédure : Bascule Manuelle (Switchover)
# Document source : documentation/procedures/patroni/switchover.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Bascule Manuelle (Switchover) Patroni"

# 1. Lancement de la bascule
log_info "Étape 1 : Lancement de la commande switchover interactive"
log_info "Note : Vous devrez confirmer le leader et choisir la cible manuellement."

# Alternative SSH : ssh -t ${PATRONI_NODE} "patronictl -c /etc/patroni.yml switchover"
docker exec -it node1 patronictl -c /etc/patroni.yml switchover

# 3. Vérification
log_info "Étape 3 : Vérification du nouveau statut"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
docker exec node1 patronictl -c /etc/patroni.yml list

log_info "✅ Procédure de switchover terminée"
