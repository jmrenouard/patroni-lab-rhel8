#!/usr/bin/env python3
# stress_test.py
# Client de test de charge cyclique pour ETCD, PostgreSQL, HAProxy et PgBouncer.
# Inclut des statistiques de réussite/échec.

import os
import time
import threading
import argparse
import subprocess
import signal
from datetime import datetime

# Couleurs pour le terminal
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[0;33m'
NC = '\033[0m'

# Compteurs globaux
stats = {
    "total": 0,
    "ok": 0,
    "fail": 0
}
stats_lock = threading.Lock()
stop_event = threading.Event()

def run_stress_client(target_cmd, thread_id, delay, max_req):
    requests_done = 0
    while not stop_event.is_set():
        if max_req > 0 and requests_done >= max_req:
            break
        
        try:
            # Exécution de la commande
            start_time = time.time()
            result = subprocess.run(target_cmd, shell=True, capture_output=True, text=True, timeout=5)
            duration = time.time() - start_time
            
            with stats_lock:
                stats["total"] += 1
                if result.returncode == 0:
                    stats["ok"] += 1
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] [Thread {thread_id}] {GREEN}SUCCESS{NC} ({duration:.3f}s)")
                else:
                    stats["fail"] += 1
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] [Thread {thread_id}] {RED}ERROR{NC}: {result.stderr.strip()[:50]}")
        except subprocess.TimeoutExpired:
            with stats_lock:
                stats["total"] += 1
                stats["fail"] += 1
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [Thread {thread_id}] {RED}TIMEOUT{NC}")
        except Exception as e:
            with stats_lock:
                stats["total"] += 1
                stats["fail"] += 1
                print(f"[{datetime.now().strftime('%H:%M:%S')}] [Thread {thread_id}] {RED}EXCEPTION{NC}: {str(e)}")

        requests_done += 1
        if delay > 0:
            time.sleep(delay)

def main():
    parser = argparse.ArgumentParser(description="Stress Test Client pour Cluster Patroni/ETCD")
    parser.add_argument("--type", choices=["pg", "etcd", "haproxy", "pgbouncer"], required=True, help="Type de cible")
    parser.add_argument("--host", default="localhost", help="Hôte cible")
    parser.add_argument("--port", type=int, required=True, help="Port cible")
    parser.add_argument("--user", default="postgres", help="Utilisateur")
    parser.add_argument("--threads", type=int, default=1, help="Nombre de threads (parallélisme)")
    parser.add_argument("--delay", type=float, default=1.0, help="Temps de pause entre requêtes (sec)")
    parser.add_argument("--max-req", type=int, default=0, help="Nombre max de requêtes par thread (0 = illimité)")
    parser.add_argument("--duration", type=int, default=0, help="Durée maximale du test en secondes (0 = illimité)")
    
    args = parser.parse_args()

    # Définition de la commande de test selon le type
    if args.type == "pg" or args.type == "haproxy" or args.type == "pgbouncer":
        cmd = f"psql -h {args.host} -p {args.port} -U {args.user} -d postgres -c 'SELECT 1;' > /dev/null 2>&1"
    elif args.type == "etcd":
        cmd = f"etcdctl --endpoints=https://{args.host}:{args.port} --cacert=certs/ca.crt --cert=certs/etcd-client.crt --key=certs/etcd-client.key endpoint health > /dev/null 2>&1"

    print(f"🚀 Démarrage du stress test sur {YELLOW}{args.type}{NC} ({args.host}:{args.port})")
    print(f"🧵 Threads: {args.threads} | Pause: {args.delay}s | Durée: {args.duration if args.duration > 0 else '∞'}s")

    threads = []
    for i in range(args.threads):
        t = threading.Thread(target=run_stress_client, args=(cmd, i, args.delay, args.max_req))
        t.start()
        threads.append(t)

    try:
        if args.duration > 0:
            time.sleep(args.duration)
            stop_event.set()
        else:
            while any(t.is_alive() for t in threads):
                time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Arrêt manuel demandé...")
        stop_event.set()

    for t in threads:
        t.join()

    # Résumé Final
    print(f"\n{YELLOW}--- RÉSUMÉ DU STRESS TEST ---{NC}")
    total = stats["total"]
    ok = stats["ok"]
    fail = stats["fail"]
    
    if total > 0:
        percent_ok = (ok / total) * 100
        percent_fail = (fail / total) * 100
    else:
        percent_ok = 0
        percent_fail = 0

    print(f"📊 Requêtes Totales : {total}")
    print(f"✅ Succès          : {GREEN}{ok}{NC} ({percent_ok:.2f}%)")
    print(f"❌ Échecs          : {RED}{fail}{NC} ({percent_fail:.2f}%)")
    print(f"{YELLOW}-----------------------------{NC}")

if __name__ == "__main__":
    main()
