# Mgmt-App : Interface de Gestion du Cluster Patroni

La `mgmt-app` est une application web en Go conçue pour faciliter le monitoring et l'exploitation du cluster PostgreSQL/Patroni/ETCD.

## 🚀 Fonctionnalités Principales

- **Dashboard Temps Réel** : Visualisation de l'état de tous les nœuds du cluster.
- **Monitoring ETCD** : Exploration de la hiérarchie des clés et état du quorum.
- **Contrôle Patroni** : Déclenchement de switchovers et mise en maintenance.
- **Audit & Logs** : Consultation centralisée des logs et des rapports de tests.
- **Sécurité** : Authentification requise et communications intégrales en HTTPS.

## 🛠️ Installation et Exécution

L'application est intégrée au cycle de vie du projet via le `Makefile`.

### Lancement Local
```bash
make mgmt-run
```

### Build et Déploiement
L'application peut être buildée manuellement ou via Docker :
```bash
cd mgmt-app
go build -o mgmt-app main.go
./mgmt-app
```

## 🏗️ Architecture Technique

- **Backend** : Go (Golang) avec `net/http`.
- **Frontend** : HTML5/CSS3 (Vanilla) et JavaScript.
- **Base de Données** : SQLite (`mgmt.db`) pour le stockage des sessions et logs d'audit.
- **Communication** : API REST Patroni et API ETCD v3 via HTTPS.

## 🔐 Sécurité

L'application utilise des certificats TLS auto-générés pour le HTTPS. Les identifiants de connexion sont gérés via des variables d'environnement.

---
[Accéder au Manuel d'Utilisation](Manuel_Utilisation.md)
