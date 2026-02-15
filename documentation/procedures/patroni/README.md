# 🛠️ Procédures d'Administration Patroni

Ce répertoire contient les procédures détaillées pour l'administration et la maintenance du cluster PostgreSQL haute disponibilité orchestré par Patroni.

## 🗂️ Récapitulatif des Procédures

### 🔍 Diagnostic et Surveillance
- **[Diagnostic de Santé](diagnostic.md)** : Vérifier l'état du cluster, les rôles (Leader/Replica) et la réplication.

### 🔄 Gestion de la Topologie
- **[Bascule Manuelle (Switchover)](switchover.md)** : Changer de leader de manière contrôlée (ex: pour maintenance).
- **[Bascule Automatique (Failover)](failover.md)** : Comprendre et gérer les bascules automatiques en cas de panne.

### 🔧 Maintenance et Configuration
- **[Maintenance du Cluster](maintenance.md)** : Mettre le cluster en mode maintenance (pause) pour des interventions lourdes.
- **[Récupération (Erreur Config)](recovery_config_error.md)** : Procédure de secours en cas de mauvais paramétrage empêchant le démarrage.

---
[Retour aux procédures](../README.md) | [Retour à l'accueil](../../../README.md)
