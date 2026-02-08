#!/bin/bash
# setup_configs.sh
# Déploie les configurations en remplaçant les variables d'environnement.

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "⚙️  Expansion des configurations..."

# Expansion pour HAProxy
envsubst < haproxy/haproxy.cfg > haproxy/haproxy.cfg.rendered

# Expansion pour PgBouncer
envsubst < pgbouncer/pgbouncer.ini > pgbouncer/pgbouncer.ini.rendered

# Pour Patroni
envsubst < patroni/patroni.yml > patroni/patroni.yml.rendered

echo "✅ Configurations générées (.rendered)."

echo "✅ Configurations générées (.rendered)."
