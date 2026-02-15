# PRD: Test et Documentation de l'Application de Gestion (mgmt-app)

## Overview
L'objectif est de valider toutes les fonctionnalités de l'application de gestion Patroni via un navigateur web et de produire une documentation complète (README et Manuel d'utilisation).

## Task 1: Validation de la Connexion et de la Page d'Accueil
- Lancer l'application via `make mgmt-run`.
- Accéder à `https://localhost:8080`.
- Tester l'authentification (Login/Logout).
- Vérifier le rendu de la page d'accueil (Tableau de bord).

## Task 2: Test du Monitoring et de l'État du Cluster
- Parcourir la page d'état du cluster.
- Vérifier que les nœuds (Patroni, ETCD, HAProxy) sont correctement affichés.
- Vérifier la mise à jour dynamique des métriques.

## Task 3: Test des Actions d'Exploitation (Switchover/Maintenance)
- Tester le déclenchement d'un switchover via l'interface.
- Activer/Désactiver le mode maintenance sur un nœud.
- Vérifier l'impact sur le cluster (via les logs ou l'état affiché).

## Task 4: Test des Outils de Diagnostic et Logs
- Consulter les logs des conteneurs via l'interface.
- Tester l'explorateur ETCD.
- Vérifier le rendu des rapports d'audit.

## Task 5: Génération de la Documentation
- Créer un fichier `mgmt-app/README.md` listant toutes les fonctionnalités validées.
- Créer un fichier `mgmt-app/Manuel_Utilisation.md` avec des captures d'écran ou descriptions des parcours utilisateurs.
