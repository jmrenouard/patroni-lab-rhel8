# 📖 Procédures d'Administration

Ce répertoire contient l'ensemble des documentations sur les procédures d'administration du cluster.

## 🗂️ Liste des Procédures

### 🛠️ Administration etcd 3.6

| Catégorie | Procédure | Document |
| :--- | :--- | :--- |
| **Sauvegarde** | Snapshot Full (Online) | [etcd/backup_full.md](etcd/backup_full.md) |
| | Sauvegarde Incrémentale | [etcd/backup_incremental.md](etcd/backup_incremental.md) |
| **Restauration** | Restauration Full | [etcd/restore_full.md](etcd/restore_full.md) |
| | Restauration Incrémentale | [etcd/restore_incremental.md](etcd/restore_incremental.md) |
| **Maintenance** | Défragmentation | [etcd/maintenance_defrag.md](etcd/maintenance_defrag.md) |
| | Vérification de corruption | [etcd/maintenance_hash_check.md](etcd/maintenance_hash_check.md) |
| **Mises à jour** | Système / Binaires | [etcd/update_system.md](etcd/update_system.md) |
| **Membres** | Gestion du cluster (Swap/Remove) | [etcd/README.md](etcd/README.md) |
| **Diagnostic** | Santé & Leader | [etcd/diagnostic.md](etcd/diagnostic.md) |

### 🐘 Orchestration Patroni (PostgreSQL HA)

| Catégorie | Procédure | Document |
| :--- | :--- | :--- |
| **Diagnostic** | Santé du cluster & Rôles | [patroni/diagnostic.md](patroni/diagnostic.md) |
| **Topologie** | Bascule Manuelle (Switchover) | [patroni/switchover.md](patroni/switchover.md) |
| | Bascule Automatique (Failover) | [patroni/failover.md](patroni/failover.md) |
| **Maintenance** | Mode Maintenance (Pause) | [patroni/maintenance.md](patroni/maintenance.md) |
| | Récupération (Erreur Config) | [patroni/recovery_config_error.md](patroni/recovery_config_error.md) |
| **Mises à jour** | Système & Version Mineure | [patroni/minor_upgrade.md](patroni/minor_upgrade.md) |

### ⚖️ Équilibrage HAProxy

| Catégorie | Procédure | Document |
| :--- | :--- | :--- |
| **Exploitation** | Maintenance Manuelle | [haproxy/maintenance.md](haproxy/maintenance.md) |
| **Monitoring** | Diagnostic & Stats | [haproxy/diagnostic.md](haproxy/diagnostic.md) |

### 🌊 Pooling PgBouncer

| Catégorie | Procédure | Document |
| :--- | :--- | :--- |
| **Sécurité** | Rotation TLS | [pgbouncer/tls_rotation.md](pgbouncer/tls_rotation.md) |
| **Utilisateurs** | Gestion userlist.txt | [pgbouncer/user_management.md](pgbouncer/user_management.md) |
| **Gestion** | Diagnostic & Pools | [pgbouncer/diagnostic.md](pgbouncer/diagnostic.md) |

---

### 📜 Automatisation (Scripts)
Toutes ces procédures s'appuient sur les scripts situés dans le dossier `scripts/` :
- `scripts/procedures/` : Scripts spécifiques d'exploitation.
- `scripts/tests/` : Scripts de validation pour chaque couche.

---
[Retour à l'accueil](../../README.md)
