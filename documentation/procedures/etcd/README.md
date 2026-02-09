# 🛠️ Procédures d'Administration etcd

Ce répertoire contient les procédures détaillées pour l'administration et la maintenance du cluster etcd 3.6.

## 🗂️ Récapitulatif des Procédures

### 🛡️ Sauvegarde et Récupération
- **[Sauvegarde Complète (Online)](backup_full.md)** : Effectuer un snapshot complet du cluster sans interruption.
- **[Sauvegarde Incrémentale](backup_incremental.md)** : Sauvegarder les modifications depuis le dernier snapshot.
- **[Restauration Complète (DR)](restore_full.md)** : Procédure de Disaster Recovery pour restaurer un cluster à partir d'un snapshot.
- **[Restauration Incrémentale](restore_incremental.md)** : Rejouer les modifications incrémentales.

### 🔧 Maintenance et Santé
- **[Défragmentation & Compactage](maintenance_defrag.md)** : Optimiser l'espace disque et les performances.
- **[Vérification de Corruption](maintenance_hash_check.md)** : Contrôler l'intégrité des données via les hash de révision.
- **[Diagnostic de Santé](diagnostic.md)** : Vérifier l'état du cluster et identifier le leader.

### 👥 Gestion des Membres
- **[Retrait d'un Nœud](member_remove.md)** : Supprimer proprement un membre du cluster.
- **[Remplacement (Swap)](member_swap.md)** : Remplacer un nœud défaillant par un nouveau.
- **[Réinitialisation Nœud Zombie](member_reset_zombie.md)** : Gérer les nœuds qui ne parviennent pas à rejoindre le cluster.

### 🔐 Sécurité et Mises à jour
- **[Gestion RBAC](rbac_admin.md)** : Administrer les rôles et les permissions.
- **[Mise à jour Système](update_system.md)** : Procédure de mise à jour des binaires et de l'OS.

---
[Retour aux procédures](../README.md) | [Retour à l'accueil](../../../README.md)
