# 🏗️ Architecture du Cluster

Ce document présente l'architecture globale du cluster PostgreSQL Haute Disponibilité et les flux de données entre ses composants.

## 🗺️ Vision Globale (8 Nœuds)

Le cluster est conçu pour la résilience avec une séparation stricte des rôles.

```mermaid
graph TD
    AppDirect(["Client : Accès Direct"]) --> LB["HAProxy"]
    AppPool(["Client : Accès Poolé"]) --> PGB["PgBouncer"]

    PGB -- "Port 5000 (RW)" --> LB
    PGB -- "Port 5001 (RO)" --> LB

    LB -- "Port 5432 (TCP)" --> Leader["Nœud Primaire"]
    LB -- "Port 5432 (TCP)" --> Replica["Nœud Réplica"]

    subgraph "Cluster Patroni"
        Leader
        Replica
        Node3["Nœud Standby"]
    end

    subgraph "Consensus et Découverte"
        ETCD[("Quorum etcd")]
    end

    Leader -. "Mise à jour du bail" .-> ETCD
    Replica -. "Surveillance du bail" .-> ETCD
    LB -. "Check API HTTPS (8008)" .-> Leader
    LB -. "Check API HTTPS (8008)" .-> Replica
```

## 🔄 Flux de Données

1. **Pooling de Connexions (PgBouncer)** :
   - L'application se connecte d'abord à **PgBouncer** (Port 6432).
   - PgBouncer gère le pool de sessions pour optimiser les ressources.
   - Il est configuré avec TLS côté client et côté serveur (`PGBOUNCER_CLIENT_SSLMODE` et `PGBOUNCER_SERVER_SSLMODE`).
   - Il redirige ensuite les requêtes vers HAProxy selon la base cible demandée (`postgres_rw` ou `postgres_ro`).

2. **Routage Intelligent (HAProxy)** :
   - HAProxy reçoit le trafic depuis PgBouncer ou en direct sur les ports **5000 (RW)** ou **5001 (RO)**.
   - **Check de Santé** : Il interroge en permanence l'API REST de Patroni (**Port 8008**) en HTTPS pour identifier dynamiquement le rôle de chaque nœud (`/primary` ou `/replica`).
   - **Relais TCP vers PostgreSQL** : Dans la configuration de laboratoire actuelle (`haproxy/haproxy.cfg`), HAProxy relaie le trafic TCP sur le port **5432** sans `send-proxy-v2` ; l'activation du protocole PROXY v2 nécessite une configuration explicite côté HAProxy et PostgreSQL.
   - **Terminaison SSL statistiques** : L'interface d'administration de HAProxy (port **7000**) sert le certificat `/certs/haproxy.pem`.

3. **Consensus (ETCD)** :
   - Patroni utilise ETCD pour stocker l'état du cluster et effectuer l'élection du Leader.
   - En cas de perte d'ETCD (perte du quorum), Patroni passe les bases PostgreSQL en lecture seule par sécurité.

## 📂 Organisation Multi-Datacenter

- **DC1 (Principal)** : `node1`, `node2`, `etcd1`, `etcd2`.
- **DC2 (Remote/Quorum)** : `node3`, `etcd3`, `haproxy`, `pgbouncer`.

---
[Retour à l'accueil (FR)](../README.fr.md) | [English Portal](../docs/index.md)
