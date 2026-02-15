# Procédure : Rotation des Certificats TLS PgBouncer

Cette procédure décrit comment renouveler les certificats TLS de PgBouncer sans interrompre durablement le service.

## 📋 Prérequis

- Accès root sur le serveur de gestion.
- Accès au répertoire des certificats (`/certs` ou variable `CACERT_PATH`).
- Script `scripts/gen_certs.sh` disponible.

## 🔄 Étapes de Rotation

### 1. Génération des nouveaux certificats
Utilisez le script de génération pour créer de nouveaux actifs :
```bash
# Générer uniquement pour pgbouncer si supporté, sinon tout régénérer
./scripts/gen_certs.sh
```

### 2. Déploiement des fichiers
Copiez les nouveaux fichiers dans le répertoire monté par les conteneurs PgBouncer :
```bash
cp certs_new/pgbouncer.crt certs/pgbouncer.crt
cp certs_new/pgbouncer.key certs/pgbouncer.key
```

### 3. Rechargement de PgBouncer
PgBouncer peut recharger sa configuration (et ses certificats) sans couper les connexions existantes via un `RELOAD`.

#### Rechargement :
```bash
pgbouncer -R -u pgbouncer /etc/pgbouncer/pgbouncer.ini
```

### 4. Vérification
Vérifiez que le certificat a bien été mis à jour :
```bash
openssl s_client -connect localhost:6432 -starttls postgres | openssl x509 -noout -dates
```

---
[Retour à l'index des procédures](../README.md)
