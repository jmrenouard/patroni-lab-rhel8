#!/bin/bash
# Script généré pour la procédure : Diagnostic de Santé Patroni
# Document source : documentation/procedures/patroni/diagnostic.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Diagnostic de Santé Patroni"

# 1. Vue d'ensemble du Cluster
log_info "Étape 1 : Vue d'ensemble du Cluster (patronictl list)"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
docker exec node1 patronictl -c /etc/patroni.yml list

# 2. Statut détaillé d'un membre (API)
log_info "Étape 2 : Vérification de la santé via l'API (curl /health)"
# Alternative SSH : ssh ${PATRONI_NODE} "curl -s -k -u \"admin:secret\" https://localhost:8008/health"
curl -s -k -u "admin:secret" https://localhost:8008/health || log_warn "API inaccessible sur localhost:8008"

# 3. Configuration Dynamique
log_info "Étape 3 : Vérification de la configuration DCS"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml show-config"
docker exec node1 patronictl -c /etc/patroni.yml show-config

# 4. Analyse des logs (Rappel)
log_info "Note : Pour l'analyse des logs en temps réel, exécutez :"
log_info "journalctl -u patroni.service -f"

log_info "✅ Diagnostic terminé"
