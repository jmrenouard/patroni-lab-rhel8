#!/bin/bash
# extract_rpms.sh
# Extraction robuste des URLs RPM par analyse repoquery.

# Essayer de charger les variables d'environnement
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

IMAGE_BASE="patroni-rhel8:latest"
FALLBACK_IMAGE="registry.access.redhat.com/ubi8/ubi:latest"
OUTPUT_FILE="rpms_urls.txt"

echo "🔍 Analyse de l'environnement pour l'extraction des RPMs..."

# Vérification si l'image de base existe
if ! docker image inspect "$IMAGE_BASE" >/dev/null 2>&1; then
    echo "⚠️  Image $IMAGE_BASE non trouvée localement."
    echo "ℹ️  Utilisation de l'image de secours $FALLBACK_IMAGE."
    IMAGE_BASE=$FALLBACK_IMAGE
    SETUP_REPOS=true
else
    echo "✅ Image $IMAGE_BASE détectée."
    SETUP_REPOS=false
fi

echo "🚀 Démarrage du conteneur d'extraction..."

# Script de préparation des dépôts
# On désactive GPG de manière TRÈS agressive
PREPARE_REPOS="
    dnf install -y dnf-plugins-core > /dev/null 2>&1
    if [ \"$SETUP_REPOS\" = \"true\" ]; then
        dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm > /dev/null 2>&1
    fi
    # Désactivation totale des vérifications GPG dans les fichiers repo
    find /etc/yum.repos.d/ -name '*.repo' -exec sed -i 's/gpgcheck.*/gpgcheck=0/g' {} +
    find /etc/yum.repos.d/ -name '*.repo' -exec sed -i 's/repo_gpgcheck.*/repo_gpgcheck=0/g' {} +
    # On désactive les dépôts PostgreSQL inutiles pour éviter les conflits et lenteurs
    dnf config-manager --set-disabled 'pgdg1[34568]' pgdg-rhel8-extras > /dev/null 2>&1
    dnf -y module disable postgresql > /dev/null 2>&1 || true
    dnf config-manager --set-enabled pgdg17 pgdg-common epel > /dev/null 2>&1
"

# Exécution de la commande repoquery
docker run --rm "$IMAGE_BASE" /bin/bash -c "
    $PREPARE_REPOS
    echo '📥 Récupération des URLs via repoquery (cela peut prendre quelques minutes)...' >&2
    
    # On spécifie les cibles
    TARGETS=\"postgresql17-server postgresql17-contrib patroni-etcd patroni pgbouncer etcd\"
    
    # On utilise repoquery pour extraire les URLs des packages disponibles
    # Note: --resolve --requires est optionnel mais utile pour l'air-gap complet
    dnf repoquery --available --location \$TARGETS 2>/dev/null | grep '^http' | sort -u
" > "$OUTPUT_FILE"

# Vérification du résultat
if [ -s "$OUTPUT_FILE" ]; then
    LINES=$(wc -l < "$OUTPUT_FILE")
    echo "✅ Extraction réussie ! $LINES URLs ont été enregistrées dans $OUTPUT_FILE."
    echo "💡 Vous pouvez maintenant utiliser ce fichier pour télécharger les paquets en mode air-gap."
else
    echo "❌ L'extraction a échoué (fichier vide)."
    echo "🛠️  Diagnostic : Vérifiez la connectivité réseau du conteneur."
    exit 1
fi
