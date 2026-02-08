# Diagnostic et Identification Leader

## Objectifs:
Évaluer instantanément la santé du cluster, vérifier que le quorum est respecté et identifier quel nœud assure le rôle de Leader.

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Non requis (Lecture seule).
- **Enregistrer les informations critiques :** Liste des endpoints cibles.
- `etcdctl` configuré avec les endpoints et certificats.

## Contraintes:
- **Noeud à noeud :** Non.

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Endpoints injoignables | Le diagnostic peut être incomplet si certains nœuds sont isolés par le firewall. | Vérifier la connectivité réseau (ping/telnet) en cas d'erreur `context deadline exceeded`. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Santé globale | `etcdctl endpoint health --cluster -w table` | Vérifie si les membres répondent. |
| 2 | Statut détaillé | `etcdctl endpoint status --cluster -w table` | Affiche la version, la taille de la DB et le leader. |
| 3 | Identification Leader | `etcdctl endpoint status --cluster -w table \| grep "true"` | Filtre rapide pour trouver l'ID du leader. |
| 4 | Analyse des logs | `journalctl -u etcd.service -f` | Permet de voir les erreurs de consensus en temps réel (Local). |
