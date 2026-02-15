# Sauvegarde à chaud (Snapshot Full)

## Objectifs:
Créer une sauvegarde complète de l'état du cluster etcd sans interruption de service pour permettre une récupération après sinistre.

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Non requis (est une sauvegarde).
- **Enregistrer les informations critiques :** Endpoints, révision actuelle.
- Accès au binaire `etcdctl`.
- Variables d'environnement TLS configurées :
  ```bash
  export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
  export ETCDCTL_CACERT=/etc/etcd/ca.pem
  export ETCDCTL_CERT=/etc/etcd/cert.pem
  export ETCDCTL_KEY=/etc/etcd/key.pem
  export ETCDCTL_API=3
  ```

## Contraintes:
- **Noeud à noeud :** Non (peut être exécuté depuis n'importe quel membre sain du cluster).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Espace disque insuffisant | Échec de la sauvegarde, saturation possible de la partition. | Vérifier l'espace libre avant l'exécution. |
| Impact sur les performances | Augmentation temporaire des IO disque et de l'utilisation CPU. | Exécuter pendant les heures de faible charge si possible. |

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/etcd/backup_full.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/etcd/backup_full.sh)

| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Export du snapshot | **Local/Docker :** `etcdctl snapshot save backup_$(date +%Y%m%d).db`<br>**SSH :** `ssh ${ETCD_NODE} "etcdctl snapshot save backup_$(date +%Y%m%d).db"` | Capture l'état actuel de la base de données. |
| 2 | Vérification d'intégrité | **Local/Docker :** `etcdutl snapshot status backup_$(date +%Y%m%d).db -w table`<br>**SSH :** `ssh ${ETCD_NODE} "etcdutl snapshot status backup_$(date +%Y%m%d).db -w table"` | Vérifie que le fichier généré est valide et lisible. |
