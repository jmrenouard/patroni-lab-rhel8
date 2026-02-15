# Solution Ansible pour Patroni Lab RHEL 8

Cette solution offre une alternative robuste et automatisée aux scripts Bash pour le déploiement et la gestion du cluster PostgreSQL/Patroni/ETCD.

## Structure du Projet Ansible
- `ansible.cfg` : Configuration globale.
- `inventories/` : Définition des hôtes (type conteneurs SSH).
- `roles/` :
    - `common` : Gestion TLS (Certificats) et dépendances.
    - `etcd` : Quorum et stockage distribué.
    - `patroni_pg` : PostgreSQL 17 et orchestration Patroni.
    - `haproxy` : Équilibrage de charge et routage intelligent.
    - `pgbouncer` : Pooling de connexions sécurisé.
- `site.yml` : Playbook de déploiement complet.
- `verify.yml` : Playbook de test et validation automatique.

## Pré-requis
- Ansible installé sur votre machine.
- Accès SSH configuré vers les cibles (conteneurs ou VM).
- Les variables d'environnement (ex: SSH_PORT_NODE1) doivent être définies si vous utilisez l'inventaire par défaut.

## Utilisation

### 1. Déploiement complet
```bash
cd ansible
ansible-playbook site.yml
```

### 2. Validation du cluster
Après l'installation, lancez le playbook de vérification pour confirmer que tous les services sont opérationnels et sécurisés :
```bash
ansible-playbook verify.yml
```

## Sécurité & TLS
- La CA et les certificats sont générés localement par le rôle `common` s'ils n'existent pas.
- Toutes les communications utilisent `hostssl` et l'authentification forte.
- Les commentaires dans les fichiers de configuration générés (`/etc/patroni.yml`, etc.) sont en **Français** pour faciliter l'exploitation.
