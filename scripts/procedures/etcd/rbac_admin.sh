#!/bin/bash
# Script généré pour la procédure : Gestion des Accès (RBAC)
# Document source : documentation/procedures/etcd/rbac_admin.md

set -e

# Chargement de la configuration commune
PROC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROC_DIR/../common.sh"

log_info "Début de la procédure : Gestion des Accès (RBAC)"

# Note : Une fois l'auth activée, les commandes suivantes nécessitent --user root:password
# Ce script suppose que vous avez configuré ETCD_ROOT_PASSWORD dans .env

ROOT_USER="root"
ROOT_PWD="${ETCD_ROOT_PASSWORD:-MyStrongPassword}"

# Étape 1 : Création de l'admin root
log_info "Étape 1 : Création de l'utilisateur root (si non existant)"
etcdctl user add "$ROOT_USER:$ROOT_PWD" || log_warn "Root déjà existant."

# Étape 2 : Création d'un rôle (exemple app-manager)
ROLE_NAME="app-manager"
log_info "Étape 2 : Création du rôle $ROLE_NAME"
etcdctl --user "$ROOT_USER:$ROOT_PWD" role add "$ROLE_NAME" || log_warn "Rôle $ROLE_NAME déjà existant."

# Étape 3 : Attribution de permissions
PREFIX="/app/data/"
log_info "Étape 3 : Attribution des permissions readwrite sur $PREFIX au rôle $ROLE_NAME"
etcdctl --user "$ROOT_USER:$ROOT_PWD" role grant-permission "$ROLE_NAME" readwrite --prefix "$PREFIX"

# Étape 4 : Liaison utilisateur/rôle
APP_USER="${1:-myuser}"
log_info "Étape 4 : Liaison de l'utilisateur $APP_USER au rôle $ROLE_NAME"
etcdctl --user "$ROOT_USER:$ROOT_PWD" user add "$APP_USER" || log_warn "Utilisateur $APP_USER déjà existant."
etcdctl --user "$ROOT_USER:$ROOT_PWD" user grant-role "$APP_USER" "$ROLE_NAME"

# Étape 5 : Activation globale
log_info "Étape 5 : Activation globale de l'authentification"
etcdctl --user "$ROOT_USER:$ROOT_PWD" auth enable || log_warn "L'authentification est peut-être déjà activée."

log_info "✅ Procédure RBAC terminée."
