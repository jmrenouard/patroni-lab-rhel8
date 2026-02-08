#!/bin/bash
# Script généré pour la procédure : Défragmemtation Membres
# Document source : documentation/procedures/etcd/maintenance_defrag.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Défragmentation etcd"

# Étape 1 : Vérification de la fragmentation
log_info "Étape 1 : État actuel de la base (Vérifiez la colonne DB SIZE vs APPLIED INDEX)"
etcdctl endpoint status --cluster -w table

# Étape 2 : Défragmentation par cluster
log_info "Étape 2 : Exécution de la défragmentation sur TOUT le cluster"
etcdctl defrag --cluster

# Étape 3 : Vérification post-opération
log_info "Étape 3 : Vérification de la taille de la base après défragmentation"
etcdctl endpoint status --cluster -w table

log_info "✅ Défragmentation terminée."
