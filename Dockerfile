FROM registry.access.redhat.com/ubi8/ubi:latest

# Metadata
LABEL maintainer="Jean-Marie RENOUARD<jmrenouard@gmail.com"
LABEL description="Patroni RHEL 8 with PostgreSQL 17, Patroni 4.1.0, and ETCD 3.6.7"

# Environmental variables
ENV TERM=xterm \
    PSQL_VERSION=17 \
    PATH="/usr/pgsql-17/bin:$PATH" \
    PATRONI_ETCD3_INSECURE=true \
    PATRONI_ETCD3_PROTOCOL=https \
    PYTHONHTTPSVERIFY=0

# 🛠️ System Utilities, SSH, and dependencies for Supervisor
RUN dnf install -y \
    openssh-server \
    openssh-clients \
    openssl \
    rsync \
    vim-enhanced \
    hostname \
    iputils \
    net-tools \
    python3 \
    python3-pip \
    python3-setuptools \
    wget \
    curl \
    git \
    unzip \
    ca-certificates \
    procps-ng \
    langpacks-en && \
    dnf clean all

# 📦 Install Supervisor via pip (easier on UBI 8 than enabling EPEL)
RUN pip3 install --no-cache-dir supervisor

# 🔐 SSH Configuration
RUN mkdir -p /var/run/sshd /var/log/supervisor /datas && \
    ssh-keygen -A && \
    echo 'root:rootpass' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 🐘 PostgreSQL 17 Installation
RUN dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    dnf -y module disable postgresql || echo "PostgreSQL module not found, skipping disable" && \
    dnf install -y postgresql17-server postgresql17-contrib

# 🚀 Patroni & ETCD Installation
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --set-enabled pgdg17 pgdg-common pgdg-rhel8-extras

# Install Python 3.12 and build dependencies
RUN dnf install -y gcc python3.12 python3.12-devel python3.12-pip libffi-devel glibc-langpack-en && \
    dnf install -y patroni-4.1.0 patroni-etcd etcd pgbouncer

# Install ETCD v3 python client (force urllib3<2.0.0 for etcd3 compatibility)
RUN /usr/bin/python3.12 -m pip install --no-cache-dir "urllib3<2.0.0" "patroni[etcd3]"

RUN dnf clean all

# ⚙️ Configuration
# Creating necessary directories (Patroni will handle initdb via bootstrap)
RUN mkdir -p /var/run/postgresql /datas/postgres && \
    chown -R postgres:postgres /var/run/postgresql /datas && \
    chmod 775 /var/run/postgresql && \
    chmod 700 /datas /datas/postgres

# Copie de la configuration Patroni et Supervisor
COPY patroni/patroni.yml /etc/patroni.yml
COPY supervisord.conf /etc/supervisord.conf
RUN chown postgres:postgres /etc/patroni.yml


# SSH Keys - Using existing files in context
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY ssh/id_rsa.pub /root/.ssh/authorized_keys
COPY ssh/id_rsa.pub /root/.ssh/id_rsa.pub
COPY ssh/id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/authorized_keys /root/.ssh/id_rsa && \
    chown -R root:root /root/.ssh

# Exposed ports: SSH (22), PostgreSQL (5432), Patroni REST API (8008), ETCD (2379, 2380)
EXPOSE 22 5432 8008

# Volumes and Working Directory
VOLUME ["/datas"]
WORKDIR /datas

# Démarrage via Supervisor
CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

