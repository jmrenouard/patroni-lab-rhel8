#!/bin/bash
# extraction_rpms.sh
# Extraction robuste des URLs RPM par analyse HTML des dépôts si repoquery échoue.

source .env

IMAGE_BASE="patroni-rhel8:latest"
OUTPUT_FILE="rpms_urls.txt"

echo "🔍 Extraction des URLs RPM (Méthode Hybride)..."

# 1. Tentative via dnf repoquery (plus propre si ça marche)
docker run --rm $IMAGE_BASE /bin/bash -c "
    dnf install -y dnf-plugins-core > /dev/null 2>&1
    dnf repoquery --requires --resolve --recursive --location \
        postgresql17-server patroni etcd | grep '^http' | sort -u
" > $OUTPUT_FILE

# 2. Si le fichier est vide ou petit, on tente une analyse brute des dépôts
if [ ! -s $OUTPUT_FILE ] || [ $(wc -l < $OUTPUT_FILE) -lt 5 ]; then
    echo "⚠️  Repoquery incomplet. Passage en mode analyse HTML/BaseURL..."
    
    # On récupère les baseurl des repos activés
    BASE_URLS=$(docker run --rm $IMAGE_BASE dnf config-manager --dump | grep baseurl | awk '{print $3}' | sort -u)
    
    for URL in $BASE_URLS; do
        echo "🌐 Scan de $URL ..."
        # Note: Dans un vrai environnement air-gap, l'utilisateur devra fournir ces fichiers.
        # Ici on simule la récupération des URLs pour le manifest.
        curl -s $URL/Packages/ | grep -o 'href="[^"]*.rpm"' | sed "s/href=\"/$URL\/Packages\//;s/\"//" >> $OUTPUT_FILE
    done
fi

# Nettoyage et dédoublonnage
sort -u $OUTPUT_FILE -o $OUTPUT_FILE

echo "✅ URLs extraites dans $OUTPUT_FILE ($(wc -l < $OUTPUT_FILE) paquets trouvés)"
