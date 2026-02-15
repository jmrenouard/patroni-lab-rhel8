# Diagnostic de Santé HAProxy

## Objectifs:
Vérifier que HAProxy est en mesure de router le trafic vers le Leader PostgreSQL (RW) et les réplicas (RO).

## Prérequis:
- Service HAProxy démarré.
- Accès au réseau du cluster.

## Description technique:

> [!NOTE]
> **Automatisation :** Une version scriptée de cette procédure est disponible : 
> [scripts/procedures/haproxy/diagnostic.sh](file:///home/jmren/GIT_REPOS/patroni-lab-rhel8/scripts/procedures/haproxy/diagnostic.sh)

### 1. Vérification des ports d'écoute
Vérifier que les ports RW, RO et Stats sont ouverts.

**Local / Docker :**
```bash
# RW: 5432, RO: 5433, Stats: 8404 (selon configuration)
netstat -tpln | grep haproxy
```

**SSH (Alternative) :**
```bash
ssh ${HAPROXY_NODE} "netstat -tpln | grep haproxy"
```

### 2. Test de connexion SQL via HAProxy
Vérifier l'accès au Primaire.
```bash
psql "host=localhost port=5432 user=postgres sslmode=require" -c "SELECT pg_is_in_recovery();"
```
*Le résultat doit être `f` (false) pour le port RW.*

### 3. Vérification des logs
Surveiller les changements d'état des serveurs backend.
```bash
journalctl -u haproxy -f
```

### 4. Statut via la Socket Admin
Interroger HAProxy en ligne de commande.

**Local / Docker (via socat) :**
```bash
echo "show stat" | socat stdio /tmp/haproxy.sock | cut -d, -f1,2,18,19 | column -s, -t
```

**SSH (Alternative) :**
```bash
ssh ${HAPROXY_NODE} "echo \"show stat\" | socat stdio /tmp/haproxy.sock | cut -d, -f1,2,18,19 | column -s, -t"
```
