# 📜 Documentation des Scripts d'Automatisation

Ce répertoire documente l'ensemble des scripts situés dans le dossier `scripts/` du projet. Pour une vue d'ensemble détaillée des tests, reportez-vous à la [Documentation des Tests](../tests.md).

## 🚀 Orchestration et Validation Globale

### [big_test.sh](../../scripts/manage/big_test.sh)
Orchestrateur principal pour un test de bout en bout du cluster.
- **Actions :** Nettoyage, génération de certificats, build Docker, configuration de l'auth ETCD, et tests de validation.
- **Rapports :** Génère un fichier Markdown dans `./reports/`.

### [verify_cluster.sh](../../scripts/tests/verify_cluster.sh)
Script de vérification globale de la santé et de la résilience (HA).
- **Actions :** Exécute tous les tests unitaires (externes et internes) et simule un **failover** en arrêtant le leader actuel.

### [stress_test.py](../../scripts/tests/stress_test.py)
Outil de test de charge écrit en Python.
- **Usage :** `python3 stress_test.py --type [pg|etcd|haproxy|pgbouncer] --port [port] ...`
- **Fonctionnalité :** Multi-threading, mesure de latence, et statistiques de succès/échec.

---

## ⚙️ Configuration et Initialisation

### [check_env.sh](../../scripts/manage/check_env.sh)
Valide que toutes les variables obligatoires sont définies dans le fichier `.env`.

### [setup_configs.sh](../../scripts/install/setup_configs.sh)
Utilise `envsubst` pour injecter les variables d'environnement dans les fichiers `.rendered` (HAProxy, PgBouncer, Patroni).

### [setup_etcd_auth.sh](../../scripts/install/setup_etcd_auth.sh)
Initialise le RBAC d'ETCD. Crée l'utilisateur `root` et l'utilisateur `patroni` avec les permissions appropriées.

### [setup_pgbouncer.sh](../../scripts/install/setup_pgbouncer.sh)
Génère le fichier `pgbouncer/userlist.txt` à partir des credentials définis dans le `.env`.

### [generate_certs.sh](../../scripts/install/generate_certs.sh)
Génère manuellement l'autorité de certification (CA) et les certificats TLS pour tous les composants avec les SAN (Subject Alternative Names) appropriés.

### [install_local_tools.sh](../../scripts/install/install_local_tools.sh)
Installe les utilitaires clients nécessaires (`psql`, `etcdctl`) sur la machine hôte pour permettre les tests hors conteneur.

---

## 🐳 Gestion des Conteneurs et Build

### [entrypoint_etcd.sh](../../scripts/manage/entrypoint_etcd.sh)
Entrypoint utilisé par les conteneurs ETCD. Il gère la détection automatique entre un nouveau cluster (`new`) et un redémarrage de nœud (`existing`).

### [extract_rpms.sh](../../scripts/install/extract_rpms.sh)
Analyse les dépendances et extrait les URLs des RPMs nécessaires pour le build hors-ligne, en utilisant `repoquery` dans un conteneur UBI.

### [create_wheels.sh](../../scripts/install/create_wheels.sh)
Télécharge les paquets Python (Whl) indispensables (ex: `etcd3`) pour l'installation de Patroni en mode offline.

### [cleanup_simple.sh](../../scripts/manage/cleanup_simple.sh)
Arrête tous les conteneurs et supprime les volumes ainsi que les réseaux.

### [cleanup_deep.sh](../../scripts/manage/cleanup_deep.sh)
Nettoyage profond : suppression des conteneurs, volumes, réseaux, images du projet et assets générés (certs, ssh, etc.).

---

## 🧪 Tests de Composants (Externes)
*Ces scripts testent l'accès au cluster depuis l'extérieur (via les ports exposés).*

| Script | Cible | Vérifications |
| :--- | :--- | :--- |
| [test_etcd.sh](../../scripts/tests/test_etcd.sh) | ETCD | HTTPS, Quorum, Auth Root/Patroni |
| [test_haproxy.sh](../../scripts/tests/test_haproxy.sh) | HAProxy | API Stats, Routage SQL Read/Write et Read-Only |
| [test_patroni.sh](../../scripts/tests/test_patroni.sh) | Patroni | API REST TLS, Identification du Leader, Écriture SQL |

---

---
## 🛠️ Scripts de Procédures Administratives (etcd)
*Ces scripts permettent d'exécuter localement les procédures documentées dans `documentation/procedures/etcd/`.*

| Script | Procédure Documentée | Description |
| :--- | :--- | :--- |
| [backup_full.sh](../../scripts/procedures/etcd/backup_full.sh) | [Snapshot Full](../procedures/etcd/backup_full.md) | Sauvegarde complète de la base etcd. |
| [backup_incremental.sh](../../scripts/procedures/etcd/backup_incremental.sh) | [Sauvegarde Incr.](../procedures/etcd/backup_incremental.md) | Capture du flux de mutations via `watch`. |
| [diagnostic.sh](../../scripts/procedures/etcd/diagnostic.sh) | [Diagnostic](../procedures/etcd/diagnostic.md) | Santé du cluster, Leader et endpoint status. |
| [maintenance_defrag.sh](../../scripts/procedures/etcd/maintenance_defrag.sh) | [Défragmentation](../procedures/etcd/maintenance_defrag.md) | Optimisation de l'espace disque. |
| [maintenance_hash_check.sh](../../scripts/procedures/etcd/maintenance_hash_check.sh) | [Hash Check](../procedures/etcd/maintenance_hash_check.md) | Vérification de corruption des données. |
| [member_remove.sh](../../scripts/procedures/etcd/member_remove.sh) | [Retrait Nœud](../procedures/etcd/member_remove.md) | Suppression propre d'un membre. |
| [member_reset_zombie.sh](../../scripts/procedures/etcd/member_reset_zombie.sh) | [Reset Zombie](../procedures/etcd/member_reset_zombie.md) | Réinitialisation d'un nœud corrompu. |
| [member_swap.sh](../../scripts/procedures/etcd/member_swap.sh) | [Swap Nœud](../procedures/etcd/member_swap.md) | Remplacement d'un membre (ex: changement IP). |
| [rbac_admin.sh](../../scripts/procedures/etcd/rbac_admin.sh) | [Gestion RBAC](../procedures/etcd/rbac_admin.md) | Configuration utilisateurs, rôles et activation auth. |
| [restore_full.sh](../../scripts/procedures/etcd/restore_full.sh) | [Restauration Full](../procedures/etcd/restore_full.md) | Disaster recovery à partir d'un snapshot. |
| [restore_incremental.sh](../../scripts/procedures/etcd/restore_incremental.sh) | [Restauration Incr.](../procedures/etcd/restore_incremental.md) | Rejeu des logs de mutations. |
| [update_system.sh](../../scripts/procedures/etcd/update_system.sh) | [Mise à jour](../procedures/etcd/update_system.md) | Mise à jour séquentielle avec transfert de leader. |

> [!NOTE]
> Tous ces scripts partagent une configuration commune via [common.sh](../../scripts/procedures/common.sh) (chargement du `.env` et configuration TLS).

---

## 🧪 Tests de Composants (Internes/Docker)

---
[Retour à l'accueil](../../README.md)
