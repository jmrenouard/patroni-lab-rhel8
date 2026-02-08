# Makefile for Patroni RHEL 8 Cluster
# Orchestrates a 3-node Patroni/PostgreSQL/ETCD cluster using docker-compose.

IMAGE_NAME = patroni-rhel8
COMPOSE_FILE = docker-compose.yml

.PHONY: help build up down restart status logs clean ps

help:
	@echo "Patroni RHEL 8 Cluster - Management Commands:"
	@echo "  make build    - Build the Docker image"
	@echo "  make up       - Start the 3-node cluster"
	@echo "  make down     - Stop and remove the cluster"
	@echo "  make restart  - Restart the cluster"
	@echo "  make ps       - Show running containers"
	@echo "  make status   - Check Patroni cluster status (from node1)"
	@echo "  make etcd     - Check ETCD cluster health"
	@echo "  make logs     - Follow logs"
	@echo "  make clean    - Remove all assets"

gen-ssh:
	@echo "🔑 Génération des clés SSH pour le cluster..."
	mkdir -p ssh/
	rm -f ssh/id_rsa ssh/id_rsa.pub
	ssh-keygen -t rsa -b 4096 -f ssh/id_rsa -N "" -q

build: gen-ssh
	docker build -t $(IMAGE_NAME) .

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down -v

rebuild-all: down build up

ps:
	docker compose -f $(COMPOSE_FILE) ps

status:
	docker exec node1 patronictl -c /etc/patroni.yml list

etcd:
	docker exec etcd1 etcdctl --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379 --cacert=/certs/ca.crt endpoint health --cluster

test-etcd:
	./scripts/test_etcd.sh

test-patroni:
	./scripts/test_patroni.sh

test-haproxy:
	./scripts/test_haproxy.sh

verify: test-etcd test-patroni test-haproxy

install-tools:
	./scripts/install_local_tools.sh

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

clean: down
	docker rmi $(IMAGE_NAME) || true
	rm -rf ssh/ certs/ reports/ rpms_urls.txt wheels/

# Audit complet : Nettoyage, Build, Tests, Stress et Rapport
big-test:
	@chmod +x scripts/*.sh
	@./scripts/big_test.sh
