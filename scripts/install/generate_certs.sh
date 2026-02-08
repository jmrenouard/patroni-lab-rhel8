#!/bin/bash
# generate_certs.sh
# Génération de certificats TLS avec SAN (Subject Alternative Names) pour le cluster.

CERT_DIR="./certs"
mkdir -p $CERT_DIR

# Fichier de config OpenSSL temporaire pour les SAN
cat > $CERT_DIR/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
x509_extensions = v3_ca

[req_distinguished_name]
commonName = Common Name

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[v3_ca]
basicConstraints = CA:TRUE
keyUsage = cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer

[alt_names]
DNS.1 = localhost
DNS.2 = etcd1
DNS.3 = etcd2
DNS.4 = etcd3
DNS.5 = node1
DNS.6 = node2
DNS.7 = node3
DNS.8 = haproxy
DNS.9 = pgbouncer
IP.1 = 127.0.0.1
EOF

echo "🔐 Génération de l'autorité de certification (CA)..."
openssl genrsa -out $CERT_DIR/ca.key 2048
openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -subj "/CN=Patroni-Cluster-CA" -days 3650 -out $CERT_DIR/ca.crt -config $CERT_DIR/openssl.cnf -extensions v3_ca

generate_cert() {
    local name=$1
    echo "📜 Génération du certificat pour $name..."
    openssl genrsa -out $CERT_DIR/$name.key 2048
    openssl req -new -key $CERT_DIR/$name.key -subj "/CN=$name" -out $CERT_DIR/$name.csr -config $CERT_DIR/openssl.cnf
    openssl x509 -req -in $CERT_DIR/$name.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial -out $CERT_DIR/$name.crt -days 365 -sha256 -extfile $CERT_DIR/openssl.cnf -extensions v3_req
}

# Certificats pour ETCD (Unifié avec SANs pour tous les noeuds)
generate_cert "etcd-server"
generate_cert "etcd-client"

# Certificats pour Patroni API
generate_cert "patroni-api"

# Certificats pour PostgreSQL
generate_cert "postgresql-server"

# Certificats pour PgBouncer
generate_cert "pgbouncer"

# Fichier PEM combiné pour HAProxy (Certificat + Clé)
echo "📜 Génération du PEM combiné pour HAProxy..."
cat $CERT_DIR/postgresql-server.crt $CERT_DIR/postgresql-server.key > $CERT_DIR/haproxy.pem

echo "✅ Certificats générés avec SAN dans $CERT_DIR"

chmod 755 $CERT_DIR
chmod 644 $CERT_DIR/*.key
chmod 644 $CERT_DIR/*.crt
