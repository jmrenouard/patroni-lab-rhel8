# Réinitialisation d'un Nœud Zombie

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible (à lancer sur un nœud sain) : 
> [scripts/procedures/etcd/member_reset_zombie.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/etcd/member_reset_zombie.sh)

## Objectifs:
Forcer la réintégration d'un membre dont le répertoire de données est corrompu ou qui a perdu sa synchronisation avec le cluster de manière irrécupérable.

## Prérequis:
- **État du service :** Arrêté (sur le nœud zombie uniquement).
- **Sauvegardes avant l'opération :** Non applicable sur le nœud corrompu (état reconstruit depuis le cluster).
- **Enregistrer les informations critiques :** ID du zombie, Peer-URLs, Cluster Name.
- Accès SSH au serveur "zombie".
- Quorum maintenu par les autres membres.

## Contraintes:
- **Noeud à noeud :** Oui (actions à la fois sur le cluster et en local sur le zombie).

## Portée:
Local (Données) / Global (Membre)

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Perte de données locales | Toutes les données non répliquées sur ce nœud seront perdues. | Aucune si le nœud est déjà corrompu ; l'état sera reconstruit depuis le cluster. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Retrait logique | `etcdctl member remove <ZOMBIE_ID>` | Nettoie la configuration globale du cluster. |
| 2 | Nettoyage local | `sudo rm -rf /var/lib/etcd/*` | Supprime les données corrompues sur le zombie. |
| 3 | Ré-ajout | `etcdctl member add <NAME> --peer-urls=https://<IP>:2380` | Enregistre à nouveau le membre. |
| 4 | Relance propre | `export ETCD_INITIAL_CLUSTER_STATE=existing && sudo systemctl start etcd` | Redémarre avec un état vierge pour synchronisation complète. |
