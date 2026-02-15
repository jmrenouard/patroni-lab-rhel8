# Maintenance du Cluster Patroni

## Objectifs:
Désactiver temporairement la gestion automatique du cluster (Failover) pour effectuer des opérations de maintenance manuelles sur PostgreSQL ou l'infrastructure sans déclencher de bascule.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/maintenance.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/maintenance.sh)

### 1. Activer le mode Maintenance (Pause)
Cette commande place le cluster en mode `paused`. Patroni ne tentera plus de promouvoir de nœud ou de gérer l'état de PostgreSQL.

**Docker :**
```bash
docker exec node1 patronictl -c /etc/patroni.yml pause
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml pause"
```

### 2. Vérification du statut
L'état du cluster doit afficher `Maintenance` ou `Paused`.

**Docker :**
```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
```

### 3. Désactiver le mode Maintenance (Resume)
Une fois les opérations terminées, rétablir la gestion automatique.

**Docker :**
```bash
docker exec node1 patronictl -c /etc/patroni.yml resume
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml resume"
```

### 4. Rechargement de la configuration
Appliquer des modifications faites dans `patroni.yml` sans redémarrer le service (si possible).
```bash
docker exec node1 patronictl -c /etc/patroni.yml reload <nom_du_noeud>
```
