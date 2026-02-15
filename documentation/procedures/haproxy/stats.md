# Interface de Statistiques HAProxy

## Objectifs:
Utiliser l'interface graphique de HAProxy pour visualiser l'état détaillé des connexions et la disponibilité des nœuds PostgreSQL.

> [!NOTE]
> **Automatisation :** Un script d'aide pour vérifier l'accès est disponible : 
> [scripts/procedures/haproxy/stats.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/haproxy/stats.sh)

## Accès:
- **URL :** `https://<IP_HAPROXY>:8404/`
- **Authentification :** Identifiants définis dans `.env` (`ADMIN_HAPROXY_USER`).

## Éléments à surveiller:

### 1. Section `pg_primary` (Backend)
- Un seul nœud doit être en état **UP** (vert foncé).
- Les autres nœuds doivent être en **MAINT** ou **DOWN** (gris/rouge) car ils ne répondent pas au check `/primary`.

### 2. Section `pg_replicas` (Backend)
- Les nœuds esclaves doivent être en état **UP**.
- Le leader peut être **UP** ou **DOWN** selon la configuration choisie pour le pool de lecture.

### 3. Sessions Actives (`Scur`)
- Surveiller le nombre de sessions en cours pour détecter des fuites de connexion ou une surcharge.

> [!TIP]
> Si tous les nœuds sont DOWN dans `pg_primary`, vérifiez si Patroni est en mode pause ou si le Leader PostgreSQL est arrêté.
