# Perform a Planned Switchover and Recover from Failover

This procedure transfers leadership cleanly between healthy Patroni nodes and checks automatic failover recovery.

## Prerequisites

- All eight lab containers run (`make ps`).
- No active hardware fault blocks replication between `node1`, `node2`, and `node3`.

## Planned Switchover

1. Inspect the current cluster topology and replication lag on `node1`.

```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

2. Confirm that every replica shows a `streaming` state and low lag.

3. Start the interactive switchover script or execute `patronictl` directly.

```bash
./scripts/procedures/patroni/switchover.sh
```

4. When `patronictl` prompts for confirmation, enter the target candidate node and confirm the action.

NOTE: HAProxy detects the promoted node on HTTPS port `8008` and updates read-write routing automatically.

## Verification

1. Check the Patroni member table after the switchover completes.

```bash
docker exec node1 patronictl -c /etc/patroni.yml list
```

2. Inspect the timeline history to confirm a clean promotion record.

```bash
docker exec node1 patronictl -c /etc/patroni.yml history
```

3. Run the Patroni and HAProxy verification tests.

```bash
make test-patroni
make test-haproxy
```

## Emergency Failover Recovery

WARNING: Force a failover only when the primary node is unreachable, or you risk recent transaction loss.

1. Run the scripted failover check if a node container stopped unexpectedly.

```bash
./scripts/tests/test_failover.sh
```

2. If an old primary remains stopped, start its container so Patroni runs `pg_rewind`.

```bash
docker start node1
```

## Rollback

To restore the original primary node after maintenance, run a second planned switchover:

```bash
docker exec -it node1 patronictl -c /etc/patroni.yml switchover
```
