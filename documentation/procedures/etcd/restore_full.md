# Restauration Full (Disaster Recovery)

## Objectifs:
Restaurer l'intégralité d'un cluster etcd à partir d'un fichier de snapshot suite à une perte majeure de données ou de quorum.

## Prérequis:
- **État du service :** Arrêté sur TOUS les nœuds (Offline).
- **Sauvegardes avant l'opération :** Copie de l'ancien `data-dir` conseillée.
- **Enregistrer les informations critiques :** Noms des membres, Peer-URLs, Cluster Token.
- **Service `etcd` arrêté sur TOUS les nœuds.**
- Fichier de snapshot (`.db`) intègre et disponible.
- Binaire `etcdutl` installé.

## Contraintes:
- **Noeud à noeud :** Oui (la commande de restauration doit être adaptée et exécutée individuellement sur chaque membre).

## Portée:
Global (réinitialise l'état de l'ensemble du cluster)

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Incohérence des paramètres | Échec de la reformation du cluster si les noms ou IPs sont mal saisis. | Valider soigneusement les drapeaux `--initial-cluster`. |
| Écrasement de données | Perte définitive des données non sauvegardées présentes sur le disque. | Sauvegarder l'ancien répertoire de données (`data-dir`) par précaution. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Arrêt du cluster | `sudo systemctl stop etcd` | Doit être fait sur tous les membres simultanément. |
| 2 | Restauration (Exemple infra0) | `etcdutl snapshot restore backup.db --name infra0 --initial-cluster infra0=https://10.0.1.10:2380,infra1=https://10.0.1.11:2380 --initial-cluster-token etcd-cluster-1 --initial-advertise-peer-urls https://10.0.1.10:2380 --data-dir /var/lib/etcd_new` | Recrée le répertoire de données à partir du snapshot. |
| 3 | Redémarrage | `sudo systemctl start etcd` | Relancer le service sur chaque nœud une fois restauré. |
