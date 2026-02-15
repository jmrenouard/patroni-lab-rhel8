# 🚀 Améliorations Futures du Lab Patroni RHEL 8

Ce document présente une feuille de route pour faire évoluer le lab d'un environnement de test vers une plateforme de référence "Production-Ready".

## 📊 Observabilité et Monitoring
- **Stack Prometheus/Grafana** : Déploiement automatique d'un exportateur PostgreSQL et d'un tableau de bord Grafana pré-configuré.
- **Centralisation des Logs** : Intégration d'une stack ELK ou Loki pour indexer les logs de Patroni, HAProxy et PostgreSQL.
- **Reporting de Santé** : Génération périodique de rapports PDF sur la stabilité du quorum et les temps de réponse SQL.

## 💾 Sauvegarde et Restauration
- **Intégration pgBackRest** : Mise en place de sauvegardes différentielles et incrémentales avec support du Point-In-Time Recovery (PITR).
- **Test de Restauration Automatisé** : Ajout d'une cible `make test-recovery` qui valide l'intégrité des backups.

## 🛡️ Sécurité Avancée
- **Rotation de Certificats** : Automatisation de la rotation des certificats mTLS sans interruption de service (HUP reload).
- **Audit de Conformité** : Script de scan pour vérifier que tous les endpoints respectent TLS 1.3 et rejettent les algorithmes de chiffrement obsolètes.
- **Gestion des Secrets** : Intégration optionnelle avec HashiCorp Vault pour ne plus stocker les mots de passe dans le `.env`.

## ⚙️ Automatisation et CI/CD
- **Pipeline GitHub Actions** : Validation automatique de chaque Pull Request par un test de déploiement Ansible complet sur des Runners Docker.
- **Infrastructure multi-nœuds réelle** : Support pour déployer le lab sur des instances AWS/GCP/Azure via Terraform.

## 🌩️ Multi-Datacenter
- **Replication Slots synchronisés** : Tester la capacité de Patroni à gérer des réplicas distants avec une latence réseau simulée.
- **Observateur (Witness) distant** : Configuration d'un nœud ETCD externe pour éviter le split-brain lors de partitions réseau.

---
> [!TIP]
> Priorité recommandée : 1. pgBackRest (Sauvegarde), 2. Prometheus (Monitoring), 3. Rotation TLS.
