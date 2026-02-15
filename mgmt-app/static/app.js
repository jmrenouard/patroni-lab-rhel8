document.addEventListener('DOMContentLoaded', () => {
    const healthGrid = document.getElementById('health-grid');
    const containerList = document.getElementById('container-list');
    const lastUpdate = document.getElementById('last-update');

    // --- ÉTAT GLOBAL & HISTORIQUE ---
    const metricsHistory = {}; // Format: { containerName: { cpu: [], ram: [] } }
    const MAX_HISTORY = 60;
    let metricsCharts = {};

    // Détection de la page actuelle (contexte)
    const rawPath = window.location.pathname.replace('/', '');
    const currentPath = rawPath === '' ? 'index' : rawPath;

    // --- RBAC: Masquage des éléments sensibles ---
    const role = localStorage.getItem('role') || 'reader';
    if (role !== 'admin') {
        const adminElements = document.querySelectorAll('.control-bar, .nav-link[href="/admin"], .batch-group');
        adminElements.forEach(el => el.style.display = 'none');
        // On modifie l'index pour que le reader ne voit pas les boutons d'action des containers
        const style = document.createElement('style');
        style.innerHTML = '.container-actions { display: none !important; }';
        document.head.appendChild(style);
    }

    if (currentPath === 'admin') {
        if (role !== 'admin') {
            window.location.href = '/';
        } else {
            loadPlatformConfig();
        }
    }

    // --- GESTION DU THÈME ---
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);

    window.toggleTheme = () => {
        const current = document.documentElement.getAttribute('data-theme');
        const next = current === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('theme', next);
    };

    // --- RECHERCHE ET FILTRAGE ---
    window.filterContainers = () => {
        const val = document.getElementById('search-containers').value.toLowerCase();
        document.querySelectorAll('.container-item').forEach(item => {
            const name = item.querySelector('.container-name').textContent.toLowerCase();
            item.style.display = name.includes(val) ? 'flex' : 'none';
        });
    };

    async function fetchStatus() {
        document.querySelectorAll('.health-card').forEach(card => card.classList.add('loading'));

        try {
            const response = await fetch('/api/status');
            const data = await response.json();
            updateUI(data);
            if (data.metrics) {
                updateVisualCharts(data.metrics);
            }
            if (lastUpdate) lastUpdate.textContent = `Dernière mise à jour: ${new Date().toLocaleTimeString()}`;

            const diagnosticOutput = document.getElementById('diag-output');
            // On n'écrase plus automatiquement le diagnosticAvancé (qui est maintenant en HTML possiblement)
            // sauf si on veut explicitement le mettre à jour.
            // if (diagnosticOutput && data.details) { diagnosticOutput.textContent = data.details; }

            // Chargement de la config si on est sur la page patroni
            if (currentPath === 'patroni' && !window.configLoaded) {
                fetchClusterConfig();
                window.configLoaded = true;
            }
        } catch (error) {
            console.error('Erreur status:', error);
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

            // Update History
            if (!metricsHistory[name]) metricsHistory[name] = { cpu: [], ram: [] };
            metricsHistory[name].cpu.push(cpu);
            metricsHistory[name].ram.push(mem);
            if (metricsHistory[name].cpu.length > MAX_HISTORY) {
                metricsHistory[name].cpu.shift();
                metricsHistory[name].ram.shift();
            }

            metricsEl.innerHTML = `
                <span>CPU: <span class="metrics-val">${cpu.toFixed(1)}%</span></span>
                <canvas id="spark-cpu-${containerId}" class="sparkline-container"></canvas>
                <span>RAM: <span class="metrics-val">${mem.toFixed(1)}MB</span></span>
                <canvas id="spark-ram-${containerId}" class="sparkline-container"></canvas>
            `;

            drawSparkline(`spark-cpu-${containerId}`, metricsHistory[name].cpu, '#4f46e5');
            drawSparkline(`spark-ram-${containerId}`, metricsHistory[name].ram, '#0ea5e9');
        } catch (e) {
            console.error("Stats Error:", e);
        }
    }

    function drawSparkline(canvasId, data, color) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        const width = canvas.width = 60;
        const height = canvas.height = 24;

        ctx.clearRect(0, 0, width, height);
        if (data.length < 2) return;

        const max = Math.max(...data, 1);
        const min = Math.min(...data);
        const range = max - min || 1;

        ctx.beginPath();
        ctx.strokeStyle = color;
        ctx.lineWidth = 1.5;
        ctx.lineJoin = 'round';

        data.forEach((val, i) => {
            const x = (i / (MAX_HISTORY - 1)) * width;
            const y = height - ((val - min) / range) * height;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });
        ctx.stroke();
    }

    function updateUI(data) {
        if (healthGrid) {
            healthGrid.innerHTML = '';
            for (const [name, info] of Object.entries(data.cluster)) {
                if (currentPath !== 'index' && name !== currentPath) continue;

                const card = document.createElement('div');
                card.className = 'health-card';
                card.id = `status-${name}`;
                card.innerHTML = `
                    <h3>${name}</h3>
                    <div class="status">
                        <span class="status-badge ${info.alive ? 'online' : 'offline'}">
                            ${info.alive ? 'EN LIGNE' : 'INACCESSIBLE'}
                        </span>
                    </div>
                    <p style="font-size: 0.75rem; color: var(--text-dim); margin-top: 10px;">${info.message || ''}</p>
                `;
                healthGrid.appendChild(card);
            }
        }

        if (containerList) {
            containerList.innerHTML = '';
            const sortedContainers = (data.containers || []).sort((a, b) => {
                const nameA = a.Names && a.Names.length > 0 ? a.Names[0] : "";
                const nameB = b.Names && b.Names.length > 0 ? b.Names[0] : "";
                return nameA.localeCompare(nameB);
            });

            sortedContainers.forEach(c => {
                const name = c.Names[0].replace('/', '');
                let match = currentPath === 'index' ?
                    ['node', 'etcd', 'haproxy', 'pgbouncer'].some(k => name.includes(k)) :
                    (currentPath === 'patroni' ? name.includes('node') : name.includes(currentPath));

                if (!match) return;

                const item = document.createElement('div');
                item.className = 'container-item';
                const isRunning = c.State === 'running';

                item.innerHTML = `
                    <div class="container-info">
                        <div class="container-name">${name}</div>
                        <div class="container-status">${c.Status}</div>
                        ${isRunning ? `<div id="metrics-${c.Id}" class="container-metrics">...</div>` : ''}
                    </div>
                    <div class="container-actions">
                        ${isRunning ? `<button onclick="viewLogs('${name}')">📋 Logs</button>` : ''}
                        <button class="${isRunning ? 'stop' : 'start'}" onclick="controlContainer('${c.Id}', '${isRunning ? 'stop' : 'start'}', '${name}')">
                            ${isRunning ? 'Arrêter' : 'Démarrer'}
                        </button>
                        <button onclick="controlContainer('${c.Id}', 'restart', '${name}')">Redémarrer</button>
                    </div>
                `;
                containerList.appendChild(item);
                if (isRunning) updateContainerMetrics(name, c.Id);
            });
        }

        // Certs rendering remains same...
        if (data.certs && currentPath === 'index') {
            const certList = document.getElementById('cert-list');
            if (certList) {
                certList.innerHTML = '';
                data.certs.forEach(c => {
                    const item = document.createElement('div');
                    item.className = 'container-metrics'; // Reuse style
                    item.style.border = c.critical ? '1px solid var(--error)' : '1px solid var(--glass-border)';
                    item.innerHTML = `<span>${c.critical ? '⚠️' : '📜'} ${c.name}</span><span>Exp: ${c.expiry} (${c.days_left}j)</span>`;
                    certList.appendChild(item);
                });
            }
        }
    }

    // --- ACTIONS ---
    window.controlContainer = async (id, command, name) => {
        try {
            const response = await fetch('/api/control', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id, command, name })
            });
            if (response.ok) fetchStatus();
        } catch (error) { console.error('Action error:', error); }
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
            if (response.ok) setTimeout(fetchStatus, 1500);
        } catch (error) { console.error('Batch error:', error); }
        finally { if (btn) btn.classList.remove('loading'); }
    };

    // --- CONFIG PATRONI ---
    async function fetchClusterConfig() {
        const ed = document.getElementById('config-editor');
        if (!ed) return;
        try {
            const r = await fetch('/api/cluster/config');
            ed.value = await r.text();
        } catch (e) { ed.value = "Erreur chargement config."; }
    }

    window.saveClusterConfig = async () => {
        const config = document.getElementById('config-editor').value;
        const btn = document.getElementById('save-config-btn');

        if (!confirm("⚠️ ATTENTION : La modification de la configuration globale peut déstabiliser le cluster. Continuer ?")) return;
        const challenge = prompt("Veuillez taper 'CONFIRMER' pour appliquer les changements :");
        if (challenge !== 'CONFIRMER') return;

        btn.classList.add('loading');
        try {
            const r = await fetch('/api/cluster/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ config })
            });
            const res = await r.json();
            alert(res.result === 'success' ? "Configuration appliquée !" : "Erreur: " + res.output);
        } catch (e) { alert("Erreur lors de la sauvegarde."); }
        finally { btn.classList.remove('loading'); }
    };

    // Polling metadata
    window.viewDiagnostics = async (theme) => {
        const out = document.getElementById('diag-output');
        out.innerHTML = '<div class="loading">Extraction des diagnostics...</div>';
        try {
            const r = await fetch(`/api/status?page=${theme}`);
            const data = await r.json();
            let raw = data.details || "Aucune donnée disponible";

            // Clean up Docker exec control characters (like \u0001\u0000...)
            raw = raw.replace(/[\u0000-\u001F\u007F-\u009F]/g, "").trim();

            // Si c'est un diagnostic Patroni ou Etcd (contient des +---+ ou | )
            if (raw.includes('+---') || raw.includes('|')) {
                out.innerHTML = parseASCIITable(raw);
            } else {
                out.innerText = raw;
            }
        } catch (e) { out.innerText = "Erreur: " + e; }
    };

    function parseASCIITable(text) {
        // Enlever les lignes de bordure (+---+)
        const lines = text.split('\n').filter(l => l.trim() !== '' && !l.includes('+---'));
        if (lines.length < 1) return `<pre>${text}</pre>`;

        let html = '<div style="overflow-x:auto;"><table class="diag-table"><thead><tr>';

        // La première ligne est souvent le header avec des |
        const headers = lines[0].split('|').map(h => h.trim()).filter(h => h !== '');

        // Si on n'a pas pu splitter par |, c'est peut être juste du texte
        if (headers.length <= 1) return `<pre>${text}</pre>`;

        headers.forEach(h => html += `<th>${h}</th>`);
        html += '</tr></thead><tbody>';

        for (let i = 1; i < lines.length; i++) {
            const cells = lines[i].split('|').map(c => c.trim()).filter(c => c !== '');
            if (cells.length === headers.length) {
                html += '<tr>';
                cells.forEach(c => html += `<td>${c}</td>`);
                html += '</tr>';
            }
        }
        html += '</tbody></table></div>';
        return html;
    }

    window.logout = () => {
        window.location.href = '/logout';
    };

    setInterval(fetchStatus, 5000);
    fetchStatus();

    // Re-expose legacy functions if they exist in HTML with different signatures
    window.switchoverCluster = async () => {
        const leader = prompt("Nom du LEADER actuel (ex: node1, node2) :", "node1");
        const candidate = prompt("Nom du CANDIDAT (ex: node1, node2) :", "node2");
        if (!leader || !candidate) return;

        if (!confirm(`⚠️ SWITCHOVER : Voulez-vous vraiment basculer le rôle de leader de '${leader}' vers '${candidate}' ?`)) return;

        try {
            const r = await fetch('/api/cluster/switchover', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ leader, candidate })
            });
            const res = await r.json();
            alert("📢 Résultats: " + (res.result || res.error || "Opération initiée (Consultez l'audit)"));
            fetchStatus();
        } catch (e) {
            console.error(e);
            alert("❌ Erreur de communication avec le serveur.");
        }
    };

    window.toggleMaintenance = async (mode) => {
        if (!confirm(`Basculer mode maintenance: ${mode} ?`)) return;
        try {
            const r = await fetch('/api/cluster/maintenance', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ mode })
            });
            fetchStatus();
        } catch (e) { console.error(e); }
    };

    // --- CHARTS LOGIC ---
    function updateVisualCharts(metrics) {
        const monitoringGrid = document.querySelector('.health-grid');
        if (!monitoringGrid) return;

        Object.entries(metrics).forEach(([container, types]) => {
            const card = document.getElementById(`status-${container}`);
            if (!card) return;

            let chartCont = card.querySelector('.chart-container');
            if (!chartCont) {
                chartCont = document.createElement('div');
                chartCont.className = 'chart-container';
                chartCont.innerHTML = `<canvas id="chart-${container}"></canvas>`;
                card.appendChild(chartCont);
                initializeChart(container);
            }

            if (metricsCharts[container]) {
                const chart = metricsCharts[container];
                const cpuData = types['cpu'] || [];
                chart.data.labels = cpuData.map((_, i) => i);
                chart.data.datasets[0].data = cpuData.map(m => m.Value);
                chart.update('none');
            }
        });
    }

    function initializeChart(container) {
        const el = document.getElementById(`chart-${container}`);
        if (!el) return;
        const ctx = el.getContext('2d');
        metricsCharts[container] = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CPU Usage',
                    borderColor: '#6366f1',
                    backgroundColor: 'rgba(99, 102, 241, 0.1)',
                    borderWidth: 2,
                    pointRadius: 0,
                    fill: true,
                    tension: 0.4,
                    data: []
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: { display: false },
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(255,255,255,0.05)' },
                        ticks: { color: '#94a3b8', font: { size: 10 } }
                    }
                }
            }
        });
    }

    // --- ADMINISTRATION ---
    async function loadPlatformConfig() {
        try {
            const resp = await fetch('/api/platform/config');
            const cfg = await resp.json();

            if (document.getElementById('mode')) {
                document.getElementById('mode').value = cfg.Mode;
                document.getElementById('etcd_ip').value = cfg.EtcdIP;
                document.getElementById('etcd_port').value = cfg.EtcdPort;
                document.getElementById('patroni_ip').value = cfg.PatroniIP;
                document.getElementById('patroni_port').value = cfg.PatroniPort;
                document.getElementById('haproxy_ip').value = cfg.HaproxyIP;
                document.getElementById('haproxy_port').value = cfg.HaproxyPort;
                document.getElementById('pgbouncer_ip').value = cfg.PgbouncerIP;
                document.getElementById('pgbouncer_port').value = cfg.PgbouncerPort;
            }
        } catch (err) { console.error('Load config error:', err); }
    }

    window.savePlatformConfig = async () => {
        const btn = document.getElementById('save-platform-btn');
        if (btn) btn.classList.add('loading');

        const cfg = {
            Mode: document.getElementById('mode').value,
            EtcdIP: document.getElementById('etcd_ip').value,
            EtcdPort: document.getElementById('etcd_port').value,
            PatroniIP: document.getElementById('patroni_ip').value,
            PatroniPort: document.getElementById('patroni_port').value,
            HaproxyIP: document.getElementById('haproxy_ip').value,
            HaproxyPort: document.getElementById('haproxy_port').value,
            PgbouncerIP: document.getElementById('pgbouncer_ip').value,
            PgbouncerPort: document.getElementById('pgbouncer_port').value
        };

        try {
            const resp = await fetch('/api/platform/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(cfg)
            });
            if (resp.ok) {
                alert('Configuration de la plateforme enregistrée !');
            } else {
                alert('Erreur lors de l\'enregistrement');
            }
        } catch (err) { alert('Erreur réseau'); }
        finally { if (btn) btn.classList.remove('loading'); }
    };
});
