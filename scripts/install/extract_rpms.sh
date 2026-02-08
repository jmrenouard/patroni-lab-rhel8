#!/bin/bash
# extract_rpms.sh
# Extraction robuste des URLs RPM par analyse repoquery.

# Essayer de charger les variables d'environnement
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

IMAGE_BASE="patroni-rhel8-base:latest"
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

# Exécution de la commande dnf download pour tout récupérer d'un coup
# Utilisation d'un heredoc non-expansé (<<'EOF') pour éviter les problèmes d'échappement bash
docker run --rm -i -e SETUP_REPOS="$SETUP_REPOS" "$IMAGE_BASE" /bin/bash <<'EOF' > "$OUTPUT_FILE"
    set -e
    # On installe les outils nécessaires si besoin (dnf download est dans dnf-plugins-core)
    dnf install -y dnf-plugins-core > /dev/null 2>&1

    # On prepare les repos si image de base UBI
    if [ "$SETUP_REPOS" = "true" ]; then
        dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm > /dev/null 2>&1
    fi
    find /etc/yum.repos.d/ -name '*.repo' -exec sed -i 's/gpgcheck.*/gpgcheck=0/g' {} +
    find /etc/yum.repos.d/ -name '*.repo' -exec sed -i 's/repo_gpgcheck.*/repo_gpgcheck=0/g' {} +
    
    # On active spécifiquement les dépôts nécessaires
    dnf config-manager --set-disabled 'pgdg1[34568]' > /dev/null 2>&1
    dnf config-manager --set-enabled pgdg17 pgdg-common pgdg-rhel8-extras epel > /dev/null 2>&1
    dnf -y module disable postgresql > /dev/null 2>&1 || true

    echo '📥 Résolution des dépendances et extraction...' >&2

    TARGETS="postgresql17-server postgresql17-contrib patroni-etcd patroni pgbouncer etcd"
    
    # On désactive le plugin pour tout le monde
    DNF="dnf --disableplugin=subscription-manager"

    # Liste brute des noms (cibles + dépendancess)
    echo "🔍 Analyse des dépendances pour $TARGETS..." >&2
    ALL_PKGS=$($DNF repoquery --available --resolve --requires --recursive $TARGETS --queryformat "%{name}" | sort -u | grep -v "Subscription Management")
    
    # On ajoute les cibles
    FINAL_LIST=$(echo -e "${TARGETS// /\n}\n$ALL_PKGS" | grep -v "^$" | sort -u)
    COUNT=$(echo "$FINAL_LIST" | wc -l)
    echo "📦 $COUNT paquets identifiés. Extraction en cours..." >&2

    # boucle simple pour commencer
    for pkg in $FINAL_LIST; do
        [ -z "$pkg" ] && continue
        # On récupère les infos (Nom;Nom-Version-Release.Arch)
        # On évite %{nevra} qui peut bugger sur certaines versions de DNF
        INFO=$($DNF repoquery --available --queryformat "%{name};%{name}-%{version}-%{release}.%{arch}" "$pkg" | grep ";" | head -n 1)
        URL=$($DNF repoquery --available --location "$pkg" | grep "^http" | head -n 1)
        
        if [ -n "$INFO" ] && [ -n "$URL" ]; then
            echo "$INFO;$URL"
            echo -n "." >&2
        fi
    done
    echo -e "\n✅ Extraction terminée." >&2
EOF

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
