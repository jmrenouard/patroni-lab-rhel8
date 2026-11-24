# Architecture Ports, Environment, and Script Inventory

## Docker Compose Services (`docker-compose.yml`)

| Service | Image | Role / Component | Internal Ports | Host Ports (`.env` Defaults) | Volumes / Key Mounts |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `etcd1` | `patroni-rhel8-etcd:latest` | etcd 3.6 node 1 | `2379`, `2380`, `22` | `2379`, SSH `22203` | `./certs_new:/certs:rw`, `./scripts:/scripts:ro`, `etcd1_data:/etcd-data` |
| `etcd2` | `patroni-rhel8-etcd:latest` | etcd 3.6 node 2 | `2379`, `2380`, `22` | `2381`, SSH `22204` | `./certs_new:/certs:rw`, `./scripts:/scripts:ro`, `etcd2_data:/etcd-data` |
| `etcd3` | `patroni-rhel8-etcd:latest` | etcd 3.6 node 3 | `2379`, `2380`, `22` | `2382`, SSH `22205` | `./certs_new:/certs:rw`, `./scripts:/scripts:ro`, `etcd3_data:/etcd-data` |
| `node1` | `patroni-rhel8-postgresql:latest` | Patroni 4.1.0 + PG 17 (`dc1`, priority `100`) | `5432`, `8008`, `22` | PG `5432`, API `8008`, SSH `22200` | `node1_data:/datas`, `./certs_new:/certs:rw`, `./scripts:/scripts:ro` |
| `node2` | `patroni-rhel8-postgresql:latest` | Patroni 4.1.0 + PG 17 (`dc1`, priority `50`) | `5432`, `8008`, `22` | PG `5433`, API `8009`, SSH `22201` | `node2_data:/datas`, `./certs_new:/certs:rw`, `./scripts:/scripts:ro` |
| `node3` | `patroni-rhel8-postgresql:latest` | Patroni 4.1.0 + PG 17 (`remote`, priority `1`) | `5432`, `8008`, `22` | PG `5434`, API `8010`, SSH `22202` | `node3_data:/datas`, `./certs_new:/certs:rw`, `./scripts:/scripts:ro` |
| `haproxy` | `patroni-rhel8-haproxy:latest` | TCP RW/RO router & HTTPS stats UI | `5000`, `5001`, `7000`, `22` | `5000`, `5001`, `7000`, SSH `${SSH_PORT_HAPROXY}` | `./certs_new:/certs:rw` |
| `pgbouncer` | `patroni-rhel8-pgbouncer:latest` | Connection pooler (`postgres_rw`, `postgres_ro`) | `6432`, `22` | `6432`, SSH `${SSH_PORT_PGBOUNCER}` | `./certs_new:/certs:rw`, `./scripts:/scripts:ro`, `./pgbouncer/userlist.txt` |

- Compose network name: `patroni-rhel8_default`.
- Node supervisor process manager: `/usr/local/bin/supervisord -c /etc/supervisord.conf` (manages `sshd` and `patroni`).

## `Makefile` Targets

| Category | Targets |
| :--- | :--- |
| **Setup & Assets** | `check-env`, `gen-ssh`, `gen-certs`, `setup-pgbouncer`, `extract-rpms`, `install-tools` |
| **Container Build** | `build-base`, `build-etcd`, `build-postgres`, `build-haproxy`, `build-pgbouncer`, `build` |
| **Lifecycle** | `up`, `down`, `restart`, `rebuild-all`, `up-etcd`, `down-etcd`, `ps`, `logs`, `clean`, `cleanup` |
| **Diagnostics & Tests** | `status`, `status-etcd`, `status-patroni`, `status-haproxy`, `status-pgbouncer`, `etcd`, `test-etcd`, `test-patroni`, `test-haproxy`, `test-pgbouncer`, `verify`, `verify-cluster`, `stress-test`, `big-test` |
| **Ansible & Go App** | `ansible-deploy`, `ansible-verify`, `ansible-all`, `mgmt-build`, `mgmt-run`, `mgmt-clean` |

## Key Environment Variables (`.env` / `".env example"`)

| Variable | Default in `.env` | Effect / Usage |
| :--- | :--- | :--- |
| `SCOPE`, `NAMESPACE` | `patroni-cluster`, `/service/` | Patroni DCS cluster key namespace in etcd |
| `ETCD_HOSTS` | `etcd1:2379,etcd2:2379,etcd3:2379` | Comma-separated etcd endpoints passed to Patroni |
| `PATRONI_ETCD3_PROTOCOL` | `https` | Scheme used by Patroni `etcd3` client in runtime environment |
| `PATRONI_ETCD3_INSECURE` | `false` | `.env` sets `false`; `Dockerfile` and `Dockerfile.postgresql` set `true` as image build default |
| `PYTHONHTTPSVERIFY` | `0` | Disables Python TLS verification in `.env`, `Dockerfile`, and `Dockerfile.base` |
| `VERIFY_CLIENT_CERT` | `true` | Enables `--peer-client-cert-auth` in `scripts/manage/entrypoint_etcd.sh` |
| `HAPROXY_WEIGHT_NODE1..3` | `100`, `50`, `1` | Backend weights configured in `haproxy/haproxy.cfg` |
| `MGMT_APP_PORT` | `8080` (default in `mgmt-app/main.go`) | HTTPS listen port for the Go management server |

## Repository Script Inventory

- **Install (`scripts/install/`):** `create_wheels.sh`, `extract_rpms.sh`, `generate_certs.sh`, `install_local_tools.sh`, `setup_configs.sh`, `setup_etcd_auth.sh`, `setup_pgbouncer.sh`.
- **Management (`scripts/manage/`):** `big_test.sh`, `check_env.sh`, `cleanup_deep.sh`, `cleanup_simple.sh`, `entrypoint_etcd.sh`, `entrypoint_node.sh`, `generate_html_report.py`, `status.sh`.
- **Verification & Stress (`scripts/tests/`):** `stress_test.py`, `test_dck_etcd.sh`, `test_dck_haproxy.sh`, `test_dck_patroni.sh`, `test_dck_pgbouncer.sh`, `test_etcd.sh`, `test_failover.sh`, `test_haproxy.sh`, `test_patroni.sh`, `test_replication_scenario.sh`, `test_utils.sh`, `verify_cluster.sh`.
- **Procedures (`scripts/procedures/`):** `common.sh`, `etcd/*.sh` (12 scripts), `haproxy/{diagnostic,stats}.sh`, `patroni/{diagnostic,failover,maintenance,recovery_config_error,switchover}.sh`, `pgbouncer/{diagnostic,pools}.sh`.
- **Management App (`mgmt-app/`):** `mgmt-app/main.go`, `mgmt-app/handlers/*.go`, `mgmt-app/services/*.go`, `mgmt-app/scripts/gen_app_certs.sh`.

## `stress_test.py` CLI Options

| Flag | Values / Default | Description |
| :--- | :--- | :--- |
| `--type` | `pg`, `etcd`, `haproxy`, `pgbouncer` | Target protocol driver (`required`) |
| `--host` | `localhost` | Target hostname or container alias |
| `--port` | Integer | Target TCP port (`required`) |
| `--user` | `postgres` | Database or auth username |
| `--threads` | `1` | Concurrent worker thread count |
| `--delay` | `1.0` | Pause between requests in seconds |
| `--max-req` | `0` (`0` = unlimited) | Maximum requests per worker thread |
| `--duration` | `0` (`0` = unlimited) | Maximum test runtime in seconds |
