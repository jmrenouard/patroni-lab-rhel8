# Cluster PostgreSQL Haute Disponibilité (HA) Hardened - RHEL 8

Ce projet implémente un cluster PostgreSQL 17 hautement sécurisé et résilient, orchestré par **Patroni** et **ETCD**, avec une topologie **Multi-Datacenter** et un pooling de connexions via **PgBouncer**.

## 🏗️ Architecture et Composants

Le cluster est composé de 8 conteneurs basés sur RHEL 8 (UBI) :
- **3 Nœuds ETCD** (etcd1, etcd2, etcd3) : Assurent le consensus et la découverte de services via HTTPS/mTLS.
- **3 Nœuds Patroni/PostgreSQL** (node1, node2, node3) :
    - `node1` & `node2` : Datacenter Principal (DC1).
    - `node3` : Datacenter Remote (Backup).
- **1 Nœud HAProxy** : Point d'entrée unique pour le routage R/W (Port 5000) et R/O (Port 5001).
- **1 Nœud PgBouncer** : Pooler de connexions (Port 6432) avec routage via HAProxy.

## 🔐 Sécurité & Hardening
- **End-to-End TLS** : Toutes les communications (ETCD, Patroni API, PostgreSQL) sont chiffrées.
- **mTLS Flexible** : Option `VERIFY_CLIENT_CERT` pour activer/désactiver l'exigence des certs clients.
- **Isolation des Crédentials** : Identifiants distincts pour chaque composant (.env).
- **Accès Superuser** : Accès au compte `postgres` restreint à `127.0.0.1`.
- **Rotation SSH** : Clés RSA régénérées à chaque build.

## 🚀 Étapes de Construction

1. **Préparation de l'environnement** :
   ```bash
   cp .env.example .env  # Configurer vos variables
   make install-tools    # Installer psql, etcdctl, openssl localement
   ```

2. **Reconstruction Complète** :
   ```bash
   make rebuild-all      # Clean, Génération Certs, Build, Up
   ```

3. **Audit de Sécurité et Performance** :
   ```bash
   make big-test         # Lance le build, tous les tests et génère un rapport
   ```

## 📋 Variables d'Environnement (.env)

| Variable | Description | Valeur par défaut |
| :--- | :--- | :--- |
| `SCOPE` | Nom du cluster Patroni | `patroni-cluster` |
| `VERIFY_CLIENT_CERT` | Activer mTLS strict | `true` |
| `EXT_PG_PORT_NODE1` | Port externe PostgreSQL | `5432` |
| `EXT_HAPROXY_RW_PORT`| Port HAProxy Read/Write | `5000` |
| `ADMIN_HAPROXY_USER` | Admin HAProxy Stats | `ha_admin` |

## 🧪 Matrice des Tests Automatisés

| Script | Composant | Description du Test | Résultat Attendu |
| :--- | :--- | :--- | :--- |
| `test_etcd.sh` | ETCD | Quorum, HTTPS, Auth Root/Patroni | Quorum OK, Accès Root OK |
| `test_patroni.sh` | Patroni | API REST TLS, Identification Leader | API accessible, Leader unique |
| `test_haproxy.sh` | HAProxy | Routage SQL RW/RO, Stats API | SELECT 1 via 5000/5001 OK |
| `test_dck_xxx.sh` | Interne | Vérification des process et logs containers | Process running, 0 Critical logs |
| `stress_test.py` | Résilience | Injection cyclique de requêtes (threads/durée) | % Succès > 99% sous charge |
| `verify_cluster.sh` | Global | Orchestration de tous les tests + Failover | Bascule du Leader réussie |

## 📊 Rapports
Chaque exécution de `make big-test` génère un rapport markdown détaillé dans le répertoire `./reports/`.
EOF
