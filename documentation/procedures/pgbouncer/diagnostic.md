# Diagnostic de Santé PgBouncer

## Objectifs:
S'assurer que PgBouncer accepte les connexions et transmet correctement les requêtes à HAProxy.

## Prérequis:
- Container `pgbouncer` actif.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/pgbouncer/diagnostic.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/pgbouncer/diagnostic.sh)

### 1. Connexion à la console d'administration
PgBouncer dispose d'une base de données virtuelle nommée `pgbouncer` pour l'administration.

**Docker :**
```bash
docker exec -it pgbouncer psql -U postgres -p 6432 -h localhost pgbouncer
```

**SSH (Alternative) :**
```bash
ssh ${PGBOUNCER_HOST} "psql -U postgres -p 6432 -h localhost pgbouncer"
```

### 2. Vérification de la version et du statut
Dans la console `psql` :
```sql
SHOW CONFIG;
SHOW SERVERS;
```

### 3. Test de connectivité applicative
Passer par le pooler pour joindre la base réelle.

**Local / Docker :**
```bash
psql "host=localhost port=6432 dbname=postgres_rw user=postgres" -c "SELECT now();"
```

**SSH (Alternative) :**
```bash
ssh ${PGBOUNCER_HOST} "psql \"host=localhost port=6432 dbname=postgres_rw user=postgres\" -c \"SELECT now();\""
```

### 4. Analyse des logs
```bash
docker logs pgbouncer -f
```
