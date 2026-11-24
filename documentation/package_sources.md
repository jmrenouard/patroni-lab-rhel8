# Sources des Paquets pour l'Installation de Patroni

Ce document répertorie l'ensemble des sources pour les paquets RPM et PIP nécessaires à l'installation de Patroni et de ses composants associés dans l'environnement RHEL 8 (UBI).

## 📦 Paquets RPM

L'installation utilise trois sources principales de dépôts ainsi que des liens de téléchargement directs pour permettre un mode "hardened" ou restreint.

### 1. Dépôts Officiels
| Dépôt | URL de Configuration / RPM de Release | Description |
| :--- | :--- | :--- |
| **Red Hat UBI 8** | `registry.access.redhat.com/ubi8/ubi` | Base du système (BaseOS, AppStream). |
| **PostgreSQL (PGDG)** | `https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm` | Paquets PostgreSQL 17, Patroni (version RPM) et dépendances liées. |
| **EPEL 8** | `https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm` | Dépendances python additionnelles et utilitaires. |

### 2. Liste Finie des RPMs (Générée à la demande)
Le script `scripts/install/extract_rpms.sh` (`make extract-rpms`) génère le fichier `rpms_urls.txt` à la racine du projet avec les URLs de téléchargement direct extraites des dépôts actifs :
- **CDN Red Hat UBI** : `https://cdn-ubi.redhat.com/...`
- **PostgreSQL Yum Repo** : `https://download.postgresql.org/...`
- **Miroirs EPEL** : `http://mirror.in2p3.fr/...`

### 3. Paquets Système Clés (Installation `dnf`)
- **Utilitaires** : `procps-ng`, `iputils`, `net-tools`, `hostname`, `curl`, `wget`, `vim-enhanced`, `passwd`, `openssh-server`, `openssh-clients`, `openssl`, `rsync`, `git`, `unzip`, `ca-certificates`.
- **Python Runtime** : `python3.12`, `python3.12-pip`, `python3.12-devel`.
- **Base de Données** : `postgresql17-server`, `etcd`, `haproxy`, `pgbouncer`.

---

## 🐍 Paquets PIP (Python)

Les paquets Python sont installés via `pip install` depuis **PyPI (Python Package Index)**. Ils sont principalement gérés sous Python 3.12.

### 1. Dépendances Patroni & Cluster
| Paquet | Source | Description |
| :--- | :--- | :--- |
| `patroni` | PyPI | Cœur de Patroni. |
| `supervisor` | PyPI | Gestionnaire de processus pour les conteneurs. |

### 2. Remarque sur les versions
- Patroni est installé en version **4.1.0** via RPM dans certains Dockerfiles, mais complété par les drivers PIP pour l'interaction avec le DCS (Distributed Configuration Store).

---

## 🛠️ Extraction et Mise en Cache
Pour les environnements déconnectés, le script `extract_rpms.sh` (mentionné dans le cycle de refactorisation) permet de télécharger l'ensemble de ces paquets en local en s'appuyant sur les définitions des Dockerfiles.
