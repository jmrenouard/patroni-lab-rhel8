# Bascule Manuelle (Switchover)

## Objectifs:
Transférer le rôle de Leader d'un nœud vers un autre de manière contrôlée et sans perte de données. Utile pour la maintenance préventive d'un hôte.

## Prérequis:
- Cluster sain (tous les nœuds en état `running`).
- Réplication à jour (pas de `lag` significatif).

## Contraintes:
- Brève interruption des écritures pendant la promotion (quelques secondes).

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/switchover.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/switchover.sh)

### 1. Lancement de la bascule
Utiliser la commande interactive pour choisir la cible.

**Docker :**
```bash
docker exec -it node1 patronictl -c /etc/patroni.yml switchover
```

**SSH (Alternative) :**
```bash
ssh -t ${PATRONI_NODE} "patronictl -c /etc/patroni.yml switchover"
```

### 2. Validation
Suivre les instructions à l'écran :
1. Confirmer le leader actuel.
2. Sélectionner le nœud cible pour la promotion.
3. Spécifier le moment (immédiat ou programmé).
4. Confirmer l'action.

### 3. Vérification
Vérifier que le changement de rôle est effectif.
```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

> [!IMPORTANT]
> HAProxy redirigera automatiquement le trafic RW vers le nouveau leader grâce aux healthchecks `/primary`.
