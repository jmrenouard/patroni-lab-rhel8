# Mise à jour Système ou Binaires

## Objectifs:
Appliquer des patchs de sécurité ou monter en version les binaires etcd tout en maintenant la haute disponibilité du service.

## Prérequis:
- **État du service :** Arrêté séquentiellement (nœud par nœud).
- **Sauvegardes avant l'opération :** Snapshot full sur chaque nœud avant l'arrêt.
- **Enregistrer les informations critiques :** Version actuelle, ID des membres.
- Cluster avec quorum sain.
- Nouveaux binaires ou dépôts système configurés.
- Sauvegarde (Snapshot Full) effectuée avant de commencer.

## Contraintes:
- **Noeud à noeud :** Oui (mise à jour séquentielle, un membre à la fois).

## Portée:
Local (par nœud opérationnel)

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Perte de quorum | Si plus d'un nœud (sur 3) est hors ligne, le cluster s'arrête. | Attendre que le nœud précédent soit "Healthy" avant de passer au suivant. |
| Incompatibilité de version | Échec de communication entre membres. | Vérifier la matrice de compatibilité des versions etcd. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Transfert du leadership (si leader) | `etcdctl move-leader <TARGET_ID>` | Assure que le nœud en maintenance n'est pas le leader. |
| 2 | Arrêt du service local | `sudo systemctl stop etcd` | Isole le nœud pour la mise à jour. |
| 3 | Mise à jour | `sudo dnf update etcd` (ou remplacement manuel) | Applique les changements. |
| 4 | Redémarrage | `sudo systemctl start etcd` | Réintègre le nœud au cluster. |
| 5 | Vérification santé | `etcdctl endpoint health` | Confirme que le membre est à nouveau opérationnel. |
