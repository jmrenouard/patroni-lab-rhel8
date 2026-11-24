# Problèmes Potentiels (POTENTIAL_ISSUES)

Ce document recense les anomalies connues, points de vigilance et correctifs documentés pour le laboratoire Patroni RHEL 8.

## 🛠️ Anomalies connues et contournements

### 1. Erreur JavaScript dans l'application de gestion (`mgmt-app`)
- **Observation** : `ReferenceError: response is not defined` à `app.js:58`.
- **Impact** : Les indicateurs de santé du cluster restaient bloqués en mode « Chargement ».
- **Solution** : Ajout de l'appel `fetch('/api/status')` manquant dans la fonction `fetchStatus`.
- **Statut** : Correctif appliqué.

### 2. Écart entre `certs/` et `certs_new/` selon les scripts
- **Observation** : `docker-compose.yml` et `make gen-certs` montent `./certs_new:/certs:rw`, tandis que certains scripts (`scripts/manage/status.sh`, `scripts/tests/stress_test.py`) utilisent `./certs` par défaut.
- **Impact** : Échec de validation TLS côté hôte si `CERT_DIR` n'est pas aligné.
- **Solution** : Définir `CERT_DIR=certs_new` lors des appels hôtes ou synchroniser les certificats générés.

## 🔐 Sécurité et environnement

### 1. Échec de démarrage des conteneurs (etcd / HAProxy)
- **Observation** : Les conteneurs `etcd1` à `etcd3` ou `haproxy` passent en état `Exited (1)`.
- **Impact** : Indisponibilité du quorum ou du routage SQL pour les tests d'exploitation.
- **Cause probable** : Certificats absents dans `certs_new/` (`make gen-certs` non exécuté) ou droits d'accès incorrects sur les clés montées dans `/certs`.

### 2. Flags TLS assouplis par défaut en mode laboratoire
- **Observation** : `PYTHONHTTPSVERIFY=0` (`.env`, `Dockerfile.base`), `PATRONI_ETCD3_INSECURE=true` (`Dockerfile.postgresql`) et `check-ssl verify none` (`haproxy/haproxy.cfg`) sont présents pour le laboratoire local.
- **Impact** : Validation stricte des certificats et du protocole PROXY v2 non activée par défaut hors durcissement.
- **Solution** : Consulter la page d'explication [Consensus, Routing, and Security Posture](docs/04-explanation/ha-consensus-and-security-model.md) avant toute transposition en production.
