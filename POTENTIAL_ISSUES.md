# Problèmes Potentiels (POTENTIAL_ISSUES)

Ce fichier recense les anomalies, points de vigilance et solutions identifiés lors des audits ou de l'exécution en boucle (Ralph Loop).

## 🛠️ Anomalies de Logique

### 1. Performance Schema Désactivé
- **Observation** : `✘ Performance_schema should be activated.` lors de l'audit.
- **Impact** : Réduction de la profondeur de diagnostic pour les métriques de performance.
- **Solution (Comment corriger)** :
    - **MySQL/MariaDB** : Ajouter `performance_schema=ON` sous la section `[mysqld]` dans votre `my.cnf` ou `server.cnf` et redémarrer le service.
    - **Cloud/Managed** : Activer via la console de votre fournisseur cloud (ex: AWS Parameter Group, GCP Flags).
    - **Vérification** : Exécuter `SHOW VARIABLES LIKE 'performance_schema';` (doit être `ON`).

### 2. Erreur Javascript dans l'Application de Gestion (mgnt-app)
- **Observation** : `ReferenceError: response is not defined` à `app.js:58`.
- **Impact** : Les indicateurs de santé du cluster restaient bloqués en mode "Chargement".
- **Solution** : Ajout de l'appel `fetch('/api/status')` manquant dans la fonction `fetchStatus`.
- **Status** : Fix appliqué par Ralph Loop.

## 🔐 Sécurité & Environnement

### 1. Échec de démarrage des containers (ETCD/HAProxy)
- **Observation** : Les containers `etcd1-3` et `haproxy` sont en état `Exited (1)`.
- **Impact** : Indisponibilité totale du cluster pour les tests d'exploitation.
- **Cause probable** : Problème de chargement des certificats TLS (mouvements de fichiers ou permissions).

---
*Dernière mise à jour par Ralph Loop le 2026-02-12*
