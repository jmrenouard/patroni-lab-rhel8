# Gestion des Pools PgBouncer

## Objectifs:
Surveiller l'utilisation des connexions côté client et côté serveur pour optimiser le `pool_size`.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/pgbouncer/pools.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/pgbouncer/pools.sh)

### 1. Afficher les statistiques des pools
Permet de voir combien de clients sont actifs, en attente (`cl_waiting`), ou combien de connexions serveurs sont ouvertes.

```bash
psql -U postgres -p 6432 -h localhost -c "SHOW POOLS" pgbouncer
```

### 2. Forcer le rechargement de la configuration
Si le fichier `pgbouncer.ini` ou `userlist.txt` est modifié.

```bash
psql -U postgres -p 6432 -h localhost -c "RELOAD" pgbouncer
```

### 3. Suspendre / Reprendre le trafic
Utile pour des maintenances très brèves sans couper les connexions clientes (mise en file d'attente).
- **Suspendre :** `PAUSE postgres_rw;`
- **Reprendre :** `RESUME postgres_rw;`

### 4. Déconnexion brutale des clients
Pour libérer toutes les connexions immédiatement.
```sql
KILL postgres_rw;
```
