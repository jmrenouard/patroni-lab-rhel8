# Bascule Automatique (Failover)

## Objectifs:
Comprendre le comportement de Patroni lors d'une panne du Leader et savoir comment intervenir si le failover ne se termine pas correctement.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/failover.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/failover.sh)

### 1. Mécanisme de Failover
En cas de perte du Leader (crash, perte réseau), les replicas entament une élection via ETCD. Le nœud ayant le moins de retard et la plus haute priorité (`failover_priority`) est promu.

### 2. Détection d'un Failover en cours
Surveiller les logs ou la liste des membres.

**Docker :**
```bash
# Un nœud apparaîtra comme "Leader" tandis que l'ancien sera "stopped" ou "unknown"
docker exec node1 patronictl -c /etc/patroni.yml list
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
```

### 3. Réintégration de l'ancien Leader
Une fois le problème résolu sur l'ancien leader, redémarrez le service. Patroni utilisera `pg_rewind` pour synchroniser le nœud avec le nouveau leader sans reconstruction complète.

**Local / SSH :**
```bash
systemctl start patroni
```

### 4. Forcer un Failover (Urgence)
Si un switchover normal échoue et que le leader est bloqué :

**Docker :**
```bash
docker exec -it node1 patronictl -c /etc/patroni.yml failover
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml failover"
```
> [!CAUTION]
> L'utilisation de `failover` au lieu de `switchover` peut entraîner une perte de données si les réplicas ne sont pas synchronisés.
