# Défragmentation et Compactage

## Objectifs:
Optimiser les performances et l'utilisation du stockage en libérant l'espace disque physique (défragmentation) et en supprimant l'historique des révisions obsolètes (compactage).

## Prérequis:
- **État du service :** Démarré (Online) ou Arrêté (Offline).
- **Sauvegardes avant l'opération :** Snapshot full obligatoire.
- **Enregistrer les informations critiques :** Taille actuelle de la DB, état du quorum.
- Quorum fonctionnel pour le compactage et la défragmentation en ligne.
- `etcdctl` et/ou `etcdutl` installés.

## Contraintes:
- **Noeud à noeud :** Oui (la défragmentation doit être lancée sur chaque endpoint individuellement).

## Portée:
Local (Défragmentation) / Global (Compactage)

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Blocage du nœud (Stop-the-world) | Le nœud ne répond plus aux requêtes pendant la défragmentation. | Procéder séquentiellement nœud après nœud en dehors des pics de charge. |
| Compactage trop agressif | Impossibilité de revenir à des versions très anciennes pour le troubleshooting. | Définir une politique de rétention claire. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Compactage (Online) | `etcdctl compact <revision_id>` | Supprime l'historique jusqu'à la révision spécifiée. |
| 2 | Défragmentation (Online) | `etcdctl defrag --endpoints=https://<IP>:2379` | Réorganise le stockage bbolt en ligne. |
| 3 | Défragmentation (Offline) | `etcdutl defrag --data-dir /var/lib/etcd` | À utiliser si le service est arrêté ou la base bloquée. |
