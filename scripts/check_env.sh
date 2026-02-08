#!/bin/bash
# check_env.sh
# Vérifie la présence de toutes les variables nécessaires dans le fichier .env

ENV_FILE=".env"
REQUIRED_VARS=(
    "SCOPE" "NAMESPACE" "POSTGRES_USER" "POSTGRES_PASSWORD"
    "REPLICATOR_USER" "REPLICATOR_PASSWORD" "ETCD_ROOT_PASSWORD"
    "ETCD_PATRONI_USER" "ETCD_PATRONI_PASSWORD"
    "PATRONI_API_USER" "PATRONI_API_PASSWORD"
    "ADMIN_HAPROXY_USER" "ADMIN_HAPROXY_PASSWORD"
    "ETCD_HOSTS" "CACERT_PATH"
)

echo "🔍 Vérification du fichier $ENV_FILE..."

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Erreur : Fichier $ENV_FILE manquant."
    exit 1
fi

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE"; then
        echo "⚠️  Variable manquante : $var"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -eq 0 ]; then
    echo "✅ Toutes les variables obligatoires sont présentes."
else
    echo "❌ $MISSING variables manquantes dans le .env."
    exit 1
fi
