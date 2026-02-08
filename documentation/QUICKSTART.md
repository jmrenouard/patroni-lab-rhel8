# 🚀 Guide de Démarrage Rapide (Quick Start)

Ce guide vous permet de déployer et de tester rapidement le cluster PostgreSQL Haute Disponibilité sécurisé sur RHEL 8.

## 📋 Prérequis

Avant de commencer, assurez-vous de disposer des éléments suivants :
- **Docker** et **Docker Compose** installés et fonctionnels.
- **GNU Make** pour utiliser l'automatisation via le `Makefile`.
- Accès au registre Red Hat (UBI 8) ou images déjà présentes.

## 🛠️ Installation en 3 étapes

Copiez le fichier d'exemple et confivgurez vos variables (mot de passe, ports, etc.) :
```bash
cp .env.example .env
```

### 2. Installation des outils locaux
Installez les outils nécessaires (psql, etcdctl, openssl) pour interagir avec le cluster depuis votre machine :
```bash
make install-tools
```

### 3. Déploiement complet
Lancez l'automatisation qui gère la génération des certificats SSL/TLS, les clés SSH, le build des images et le démarrage des conteneurs :
```bash
make rebuild-all
```

## 🔍 Vérification du Cluster

Une fois le déploiement terminé, vérifiez la santé des composants :

- **État de Patroni** (Leader/Replicas) :
  ```bash
  make status
  ```

- **Santé de ETCD** :
  ```bash
  make etcd
  ```

- **Logs en temps réel** :
  ```bash
  make logs
  ```

## 🧪 Tests et Audit

Pour valider le bon fonctionnement et la sécurité :

- **Tests de base** (ETCD, Patroni, HAProxy) :
  ```bash
  make verify
  ```

- **Audit complet (Big Test)** :
  Lance un cycle complet de reconstruction, tests de charge (stress-test) et génère un rapport de synthèse :
  ```bash
  make big-test
  ```
  *Le rapport sera disponible dans le répertoire `./reports/`.*

## 🧹 Nettoyage

Pour arrêter le cluster et nettoyer les ressources :

- **Arrêt simple** : `make down`
- **Nettoyage profond** (suppression des certs, clés et images) : `make clean`
- **Nettoyage total des scripts** : `make cleanup`

---
> [!TIP]
> Pour plus de détails sur les procédures d'administration, consultez le [Manuel etcd](procedures/etcd_admin.md).
