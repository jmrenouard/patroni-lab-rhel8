# Procédure : Gestion des Utilisateurs PgBouncer

L'ajout ou la modification d'utilisateurs dans PgBouncer nécessite la mise à jour du fichier `userlist.txt`.

## 📋 Structure du fichier `userlist.txt`

Le fichier contient les identifiants au format :
`"username" "password_hash"`

## ➕ Ajouter un utilisateur

### 1. Générer le hash du mot de passe
Il est recommandé d'utiliser MD5 (ou SCRAM-SHA-256 si configuré) :
```bash
echo -n "motdepasseusername" | md5sum | awk '{print "md5"$1}'
```

### 2. Modifier le fichier
Ajoutez la ligne au fichier `pgbouncer/userlist.txt` :
```bash
echo '"mon_user" "md5hash_genere"' >> pgbouncer/userlist.txt
```

### 3. Recharger PgBouncer
```bash
kill -HUP 1
```

## 🔐 Bonnes Pratiques

- **Isolation** : Ne partagez pas les mots de passe entre les utilisateurs applicatifs et administratifs.
- **TLS** : Assurez-vous que l'authentification se fait toujours via une connexion chiffrée.

---
[Retour à l'index des procédures](../README.md)
