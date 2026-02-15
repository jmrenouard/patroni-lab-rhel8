# Diagnostic de Santé Patroni

## Objectifs:
Évaluer instantanément la santé du cluster PostgreSQL, identifier le Leader actuel et vérifier l'état de la réplication sur les membres.

## Prérequis:
- **État du service :** Démarré (Online).
- **Accès :** Accès shell sur l'un des nœuds (node1, node2 ou node3).
- `patronictl` configuré (via `/etc/patroni.yml`).

## Contraintes:
- Aucune interruption de service.

## Portée:
Global (Cluster)

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| API Rest injoignable | Diagnostic incomplet si Patroni ne répond pas sur un nœud. | Vérifier le service Patroni via `systemctl status patroni`. |

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/diagnostic.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/diagnostic.sh)

### 1. Vue d'ensemble du Cluster
Affiche la liste des membres, leur état, leur rôle et leur retard de réplication.

**Docker :**
```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml list"
```

### 2. Statut détaillé d'un membre
Vérifier les détails d'un nœud spécifique via l'API.

**Local / Docker (via curl) :**
```bash
# Exemple pour node1
curl -s -k -u "admin:secret" https://localhost:8008/health
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "curl -s -k -u \"admin:secret\" https://localhost:8008/health"
```

### 3. Configuration Dynamique
Vérifier les paramètres DCS (Distributed Configuration Store).

**Docker :**
```bash
docker exec node1 patronictl -c /etc/patroni.yml show-config
```

**SSH (Alternative) :**
```bash
ssh ${PATRONI_NODE} "patronictl -c /etc/patroni.yml show-config"
```

### 4. Analyse des logs
En cas d'instabilité, surveiller les logs de Patroni.
```bash
journalctl -u patroni.service -f
```
