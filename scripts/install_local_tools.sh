#!/bin/bash
# install_local_tools.sh
# Installe les outils clients nécessaires pour tester le cluster en local (hors Docker).

echo "📦 Installation des outils clients locaux (etcdctl, psql, curl)..."

# 1. PostgreSQL Client
if ! command -v psql &> /dev/null; then
    echo "🐘 Installation de psql..."
    sudo dnf install -y postgresql || sudo apt-get install -y postgresql-client
else
    echo "🐘 psql déjà présent."
fi

# 2. ETCD Client (etcdctl)
if ! command -v etcdctl &> /dev/null; then
    echo "⚡ Installation de etcdctl..."
    # Téléchargement binaire simple pour compatibilité large
    ETCD_VER=v3.5.0
    GOOGLE_URL=https://storage.googleapis.com/etcd
    GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
    DOWNLOAD_URL=${GOOGLE_URL}

    curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/ --strip-components=1
    sudo mv /tmp/etcdctl /usr/local/bin/
    rm -rf /tmp/etcd*
else
    echo "⚡ etcdctl déjà présent."
fi

# 3. OpenSSL & Curl (Généralement présents)
echo "🔍 Vérification OpenSSL et Curl..."
command -v openssl && command -v curl

echo "✅ Outils installés. Vous pouvez maintenant lancer les scripts de test."
