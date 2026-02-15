# Sauvegarde Incrémentale

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/etcd/backup_incremental.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/etcd/backup_incremental.sh)

## Objectifs:
Capturer en continu toutes les modifications (PUT/DELETE) effectuées sur le cluster etcd depuis le dernier snapshot complet.

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Snapshot full récent nécessaire.
- **Enregistrer les informations critiques :** Révision de début.
- Un snapshot full récent pour identifier la révision de départ.
- Outil `jq` installé pour le parsing JSON.
- `etcdctl` configuré avec les certificats TLS.

## Contraintes:
- **Noeud à noeud :** Non (écoute le flux de mutations global).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Interruption du flux (Watch) | Perte de traçabilité des modifications pendant la coupure. | Mettre en place un mécanisme de reconnexion automatique. |
| Taille du fichier journal | Consommation importante de stockage si le volume de transactions est élevé. | Surveiller la taille du fichier `.log`. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Récupération de la révision | `LAST_REV=$(etcdutl snapshot status backup_full.db --write-out=json \| jq .revision)` | Identifie le point de départ depuis le dernier snapshot. |
| 2 | Capture du flux incremental | `etcdctl watch / --prefix --rev=$((LAST_REV + 1)) > etcd_incremental_$(date +%Y%m%d).log` | Enregistre en continu les changements dans un fichier. |
