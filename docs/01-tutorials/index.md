# Tutorials

Learning-oriented hands-on exercises for deploying and testing the Patroni, etcd, HAProxy, and PgBouncer Docker lab.

1. [Deploy and Verify the Patroni RHEL 8 Cluster](01-deploy-and-verify-cluster.md) — validate environment variables, generate lab certificates and SSH keys, build the UBI 8 images, and verify all 8 containers.
2. [Observe Patroni Failover and Primary Reintegration](02-failover-and-recovery-lab.md) — generate client queries with `stress_test.py`, simulate a primary node failure, inspect replica promotion, and watch `pg_rewind` rejoin the recovered node.

[Back to Documentation Portal](../index.md)
