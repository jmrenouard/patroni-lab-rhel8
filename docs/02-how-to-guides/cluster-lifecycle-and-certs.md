# Generate TLS Certificates and Start the Docker Lab

This procedure prepares SSH keys, generates TLS certificates in `certs_new/`, and starts the cluster containers.

## Prerequisites

- Docker Engine and Docker Compose are installed on the host.
- GNU Make, Bash, and OpenSSL are available on the host.
- The `.env` file exists at the repository root.

## Procedure

1. Verify that all mandatory variables exist in `.env`.

```bash
make check-env
```

2. Validate the syntax of the Compose manifest before you start the containers.

```bash
docker compose -f docker-compose.yml config -q
```

3. Generate the cluster SSH keys in `ssh/`.

```bash
make gen-ssh
```

4. Generate the CA and node certificates in `certs_new/`.

```bash
make gen-certs
```

5. Generate the `pgbouncer/userlist.txt` file from `.env`.

```bash
make setup-pgbouncer
```

6. Build the five RHEL 8 UBI container images.

```bash
make build
```

7. Start the eight containers in detached mode.

```bash
make up
```

8. Wait 30 seconds for etcd consensus and PostgreSQL bootstrap to finish.

```bash
sleep 30
```

## Verification

1. List the active containers to confirm that all eight services run.

```bash
make ps
```

2. Run the full status script and component checks.

```bash
make status
make verify
make test-pgbouncer
```

All component checks exit with code `0` when every service is healthy.

## Rollback

CAUTION: Run `make cleanup` only if you want to delete all generated images, certificates, and SSH keys.

To stop the containers and remove their Docker volumes without image removal, run `make down`:

```bash
make down
```
