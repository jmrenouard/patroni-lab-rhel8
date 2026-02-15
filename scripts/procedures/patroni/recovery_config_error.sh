#!/bin/bash
# Script généré pour la procédure : Procédu de Récupération (Erreur de Configuration)
# Document source : documentation/procedures/patroni/recovery_config_error.md

set -euo pipefail

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Récupération après erreur de configuration"

# 1. Arrêt de Patroni
log_info "Étape 1 : Arrêt de Patroni sur tous les nœuds"
# Local / SSH
systemctl stop patroni || log_warn "Patroni était déjà arrêté ou introuvable."

# 2. Lancement manuel de PostgreSQL (Rappel)
log_info "Étape 2 : Pour diagnostiquer, lancez PostgreSQL manuellement :"
log_info "/usr/pgsql-17/bin/postgres -D /datas/postgres"

# 5/6. Vérification / Correction DCS via ETCD
log_info "Étape 5/6 : Vérification de la configuration DCS dans ETCD"
# Note : Utilise les variables ETCD de common.sh
if etcdctl get /service/patroni-cluster/config &> /dev/null; then
    log_info "Configuration DCS trouvée."
    read -p "Souhaitez-vous SUPPRIMER la configuration DCS pour forcer le rechargement du local ? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        etcdctl del /service/patroni-cluster/config
        log_info "Configuration DCS supprimée."
    fi
else
    log_info "Aucune configuration DCS n'a été trouvée dans ETCD."
fi

# 7. Redémarrage
log_info "Étape 7 : Redémarrage de Patroni"
systemctl start patroni

# 8. Vérification
log_info "Étape 8 : Vérification finale"
# Alternative SSH : ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
docker exec node1 patronictl -c /etc/patroni.yml list

log_info "✅ Procédure de récupération terminée"
