#!/bin/bash
# Script généré pour la procédure : Diagnostic de Santé HAProxy
# Document source : documentation/procedures/haproxy/diagnostic.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Diagnostic de Santé HAProxy"

# 1. Vérification des ports d'écoute
log_info "Étape 1 : Vérification des ports d'écoute (RW:5432, RO:5433, Stats:8404)"
# Alternative SSH : ssh ${HAPROXY_NODE} "netstat -tpln | grep haproxy"
netstat -tpln | grep haproxy || log_warn "HAProxy ne semble pas écouter sur les ports attendus."

# 2. Test de connexion SQL via HAProxy
log_info "Étape 2 : Test de connexion SQL (RW port 5432)"
# Note: psql doit être installé localement.
if command -v psql &> /dev/null; then
    psql "host=localhost port=5432 user=postgres sslmode=require" -c "SELECT pg_is_in_recovery();" || log_warn "Échec de connexion au port 5432"
else
    log_warn "psql n'est pas installé, test de connexion ignoré."
fi

# 4. Statut via la Socket Admin
log_info "Étape 4 : Statut détaillé via la Socket Admin"
if [ -S /tmp/haproxy.sock ]; then
    # Alternative SSH : ssh ${HAPROXY_NODE} "echo \"show stat\" | socat stdio /tmp/haproxy.sock | cut -d, -f1,2,18,19 | column -s, -t"
    echo "show stat" | socat stdio /tmp/haproxy.sock | cut -d, -f1,2,18,19 | column -s, -t
else
    log_warn "Socket /tmp/haproxy.sock introuvable."
fi

log_info "✅ Diagnostic HAProxy terminé"
