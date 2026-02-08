# Restauration Incrémentale (Replay de log)

## Objectifs:
Réinjecter les modifications capturées via un flux incremental après une restauration complète du cluster.

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Snapshot full restauré avec succès.
- **Enregistrer les informations critiques :** Révision de fin du snapshot.
- Cluster etcd à nouveau fonctionnel (après une restauration Full).
- Fichier de log incremental généré par la procédure de sauvegarde.
- `etcdctl` configuré pour l'accès en écriture.

## Contraintes:
- **Noeud à noeud :** Non (les commandes sont injectées globalement via l'API).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Ordre des opérations | Risque d'incohérence si des clés interdépendantes sont rejouées dans le mauvais ordre. | Utiliser un script de parsing robuste qui respecte l'ordre chronologique du log. |
| Doublons/Conflits | Tentative d'écriture de données déjà présentes. | S'assurer que la révision de début correspond exactement à la fin du snapshot full. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Rejeu des données | `while read -r line; do # Parsing... etcdctl put "$key" "$value"; done < etcd_incremental.log` | Lit le log ligne par ligne et réapplique les opérations `PUT`. |
