document.addEventListener('DOMContentLoaded', () => {
    const healthGrid = document.getElementById('health-grid');
    const containerList = document.getElementById('container-list');
    const lastUpdate = document.getElementById('last-update');

    // Détection de la page actuelle (contexte)
    const rawPath = window.location.pathname.replace('/', '');
    const currentPath = rawPath === '' ? 'index' : rawPath;

    async function fetchStatus() {
        // Feedbak visuel de chargement sur les cartes
        document.querySelectorAll('.health-card').forEach(card => card.classList.add('loading'));

        try {
            const response = await fetch(`/api/status?page=${currentPath}`);
            const data = await response.json();
            updateUI(data);
            if (lastUpdate) lastUpdate.textContent = `Dernière mise à jour: ${new Date().toLocaleTimeString()}`;

            // Mise à jour des diagnostics détaillés (Diagnostic Avancé)
            const diagnosticOutput = document.getElementById('diag-output');
            if (diagnosticOutput && data.details) {
                diagnosticOutput.textContent = data.details;
            }
        } catch (error) {
            console.error('Erreur lors de la récupération du statut:', error);
            const connStatus = document.getElementById('connection-status');
            if (connStatus) {
                connStatus.textContent = 'Erreur de connexion';
                connStatus.className = 'offline';
            }
        } finally {
            document.querySelectorAll('.health-card').forEach(card => card.classList.remove('loading'));
        }
    }

    async function updateContainerMetrics(name, containerId) {
        const metricsEl = document.getElementById(`metrics-${containerId}`);
        if (!metricsEl) return;

        try {
            const response = await fetch(`/api/stats?name=${name}`);
            if (!response.ok) return;
            const stats = await response.json();

            // CPU
            let cpu = 0;
            if (stats.cpu_stats && stats.precpu_stats) {
                const cpuDelta = stats.cpu_stats.cpu_usage.total_usage - stats.precpu_stats.cpu_usage.total_usage;
                const sysDelta = stats.cpu_stats.system_cpu_usage - stats.precpu_stats.system_cpu_usage;
                if (sysDelta > 0 && cpuDelta > 0) {
                    cpu = (cpuDelta / sysDelta) * stats.cpu_stats.online_cpus * 100.0;
                }
            }

            // RAM
            const mem = (stats.memory_stats.usage || 0) / (1024 * 1024);

            metricsEl.innerHTML = `
                <span>CPU: <span class="metrics-val">${cpu.toFixed(1)}%</span></span>
                <span>RAM: <span class="metrics-val">${mem.toFixed(1)}MB</span></span>
            `;
        } catch (e) {
            console.error("Stats Error:", e);
        }
    }

    function updateUI(data) {
        // Update Health Grid (seulement si présent sur la page)
        if (healthGrid) {
            healthGrid.innerHTML = '';
            for (const [name, info] of Object.entries(data.cluster)) {
                // Sur les sous-pages, on ne montre que le composant concerné
                if (currentPath !== 'index' && name !== currentPath) continue;

                const card = document.createElement('div');
                card.className = 'health-card';
                card.innerHTML = `
                    <h3>${name}</h3>
                    <div class="status">
                        <span class="dot ${info.alive ? 'online' : 'offline'}"></span>
                        ${info.alive ? 'En ligne' : 'Inaccessible'}
                    </div>
                    <p style="font-size: 0.75rem; color: var(--text-dim); margin-top: 10px;">${info.message || ''}</p>
                `;
                healthGrid.appendChild(card);
            }
        }

        // Update Container List
        if (containerList) {
            containerList.innerHTML = '';
            const sortedContainers = (data.containers || []).sort((a, b) => {
                const nameA = a.Names && a.Names.length > 0 ? a.Names[0] : "";
                const nameB = b.Names && b.Names.length > 0 ? b.Names[0] : "";
                return nameA.localeCompare(nameB);
            });

            sortedContainers.forEach(c => {
                if (!c.Names || c.Names.length === 0) return;
                const name = c.Names[0].replace('/', '');

                // Filtrage Intelligent par page
                let match = false;
                if (currentPath === 'index') {
                    match = ['node', 'etcd', 'haproxy', 'pgbouncer'].some(k => name.includes(k));
                } else if (currentPath === 'patroni') {
                    match = name.includes('node');
                } else {
                    match = name.includes(currentPath);
                }

                if (!match) return;

                const item = document.createElement('div');
                item.className = 'container-item';

                const isRunning = c.State === 'running';

                item.innerHTML = `
                    <div class="container-info">
                        <div class="container-name">${name}</div>
                        <div class="container-status">${c.Status}</div>
                        ${isRunning ? `<div id="metrics-${c.Id}" class="container-metrics">Chargement stats...</div>` : ''}
                    </div>
                    <div class="container-actions">
                        ${isRunning ? `<button onclick="viewLogs('${name}')">📋 Logs</button>` : ''}
                        <button class="${isRunning ? 'stop' : 'start'}" onclick="controlContainer('${c.Id}', '${isRunning ? 'stop' : 'start'}')">
                            ${isRunning ? 'Arrêter' : 'Démarrer'}
                        </button>
                        <button onclick="controlContainer('${c.Id}', 'restart')">Redémarrer</button>
                    </div>
                `;
                containerList.appendChild(item);

                // Déclenchement de la mise à jour des stats si running
                if (isRunning) {
                    updateContainerMetrics(name, c.Id);
                }
            });
        }

        // --- GOUVERNANCE : CERTIFICATS ---
        if (data.certs && data.certs.length > 0 && currentPath === 'index') {
            const certList = document.getElementById('cert-list');
            if (certList) {
                certList.innerHTML = '';
                data.certs.forEach(c => {
                    const item = document.createElement('div');
                    item.style.display = 'flex';
                    item.style.justifyContent = 'space-between';
                    item.style.padding = '8px';
                    item.style.background = c.critical ? 'rgba(239, 68, 68, 0.1)' : 'rgba(255,255,255,0.03)';
                    item.style.borderRadius = '6px';
                    item.style.fontSize = '0.8rem';
                    item.style.border = c.critical ? '1px solid var(--error)' : '1px solid var(--glass-border)';

                    item.innerHTML = `
                        <span>${c.critical ? '⚠️' : '📜'} ${c.name}</span>
                        <span style="color: ${c.critical ? 'var(--error)' : 'var(--text-dim)'};">Exp: ${c.expiry} (${c.days_left}j)</span>
                    `;
                    certList.appendChild(item);
                });
            }
        }
    }

    window.controlContainer = async (id, command) => {
        try {
            const response = await fetch('/api/control', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id, command })
            });
            if (response.ok) {
                fetchStatus();
            } else {
                alert('Erreur lors de l\'exécution de la commande');
            }
        } catch (error) {
            console.error('Erreur action container:', error);
        }
    };

    window.batchControl = async (theme, command) => {
        const btn = event?.target;
        if (btn) btn.classList.add('loading');

        try {
            const response = await fetch('/api/batch-control', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ theme, command })
            });
            if (response.ok) {
                // On laisse un petit délai pour que Docker prenne en compte l'état
                setTimeout(fetchStatus, 1000);
            } else {
                alert('Erreur lors de l\'exécution du batch');
            }
        } catch (error) {
            console.error('Erreur action batch:', error);
        } finally {
            if (btn) btn.classList.remove('loading');
        }
    };

    window.viewLogs = async (name) => {
        const modal = document.getElementById('log-modal');
        const viewer = document.getElementById('log-viewer');
        const title = document.getElementById('log-title');

        if (!modal || !viewer) return;

        title.textContent = `Logs de ${name}`;
        viewer.textContent = "Récupération des logs...";
        modal.style.display = 'flex';

        try {
            const response = await fetch(`/api/logs?name=${name}&tail=200`);
            const logs = await response.text();
            viewer.textContent = logs;
            viewer.scrollTop = viewer.scrollHeight;
        } catch (e) {
            viewer.textContent = "Erreur lors du chargement des logs.";
        }
    };

    // Poll every 5 seconds
    setInterval(fetchStatus, 5000);
    fetchStatus();

    window.switchoverCluster = async () => {
        const leader = prompt("Nom du leader actuel (ex: node1):");
        const candidate = prompt("Nom du candidat (ex: node2):");
        if (!leader || !candidate) return;

        if (!confirm(`⚠️ Êtes-vous sûr de vouloir basculer le trafic de ${leader} vers ${candidate} ?`)) return;

        try {
            const response = await fetch('/api/cluster/switchover', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ leader, candidate })
            });
            const data = await response.json();
            alert(data.result === 'success' ? 'Switchover réussi' : `Erreur: ${data.output}`);
            fetchStatus();
        } catch (error) {
            console.error('Switchover Error:', error);
        }
    };

    window.toggleMaintenance = async (mode) => {
        const actionText = mode === 'on' ? 'ACTIVER' : 'DÉSACTIVER';
        if (!confirm(`⚠️ Voulez-vous ${actionText} le mode maintenance (pause) du cluster ?`)) return;

        try {
            const response = await fetch('/api/cluster/maintenance', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ mode })
            });
            const data = await response.json();
            alert(data.result === 'success' ? `Mode maintenance ${mode === 'on' ? 'activé' : 'désactivé'}` : `Erreur: ${data.output}`);
            fetchStatus();
        } catch (error) {
            console.error('Maintenance Error:', error);
        }
    };

    window.controlHaproxy = async () => {
        const backend = prompt("Nom du backend (ex: nodes):", "nodes");
        const server = prompt("Nom du serveur (ex: node1):");
        const command = prompt("Commande (disable, enable, drain, ready):");
        if (!backend || !server || !command) return;

        try {
            const response = await fetch('/api/haproxy/control', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ backend, server, command })
            });
            const data = await response.json();
            alert(data.result === 'success' ? 'Commande HAProxy envoyée' : `Erreur: ${data.output}`);
            fetchStatus();
        } catch (error) {
            console.error('HAProxy Error:', error);
        }
    };
});
