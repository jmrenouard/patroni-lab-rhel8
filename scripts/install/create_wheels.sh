#!/bin/bash
# create_wheels.sh
# Ce script crée des paquets wheel pour patroni-etcd3 et ses dépendances.

echo "📦 Création des wheels pour l'installation hors-ligne..."

mkdir -p wheels
/usr/bin/python3.12 -m pip download \
    --dest wheels \
    "urllib3<2.0.0" \
    etcd3

echo "✅ Wheels créés dans le dossier ./wheels"
echo "💡 Usage hors-ligne : pip install --no-index --find-links=./wheels etcd3"
