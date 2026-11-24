# Must-Have du Projet : Cluster PostgreSQL/Patroni/ETCD Ultra-Sécurisé

## 🔐 Sécurité & Authentification (Obligatoire)
- **Zéro Connexion en Clair** : Toutes les communications entre ETCD, Patroni, PostgreSQL et HAProxy **DOIVENT** utiliser TLS/SSL (HTTPS).
- **Authentification forte à chaque niveau** :
    - **ETCD** : Authentification activée avec un utilisateur `root` (superadmin) et un utilisateur `patroni` (dédié).
    - **Patroni REST API** : Authentification requise par identifiants (Basic Auth) et sécurisée via TLS.
    - **PostgreSQL** : Authentification par mot de passe obligatoire pour `superuser` et `replicator`. SSL forcé via `pg_hba.conf` (`hostssl`).
    - **Isolation Superuser** : L'utilisateur `POSTGRES_USER` est bridé à `127.0.0.1` (pas d'accès distant, même en SSL).
- **Gestion des Secrets** : Aucun mot de passe en dur. Tous les secrets sont injectés via le fichier `.env`.

## 🏗️ Architecture & Haute Disponibilité
- **Découplage Total** : Séparation des rôles (3 nœuds ETCD, 3 nœuds PostgreSQL/Patroni).
- **HAProxy Durci (Cible)** :
    - Équilibreur de charge avec certificats TLS propres.
    - Utilisation du **PROXY protocol** (cible à activer via `send-proxy-v2` dans `haproxy/haproxy.cfg`) pour préserver les IPs sources sans complexifier `pg_hba.conf`.
    - Deux ports TCP dédiés : 
        - **5000 (R/W)** : Pointe vers le Master (via check Patroni `/primary`).
        - **5001 (R/O)** : Pointe vers les Replicas (via check Patroni `/replica`).
    - Interface d'administration sécurisée sur le port **7000**.

## 🌍 Environnement & Portabilité
- **Air-Gap Ready** : Fourniture de scripts d'extraction :
    - Extraction des URLs RPM pour installation hors-ligne.
    - Création de paquets PIP Wheel pour Patroni.
- **Localisation** : Fichiers de configuration (`patroni.yml`, `etcd.yml`) intégralement documentés en **Français**.

## 🏢 Architecture & Topologie
- **Multi-Datacenter** : Support natif d'une topologie asymétrique (DC1 vs Remote) avec gestion des priorités de bascule.
- **PgBouncer** : Connection pooling obligatoire pour la montée en charge, configuré avec TLS.
- **Séparation des Secrets** : Interdiction de partager des identifiants (ex: HAProxy ne doit pas utiliser les creds Patroni).
- **Paramétrage Total** : Tous les ports TCP doivent être modifiables via le fichier `.env`.

## 🛠️ Maintenance & Tests
- **Tests de Charge (Stress)** : Capacité à lancer des requêtes cycliques (threads, pauses, durée max) pour valider la stabilité.
- **Tests Modulaires** : L'ensemble des tests **DOIT** être séparé par couche (ETCD, Patroni/PG, HAProxy) pour une analyse granulaire.
- **Vérification Intra-Conteneur** : Scripts `test_dck_xxx.sh` pour valider l'état interne si nécessaire.
- **Vérification Automatisée** : Un script global `verify_cluster.sh` orchestre l'ensemble pour garantir le "zéro régression".
- **Outillage Local** : Fourniture du script `scripts/install_local_tools.sh` pour permettre les diagnostics hors conteneur.

## 🔗 Flux Inter-Composants
- **TLS Obligatoire** : Aucun flux (ETCD <-> Patroni, Patroni <-> HAProxy, PostgreSQL <-> HAProxy, HAProxy <-> PgBouncer) ne doit circuler en clair.
- **Authentification Systématique** : Chaque point de contact doit exiger une authentification.
- **Proxy Protocol** : Utilisation pour transmettre l'IP source réelle.
