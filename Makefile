# Makefile for Patroni RHEL 8 Cluster
# Orchestrates a 3-node Patroni/PostgreSQL/ETCD cluster using docker-compose.

IMAGE_BASE = patroni-rhel8-base
IMAGE_ETCD = patroni-rhel8-etcd
IMAGE_POSTGRES = patroni-rhel8-postgresql
IMAGE_HAPROXY = patroni-rhel8-haproxy
IMAGE_PGBOUNCER = patroni-rhel8-pgbouncer
COMPOSE_FILE = docker-compose.yml

.PHONY: help build up down restart status logs clean ps gen-ssh \
	gen-certs extract-rpms check-env setup-pgbouncer verify-cluster \
	stress-test cleanup test-pgbouncer test-etcd test-patroni \
	test-haproxy verify big-test install-tools rebuild-all \
	up-etcd down-etcd etcd build-base build-etcd build-postgres \
	build-haproxy build-pgbouncer

help:
	@echo "=========================================================="
	@echo "Patroni RHEL 8 Cluster - Management Console"
	@echo "=========================================================="
	@echo ""
	@echo "🚀 Cluster Management:"
	@echo "  make build         - Build all specialized images"
	@echo "  make build-base    - Build only the base image"
	@echo "  make up            - Start the 3-node cluster"
	@echo "  make down          - Stop and remove the cluster"
	@echo "  make restart       - Restart the cluster"
	@echo "  make rebuild-all   - Full rebuild (down -> build -> up)"
	@echo "  make ps            - Show running containers"
	@echo "  make logs          - Follow logs"
	@echo "  make clean         - Remove core assets (ssh, certs, images)"
	@echo "  make cleanup       - Deep cleanup of all script-generated assets"
	@echo ""
	@echo "🔧 Independent Component Management:"
	@echo "  make up-etcd       - Start only the ETCD cluster"
	@echo "  make down-etcd     - Stop and remove only the ETCD cluster"
	@echo ""
	@echo "📊 Status & Health:"
	@echo "  make status        - Check Patroni cluster status (from node1)"
	@echo "  make etcd          - Check ETCD cluster health"
	@echo "  make verify-cluster - Run comprehensive cluster verification"
	@echo ""
	@echo "🧪 Testing & Audit:"
	@echo "  make verify        - Run basic component tests (ETCD, Patroni, HAProxy)"
	@echo "  make test-etcd     - Test ETCD functionality"
	@echo "  make test-patroni  - Test Patroni failover/logic"
	@echo "  make test-haproxy  - Test HAProxy routing"
	@echo "  make test-pgbouncer - Test PgBouncer connection pooling"
	@echo "  make stress-test   - Run load simulation on the cluster"
	@echo "  make big-test      - Audit complet: Clean, Build, Tests, Stress & Report"
	@echo ""
	@echo "🛠️  Setup & Utilities:"
	@echo "  make gen-ssh       - Generate SSH keys for the cluster"
	@echo "  make gen-certs     - Generate SSL/TLS certificates"
	@echo "  make extract-rpms  - Extract RPMs from UBI images"
	@echo "  make install-tools - Install local management tools"
	@echo "  make check-env     - Verify local environment prerequisites"
	@echo "  make setup-pgbouncer - Configure PgBouncer instances"
	@echo "=========================================================="

gen-ssh:
	@echo "🔑 Génération des clés SSH pour le cluster..."
	@mkdir -p ssh/
	@rm -f ssh/id_rsa ssh/id_rsa.pub
	@ssh-keygen -t rsa -b 4096 -f ssh/id_rsa -N "" -q

gen-certs:
	@echo "🔐 Génération des certificats SSL/TLS..."
	@./scripts/install/generate_certs.sh

extract-rpms:
	@echo "📦 Extraction des RPMs..."
	@./scripts/install/extract_rpms.sh

check-env:
	@./scripts/manage/check_env.sh

setup-pgbouncer:
	@./scripts/install/setup_pgbouncer.sh

build-base: gen-ssh
	@echo "🏗️ Building base image..."
	docker build -t $(IMAGE_BASE):latest -f Dockerfile.base .

build-etcd: build-base
	@echo "🏗️ Building ETCD image..."
	docker build -t $(IMAGE_ETCD):latest -f Dockerfile.etcd .

build-postgres: build-base
	@echo "🏗️ Building PostgreSQL/Patroni image..."
	docker build -t $(IMAGE_POSTGRES):latest -f Dockerfile.postgresql .

build-haproxy: build-base
	@echo "🏗️ Building HAProxy image..."
	docker build -t $(IMAGE_HAPROXY):latest -f Dockerfile.haproxy .

build-pgbouncer: build-base
	@echo "🏗️ Building PgBouncer image..."
	docker build -t $(IMAGE_PGBOUNCER):latest -f Dockerfile.pgbouncer .

build: build-base build-etcd build-postgres build-haproxy build-pgbouncer

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down -v

rebuild-all: down build up

up-etcd:
	docker compose -f $(COMPOSE_FILE) up -d etcd1 etcd2 etcd3

down-etcd:
	docker compose -f $(COMPOSE_FILE) stop etcd1 etcd2 etcd3
	docker compose -f $(COMPOSE_FILE) rm -f -v etcd1 etcd2 etcd3

ps:
	docker compose -f $(COMPOSE_FILE) ps

status:
	@docker exec node1 patronictl -c /etc/patroni.yml list

etcd:
	@docker exec etcd1 etcdctl --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 --cacert=/certs/ca.crt --cert=/certs/etcd-client.crt --key=/certs/etcd-client.key --user root:${ETCD_ROOT_PASSWORD} endpoint health --cluster

test-etcd:
	@./scripts/tests/test_etcd.sh

test-patroni:
	@./scripts/tests/test_patroni.sh

test-haproxy:
	@chmod +x scripts/tests/test_haproxy.sh
	./scripts/tests/test_haproxy.sh

test-pgbouncer:
	@chmod +x scripts/tests/test_dck_pgbouncer.sh
	./scripts/tests/test_dck_pgbouncer.sh

verify-cluster:
	@chmod +x scripts/tests/verify_cluster.sh
	./scripts/tests/verify_cluster.sh

stress-test:
	@python3 scripts/tests/stress_test.py

verify: test-etcd test-patroni test-haproxy

install-tools:
	@chmod +x scripts/install/install_local_tools.sh
	./scripts/install/install_local_tools.sh

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

clean: down
	docker rmi $(IMAGE_NAME) || true
	rm -rf ssh/ certs/ reports/ rpms_urls.txt wheels/

cleanup:
	@chmod +x scripts/manage/cleanup_all.sh
	./scripts/manage/cleanup_all.sh

# Audit complet : Nettoyage, Build, Tests, Stress et Rapport
big-test:
	@chmod +x scripts/manage/*.sh
	@chmod +x scripts/install/*.sh
	@chmod +x scripts/tests/*.sh
	@./scripts/manage/big_test.sh
