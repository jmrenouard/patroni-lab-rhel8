# Manuel d'Utilisation - mgmt-app

Ce guide détaille les étapes d'utilisation de l'interface de gestion pour un administrateur de base de données.

## 1. Connexion

1. Accédez à l'URL : `https://localhost:8080` (Le port peut varier selon votre configuration `.env`).
2. Ignorez l'avertissement de certificat auto-signé (si en environnement de test).
3. Saisissez votre **Login** et **Mot de passe** définis dans votre configuration de sécurité.

## 2. Dashboard Cluster (Accueil)

Le dashboard affiche une vue d'ensemble du cluster :
- **Nodes Table** : Liste des nœuds avec leur rôle (Leader, Replica, Standby).
- **Health Charts** : Graphiques dynamiques des temps de réponse et de la charge.
- **Actions Rapides** : Boutons pour redémarrer un service ou forcer un check de santé.

## 3. Gestion Patroni

Dans l'onglet **Patroni**, vous pouvez :
- **Switchover** : Transférer proprement le rôle de Leader vers un autre nœud.
- **Maintenance** : Activer le mode `pause` sur un nœud pour effectuer des mises à jour système sans déclencher de failover.
- **Diagnostic** : Voir les détails de la configuration DCS stockée dans ETCD.

## 4. Exploration ETCD

L'onglet **ETCD** permet de naviguer dans l'arborescence des clés utilisées par Patroni :
- Consultation des verrous de leader.
- Vérification de la configuration partagée du cluster.
- État des membres du cluster de consensus.

## 5. Audit et Rapports

L'interface permet de consulter les résultats des tests automatisés :
- Visualisation des derniers rapports produits par `make big-test`.
- Historique des actions d'exploitation effectuées via l'interface.
- Accès direct aux logs filtrés des conteneurs.

---
[Retour à la racine](../README.md)
