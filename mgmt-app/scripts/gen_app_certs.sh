#!/bin/bash
set -euo pipefail

CERT_DIR="../certs_app"
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/server.crt" ]; then
  echo "Generating self-signed certs for Mgmt App..."
  openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" -days 365 -nodes -subj "/CN=mgmt-app"
fi