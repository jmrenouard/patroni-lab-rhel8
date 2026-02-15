# Mise à jour Système et Version Mineure (Patroni/PostgreSQL)

Cette procédure décrit comment appliquer des correctifs de sécurité (OS) ou effectuer des montées en version mineure de PostgreSQL ou Patroni tout en préservant la haute disponibilité du cluster.

## 📋 Objectifs

- Appliquer `dnf update` sur les hôtes RHEL 8 (UBI).
- Monter en version mineure (ex: PG 17.1 -> 17.2).
- Garantir une interruption de service minimale via des bascules contrôlées.

## 🛠️ Description technique

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/minor_upgrade.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/minor_upgrade.sh)

### 1. Préparation (Sur tous les nœuds)

Avant de commencer, validez l'état du cluster :
```bash
patronictl -c /etc/patroni.yml list
```

### 2. Mise à jour des Nœuds Replicas (Séquentiel)

Effectuez ces étapes sur chaque replica, **un par un** :

1. **Mise en maintenance locale** (Optionnel mais recommandé) :
   ```bash
   patronictl -c /etc/patroni.yml pause
   ```
2. **Arrêt du conteneur/service** :
   ```bash
   docker stop <container_id>
   ```
3. **Mise à jour de l'hôte/image** :
   Appliquez les patchs système ou mettez à jour l'image Docker.
4. **Redémarrage** :
   ```bash
   docker start <container_id>
   ```
5. **Sortie de maintenance et vérification** :
   ```bash
   patronictl -c /etc/patroni.yml resume
   patronictl -c /etc/patroni.yml list
   ```
   *Attendez que le nœud soit à nouveau en état `running` et synchronisé avant de passer au suivant.*

### 3. Mise à jour du Nœud Leader

Une fois tous les replicas à jour :

1. **Bascule contrôlée** :
   Transférez le rôle de leader vers un nœud déjà mis à jour.
   ```bash
   patronictl -c /etc/patroni.yml switchover
   ```
2. **Mise à jour de l'ancien leader** :
   Suivez les mêmes étapes que pour les replicas (Arrêt -> Update -> Start).
3. **Vérification finale** :
   Vérifiez que le cluster est complet et que tous les nœuds sont à la nouvelle version si applicable.

## ⚠️ Risques et Mitigations

- **Perte de Quorum** : Ne jamais arrêter plus d'un nœud à la fois.
- **Lag de réplication** : Si le lag est trop important, la bascule (switchover) peut échouer. Vérifier le lag avant de basculer.

---
[Retour à l'index des procédures](../README.md)
