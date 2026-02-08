# Remplacement d'un nœud (Swap)

## Objectifs:
Remplacer un membre du cluster par un nouveau (suite à une panne matérielle ou un changement d'IP) sans interruption de service globale.

## Prérequis:
- **État du service :** Démarré (sur les membres sains).
- **Sauvegardes avant l'opération :** Sauvegarde complète obligatoire.
- **Enregistrer les informations critiques :** IDs, IPs, Cluster Token.
- Nouvelle instance prête avec etcd installé.
- Sauvegarde à jour avant l'opération.
- Quorum actuellement atteint sur les membres restants.

## Contraintes:
- **Noeud à noeud :** Oui (retrait sur les membres sains, configuration sur le nouveau).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Mauvais Cluster State | Le nouveau nœud tente de créer un nouveau cluster au lieu de rejoindre l'existant. | Toujours utiliser `ETCD_INITIAL_CLUSTER_STATE=existing`. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Retrait de l'ancien | `etcdctl member remove <OLD_ID>` | Supprime l'ancienne identité du cluster. |
| 2 | Ajout du nouveau | `etcdctl member add <NAME> --peer-urls=https://<IP>:2380` | Déclare le nouveau membre. |
| 3 | Initialisation | `export ETCD_INITIAL_CLUSTER_STATE=existing && sudo systemctl start etcd` | Démarre le nouveau membre en mode "jonction". |
