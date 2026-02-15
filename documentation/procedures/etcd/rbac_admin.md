# Gestion des Accès (RBAC)

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/etcd/rbac_admin.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/etcd/rbac_admin.sh)

## Objectifs:
Mettre en place une politique de sécurité granulaire en gérant les utilisateurs, les rôles et en activant l'authentification sur le cluster.

## Prérequis:
- **État du service :** Démarré (Online).
- **Sauvegardes avant l'opération :** Snapshot full vivement conseillé.
- **Enregistrer les informations critiques :** Liste des utilisateurs et rôles actuels.
- Accès admin au cluster.
- `etcdctl` configuré.
- **Attention :** Une fois l'authentification activée, toutes les commandes devront inclure `--user root:password`.

## Contraintes:
- **Noeud à noeud :** Non (les changements RBAC sont répliqués sur tout le cluster).

## Portée:
Global

## Risques:
| Risque | Impact | Mitigation |
| :--- | :--- | :--- |
| Perte des identifiants root | Accès administratif impossible au cluster. | Stocker les mots de passe dans un coffre-fort numérique sécurisé. |
| Erreur de syntaxe dans les permissions | Blocage des applications légitimes. | Tester les permissions sur des préfixes de test avant la production. |

## Description technique:
| Étape | Action | Commande | Description |
| :--- | :--- | :--- | :--- |
| 1 | Création de l'admin root | `etcdctl user add root:MyStrongPassword` | Crée le super-utilisateur nécessaire à l'authentification. |
| 2 | Création d'un rôle | `etcdctl role add app-manager` | Définit un groupe de permissions. |
| 3 | Attribution de permissions | `etcdctl role grant-permission app-manager readwrite --prefix /app/data/` | Autorise l'accès complet sur un préfixe spécifique. |
| 4 | Liaison utilisateur/rôle | `etcdctl user grant-role myuser app-manager` | Associe un utilisateur à ses droits. |
| 5 | Activation globale | `etcdctl auth enable` | Active le contrôle d'accès sur tout le cluster. |
