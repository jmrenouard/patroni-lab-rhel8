# Documentation des Tests - Cluster Patroni HA

Cette documentation détaille l'ensemble des tests et outils de validation disponibles pour assurer le bon fonctionnement, la sécurité et la résilience du cluster Patroni sur RHEL 8.

## Sommaire
1. [Tests par Composants (Externes)](#1-tests-par-composants-externes)
2. [Validation Interne (Docker)](#2-validation-interne-docker)
3. [Tests de Charge (Stress Test)](#3-tests-de-charge-stress-test)
4. [Validation Globale et Failover](#4-validation-globale-et-failover)
5. [Audit Complet (Big Test)](#5-audit-complet-big-test)
6. [Utilisation via Makefile](#6-utilisation-via-makefile)

---

## 1. Tests par Composants (Externes)
Ces tests sont exécutés depuis l'hôte (ou le nœud de gestion) et vérifient l'accessibilité externe des services.

### ETCD (`test_etcd.sh`)
Vérifie la couche de découverte et de verrouillage :
- Accessibilité HTTPS de l'endpoint de santé.
- Validation du Quorum du cluster et de l'authentification `root`.
- Validation des permissions de l'utilisateur `patroni` (Lecture/Écriture).

### Patroni & PostgreSQL (`test_patroni.sh`)
Vérifie l'état de la base de données et de son orchestrateur :
- Accessibilité de l'API REST Patroni (avec authentification).
- Identification correcte du leader actuel du cluster.
- Test d'écriture SQL direct sur le nœud leader.

### HAProxy (`test_haproxy.sh`)
Vérifie la couche d'accès et d'équilibrage de charge :
- Accessibilité de l'API de statistiques (TLS + Auth).
- Routage SQL via le port Read-Write (RW).
- Routage SQL via le port Read-Only (RO).

---

## 2. Validation Interne (Docker)
Ces tests s'exécutent directement à l'intérieur des conteneurs pour vérifier l'état des processus et des configurations locales.

- **`test_dck_etcd.sh`** : Vérifie la santé interne, la synchronisation des membres et le quorum.
- **`test_dck_patroni.sh`** : Vérifie les processus Supervisord, l'écoute des ports (PG/Patroni) et analyse les erreurs dans les logs.
- **`test_dck_haproxy.sh`** : Vérifie le processus HAProxy et l'API de statistiques locale.
- **`test_dck_pgbouncer.sh`** : Vérifie le pool de connexions (RW/RO) via PgBouncer.

---

## 3. Tests de Charge (Stress Test)
Le script **`stress_test.py`** est un outil Python multi-threadé permettant de simuler une charge constante sur le cluster.

**Capacités :**
- Cibles supportées : `pg`, `etcd`, `haproxy`, `pgbouncer`.
- Paramètres : Nombre de threads, délai entre requêtes, nombre max de requêtes, durée totale.
- Résultats : Statistiques détaillées de succès et d'échec avec temps de réponse.

---

## 4. Validation Globale et Failover
Le script **`verify_cluster.sh`** est l'orchestrateur principal de santé.

Il enchaîne les étapes suivantes :
1. Vérification des prérequis environnementaux.
2. Exécution de tous les tests de composants (Externes).
3. Exécution de tous les tests internes (Docker).
4. Simulation d'un **Failover** :
   - Identification du leader.
   - Arrêt brutal du conteneur leader.
   - Vérification de l'élection d'un nouveau leader par Patroni/ETCD.
   - Redémarrage de l'ancien leader et vérification de sa réintégration.

---

## 5. Audit Complet (Big Test)
Le script **`big_test.sh`** exécute un cycle de vie complet pour audit.

1. **Clean** : Nettoyage complet des anciens actifs.
2. **Build** : Régénération des certificats et reconstruction des images Docker.
3. **Deploy** : Démarrage du cluster.
4. **Test** : Exécution de la validation globale (`verify_cluster.sh`).
5. **Stress** : Test de charge final sur HAProxy.
6. **Report** : Génération d'un rapport détaillé au format Markdown dans le dossier `reports/`.

---

## 6. Utilisation via Makefile
Pour simplifier l'exécution, des cibles Makefile sont disponibles :

| Commande | Description |
| :--- | :--- |
| `make test-etcd` | Teste la fonctionnalité ETCD |
| `make test-patroni` | Teste la logique Patroni/Failover |
| `make test-haproxy` | Teste le routage HAProxy |
| `make test-pgbouncer` | Teste le pooling PgBouncer |
| `make verify-cluster` | Lance la validation complète + Failover |
| `make stress-test` | Lance une simulation de charge |
| `make big-test` | Lance l'audit complet avec rapport |
