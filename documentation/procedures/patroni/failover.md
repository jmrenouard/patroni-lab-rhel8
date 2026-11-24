# Bascule Automatique (Failover)

## Objectifs:
Comprendre le comportement de Patroni lors d'une panne du Leader et savoir comment intervenir si le failover ne se termine pas correctement.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/failover.sh](../../../scripts/procedures/patroni/failover.sh)

### 1. Mécanisme de Failover
En cas de perte du Leader (crash, perte réseau), les replicas entament une élection via ETCD. Le nœud ayant le moins de retard et la plus haute priorité (`failover_priority`) est promu.

### 2. Détection d'un Failover en cours
Surveiller les logs ou la liste des membres.

```bash
# Un nœud apparaîtra comme "Leader" tandis que l'ancien sera "stopped" ou "unknown"
patronictl -c /etc/patroni.yml list
```

### 3. Réintégration de l'ancien Leader
Une fois le problème résolu sur l'ancien leader, redémarrez le service. Patroni utilisera `pg_rewind` pour synchroniser le nœud avec le nouveau leader sans reconstruction complète.

**Dans le lab Docker (Supervisord) / Hôte nu (Systemd) :**
```bash
# Conteneur Docker géré par supervisord
docker exec node1 supervisorctl start patroni
# Ou sur hôte systemd :
systemctl start patroni
```

### 4. Forcer un Failover (Urgence)
Si un switchover normal échoue et que le leader est bloqué :

```bash
patronictl -c /etc/patroni.yml failover
```
> [!CAUTION]
> L'utilisation de `failover` au lieu de `switchover` peut entraîner une perte de données si les réplicas ne sont pas synchronisés.
