# Procédure : Maintenance HAProxy

Cette procédure explique comment isoler un backend ou un nœud pour maintenance sans perturber le cluster.

## 🛠️ Actions via l'Interface de Stats

HAProxy est configuré avec une interface d'administration sur le port **7000**.

### 1. Se connecter à l'interface
- URL : `https://haproxy:7000/`
- Login/Pass : Voir variables `ADMIN_HAPROXY_USER` / `ADMIN_HAPROXY_PASSWORD`.

### 2. Passer un nœud en maintenance
- Dans le tableau des backends (`pg_primary` ou `pg_replicas`), cochez la case du nœud concerné.
- Sélectionnez l'action **"Set state to MAINT"**.
- Le nœud ne recevra plus de nouvelles connexions SQL.

## 💻 Actions via la Ligne de Commande (Runtime API)

Si vous avez besoin d'automatiser la mise en maintenance :

### 1. Vérifier l'état actuel
```bash
echo "show stat" | socat stdio /tmp/haproxy.sock | cut -d ',' -f 1,2,18
```

### 2. Désactiver un serveur
```bash
echo "disable server pg_primary/node1" | socat stdio /tmp/haproxy.sock
```

### 3. Réactiver un serveur
```bash
echo "enable server pg_primary/node1" | socat stdio /tmp/haproxy.sock
```

## ⚠️ Précautions

- **Quorum** : Assurez-vous de ne pas désactiver trop de nœuds simultanément.
- **Vérification** : Toujours vérifier le routage via `scripts/tests/test_haproxy.sh` après une modification.

---
[Retour à l'index des procédures](../README.md)
