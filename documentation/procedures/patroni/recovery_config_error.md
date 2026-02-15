# Procédure de Récupération (Erreur de Configuration)

## Objectifs:
Récupérer un cluster Patroni/PostgreSQL qui ne démarre plus suite à une erreur de configuration (ex: mauvais paramétrage des tampons mémoire `shared_buffers`).

## Symptômes:
- Le service Patroni boucle ou échoue au démarrage.
- PostgreSQL refuse de démarrer avec des erreurs de type `could not create shared memory segment`.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/patroni/recovery_config_error.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/patroni/recovery_config_error.sh)

### 1. Arrêt de Patroni sur tous les nœuds
S'assurer que l'orchestrateur est arrêté pour éviter toute interférence.

**Local / SSH :**
```bash
systemctl stop patroni
```

### 2. Lancement manuel de PostgreSQL
Démarrer PostgreSQL en direct pour valider et consulter les erreurs.
```bash
# Se positionner sur le nœud et lancer postgres
/usr/pgsql-17/bin/postgres -D /datas/postgres
```

### 3. Consultation des logs
Si PostgreSQL échoue, les logs s'afficheront directement dans la console ou dans `/datas/postgres/log/`.
Identifier le paramètre fautif (ex: `shared_buffers` trop élevé pour la RAM disponible).

### 4. Correction de la configuration locale
Modifier le fichier `patroni.yml` sur les nœuds pour corriger la valeur erronée.
```bash
vi /etc/patroni.yml
```

### 5. Vérification de la configuration distribuée (DCS)
Patroni stocke sa configuration dans ETCD, qui prime sur le fichier local.
```bash
# Vérifier la configuration actuelle dans ETCD
docker exec etcd1 etcdctl --cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key \
  get /service/patroni-cluster/config
```

### 6. Correction de la configuration dans ETCD
Si la configuration dans DCS est erronée, il faut la corriger ou la supprimer pour que Patroni reprenne la configuration locale.

**Option A : Supprimer la configuration DCS (Recommandé pour repartir du local)**
```bash
docker exec etcd1 etcdctl --cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key \
  del /service/patroni-cluster/config
```

**Option B : Modifier manuellement via `patronictl` (si possible)**
```bash
# Si un nœud Patroni est démarrable
patronictl -c /etc/patroni.yml edit-config
```

### 7. Redémarrage du Cluster
Relancer Patroni sur les nœuds, en commençant par le nœud que vous souhaitez voir devenir leader.
```bash
systemctl start patroni
```

### 8. Vérification finale
```bash
patronictl -c /etc/patroni.yml list
```

> [!WARNING]
> La suppression de `/service/patroni-cluster/config` dans ETCD réinitialisera les paramètres dynamiques aux valeurs par défaut définies dans votre fichier `patroni.yml` lors du prochain démarrage.
