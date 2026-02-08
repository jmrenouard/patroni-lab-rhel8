#!/bin/bash
# Script généré pour la procédure : Diagnostic et Identification Leader
# Document source : documentation/procedures/etcd/diagnostic.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Diagnostic du cluster etcd"

# Étape 1 : Santé globale
log_info "Étape 1 : Santé globale du cluster"
etcdctl endpoint health --cluster -w table

# Étape 2 : Statut détaillé
log_info "Étape 2 : Statut détaillé (Leader, Version, Taille DB)"
etcdctl endpoint status --cluster -w table

# Étape 3 : Identification Leader
log_info "Étape 3 : Identification rapide du Leader"
etcdctl endpoint status --cluster -w table | grep "true" || log_warn "Leader non trouvé dans le formatage table (vérifiez l'étape 2)."

# Étape 4 : Analyse des logs (Informationnel)
log_info "Étape 4 : Pour l'analyse des logs en temps réel, utilisez :"
log_info "journalctl -u etcd.service -f"

log_info "✅ Diagnostic terminé."
