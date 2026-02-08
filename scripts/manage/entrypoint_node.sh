#!/bin/bash
# entrypoint_node.sh
# Prépare les certificats et lance la commande demandée (supervisord ou pgbouncer)
# Peut switcher vers un utilisateur non-root si RUN_AS_USER est défini.

set -e

# Dossier local pour les certificats
LOCAL_CERT_DIR="/etc/patroni/certs"
mkdir -p "$LOCAL_CERT_DIR"

echo "🔐 [ENTRYPOINT] Préparation des certificats..."

# Copier les certificats du montage /certs vers le dossier local
if [ -d "/certs" ]; then
    cp /certs/*.crt "$LOCAL_CERT_DIR/" 2>/dev/null || true
    cp /certs/*.key "$LOCAL_CERT_DIR/" 2>/dev/null || true
    
    # On chown le dossier et les fichiers pour l'utilisateur cible
    TARGET_USER="${RUN_AS_USER:-root}"
    chown -R "$TARGET_USER:$TARGET_USER" "$LOCAL_CERT_DIR"
    # Toujours s'assurer que postgres peut lire les certificats
    chown -R postgres:postgres /etc/patroni/certs
    chmod 755 /etc/patroni/certs
    chmod 600 /etc/patroni/certs/*.key
    chmod 644 /etc/patroni/certs/*.crt

    echo "✅ [ENTRYPOINT] Certificats préparés dans /etc/patroni/certs (Propriétaire: postgres)"
else
    echo "⚠️  [ENTRYPOINT] Dossier /certs non trouvé."
fi

# Switcher d'utilisateur si nécessaire pour lancer la commande finale
if [ -n "$RUN_AS_USER" ] && [ "$RUN_AS_USER" != "root" ]; then
    echo "👤 [ENTRYPOINT] Exécution en tant que $RUN_AS_USER..."
    # On utilise su pour switcher d'utilisateur tout en gardant l'environnement complet
    exec su -s /bin/bash "$RUN_AS_USER" -c "$*"
else
    echo "👤 [ENTRYPOINT] Exécution en tant que root..."
    exec "$@"
fi
