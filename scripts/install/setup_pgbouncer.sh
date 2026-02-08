#!/bin/bash
# setup_pgbouncer.sh
# Génère le fichier userlist.txt pour PgBouncer à partir du .env

source .env

USERLIST="pgbouncer/userlist.txt"

echo "🔑 Génération de $USERLIST..."

# Format: "username" "password"
# On peut utiliser le mot de passe en clair ou un hash md5. 
# Pour simplifier avec PgBouncer, on utilise le format "user" "password"

cat > $USERLIST <<EOF
"${POSTGRES_USER}" "${POSTGRES_PASSWORD}"
"${REPLICATOR_USER}" "${REPLICATOR_PASSWORD}"
EOF

chmod 644 $USERLIST
echo "✅ $USERLIST généré."
