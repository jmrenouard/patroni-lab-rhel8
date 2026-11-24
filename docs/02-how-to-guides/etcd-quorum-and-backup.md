# Verify etcd Quorum and Run an Online Snapshot Backup

This procedure validates etcd 3-node quorum health and creates a verified snapshot backup file.

## Prerequisites

- The `etcd1`, `etcd2`, and `etcd3` containers run cleanly.
- The client certificates exist inside `/certs` in `etcd1`.
- The `.env` file defines `ETCD_ROOT_PASSWORD`.

## Procedure

1. Source `.env` so `ETCD_ROOT_PASSWORD` is available in your shell session.

```bash
set -a
source .env
set +a
```

2. Verify endpoint health across all three etcd members.

```bash
make etcd
```

3. List the cluster members and Raft leader status in table format.

```bash
docker exec etcd1 etcdctl \
  --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 \
  --cacert=/certs/ca.crt \
  --cert=/certs/etcd-client.crt \
  --key=/certs/etcd-client.key \
  --user="root:${ETCD_ROOT_PASSWORD}" \
  endpoint status --cluster -w table
```

4. Save a snapshot inside `etcd1` to `/etcd-data/etcd-backup.db`.

```bash
docker exec etcd1 etcdctl \
  --endpoints=https://etcd1:2379 \
  --cacert=/certs/ca.crt \
  --cert=/certs/etcd-client.crt \
  --key=/certs/etcd-client.key \
  --user="root:${ETCD_ROOT_PASSWORD}" \
  snapshot save /etcd-data/etcd-backup.db
```

NOTE: On a bare-metal host with `etcdctl` installed locally, you can run `./scripts/procedures/etcd/backup_full.sh`.

## Verification

1. Inspect the saved snapshot metadata to confirm non-zero revision and key count.

```bash
docker exec etcd1 etcdctl snapshot status /etcd-data/etcd-backup.db -w table
```

2. Run the automated etcd test suite.

```bash
make test-etcd
```

## Rollback

If an invalid snapshot file remains in `/etcd-data`, delete the temporary snapshot file:

```bash
docker exec etcd1 rm -f /etcd-data/etcd-backup.db
```

CAUTION: Do not run `etcdctl snapshot restore` on a live quorum unless all members are stopped.
