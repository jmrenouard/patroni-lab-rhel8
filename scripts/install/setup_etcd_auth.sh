#!/bin/bash
set -e

# Load credentials from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "🔐 Initialisation de l'authentification ETCD (via HTTPS)..."

# CACERT, CERT and KEY pour les commandes etcdctl
ETCD_CMD="docker exec etcd1 etcdctl --endpoints=https://etcd1:2379 --cacert=/certs/ca.crt"
if [ "${VERIFY_CLIENT_CERT}" = "true" ]; then
  ETCD_CMD="$ETCD_CMD --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key"
fi

# Attendre qu'ETCD soit prêt
until $ETCD_CMD endpoint health; do
  echo "En attente d'ETCD..."
  sleep 2
done

# 1. Créer l'utilisateur root (si non existant) et lui donner le rôle root
echo "Création de l'utilisateur root..."
$ETCD_CMD user add root --new-user-password="${ETCD_ROOT_PASSWORD}" || echo "Root déjà existant."
$ETCD_CMD user grant-role root root || echo "Rôle root déjà accordé."

# 2. Activer l'authentification
echo "Activation de l'auth..."
$ETCD_CMD auth enable || echo "Auth déjà activée."

# 3. Créer l'utilisateur patroni et son rôle
echo "Création utilisateur/rôle patroni..."
$ETCD_CMD --user root:"${ETCD_ROOT_PASSWORD}" role add patroni || echo "Rôle patroni déjà existant."
$ETCD_CMD --user root:"${ETCD_ROOT_PASSWORD}" role grant-permission patroni --prefix=true readwrite "${NAMESPACE:-/service/}"
$ETCD_CMD --user root:"${ETCD_ROOT_PASSWORD}" user add "${ETCD_PATRONI_USER}" --new-user-password="${ETCD_PATRONI_PASSWORD}" || echo "Utilisateur patroni déjà existant."
$ETCD_CMD --user root:"${ETCD_ROOT_PASSWORD}" user grant-role "${ETCD_PATRONI_USER}" patroni

echo "✅ Authentification ETCD opérationnelle."
