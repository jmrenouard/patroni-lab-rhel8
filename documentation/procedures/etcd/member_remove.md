# Retrait propre d'un nœud

## Objectifs:
Retirer définitivement un membre sain du cluster etcd, par exemple lors d'un décommissionnement progressif d'un serveur.

## Prérequis:
- **État du service :** Démarré (pour l'API membre) puis Arrêté (localement).
- **Sauvegardes avant l'opération :** Sauvegarde DB complète recommandée.
- **Enregistrer les informations critiques :** ID du membre, Peer-URLs.
- Accès administratif au cluster.
- Identification de l'ID du membre à retirer (`MEMBER_ID`).

## Contraintes:
- **Noeud à noeud :** Non (l'action de retrait est répliquée via l'API).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Rupture de quorum | Si le retrait amène le nombre de nœuds sous le seuil de majorité (ex: passage de 3 à 2), le cluster devient instable. | S'assurer qu'un nombre impair de nœuds est maintenu ou que le quorum reste atteint. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Identification | `etcdctl member list -w table` | Copier l'ID du nœud cible. |
| 2 | Retrait logique | `etcdctl member remove <MEMBER_ID>` | Informe le cluster du départ du membre. |
| 3 | Arrêt physique | `sudo systemctl stop etcd` | Arrête le service sur le serveur décommissionné. |
