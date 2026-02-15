#!/bin/bash
# Script généré pour la procédure : Interface de Statistiques HAProxy
# Document source : documentation/procedures/haproxy/stats.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Interface de Statistiques HAProxy"

# Informations d'accès
HAPROXY_IP=${IP_HAPROXY:-"127.0.0.1"}
HAPROXY_PORT=8404
HAPROXY_USER=${ADMIN_HAPROXY_USER:-"admin"}

log_info "L'interface graphique est accessible à l'URL suivante :"
log_info "➡️  https://${HAPROXY_IP}:${HAPROXY_PORT}/"
log_info "Utilisateur : ${HAPROXY_USER}"
log_info "Mot de passe : [Consulter votre fichier .env ou variables d'environnement]"

# Test de disponibilité du port
log_info "Vérification de la disponibilité du port ${HAPROXY_PORT}..."
if nc -z -v -w5 "${HAPROXY_IP}" "${HAPROXY_PORT}" &> /dev/null; then
    log_info "✅ Le port ${HAPROXY_PORT} est ouvert et accessible."
else
    log_warn "❌ Le port ${HAPROXY_PORT} ne semble pas accessible à l'adresse ${HAPROXY_IP}."
fi

log_info "✅ Procédure terminée"
