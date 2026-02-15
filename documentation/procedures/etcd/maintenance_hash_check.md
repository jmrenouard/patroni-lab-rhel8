# Vérification de corruption (Hash Check)

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/etcd/maintenance_hash_check.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/etcd/maintenance_hash_check.sh)

## Objectifs:
Détecter d'éventuelles divergences ou corruptions de données entre les différents membres du cluster en comparant leurs empreintes numériques (hash).

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Non requis pour une lecture seule.
- **Enregistrer les informations critiques :** Liste des endpoints à vérifier.
- Cluster en ligne.
- Connectivité réseau vers tous les endpoints du cluster.

## Contraintes:
- **Noeud à noeud :** Non (on interroge tous les nœuds simultanément).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Divergence de hash | Données incohérentes entre les membres, risque de comportement erratique du cluster. | Isoler le nœud fautif, le réinitialiser ou restaurer un snapshot sain. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Vérification des hashs | `etcdctl check hash --endpoints=https://IP1:2379,https://IP2:2379...` | Compare les signatures de stockage entre les membres. |
