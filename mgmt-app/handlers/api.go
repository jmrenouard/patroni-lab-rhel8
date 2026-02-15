package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"patroni-mgmt-app/services"
)

// APIHandler regroupe les services nécessaires pour les endpoints API.
type APIHandler struct {
	Docker  *services.DockerService
	Health  *services.HealthService
	Audit   *services.AuditService
	Config  *services.ConfigService
	Metrics *services.MetricsService
}

// GetStatus retourne l'état complet du cluster et des containers.
func (h *APIHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	
	containers, _ := h.Docker.ListContainers(ctx)
	cluster := h.Health.GetClusterStatus()

	response := map[string]interface{}{
		"containers": containers,
		"cluster":    cluster,
		"certs":      h.Health.GetCertificateStatus(),
		"metrics":    h.Metrics.GetHistory(),
	}

	// Si un filtre de page est présent, on peut ajouter des diagnostics détaillés
	page := r.URL.Query().Get("page")
	if page != "" && page != "index" {
		response["details"] = h.Health.GetDetailedDiagnostic(ctx, page)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// GetPlatformConfig retourne la configuration de la plateforme (IPs, Ports, Mode).
func (h *APIHandler) GetPlatformConfig(w http.ResponseWriter, r *http.Request) {
	cfg, err := h.Config.GetConfig()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(cfg)
}

// UpdatePlatformConfig met à jour la configuration de la plateforme.
func (h *APIHandler) UpdatePlatformConfig(w http.ResponseWriter, r *http.Request) {
	var cfg services.PlatformConfig
	if err := json.NewDecoder(r.Body).Decode(&cfg); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	if err := h.Config.UpdateConfig(cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	h.Audit.LogAction("admin", "PLATFORM_CONFIG_UPDATE", "system", "Configuration de la plateforme mise à jour", "SUCCESS")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success"})
}

// GetAuditLogs retourne l'historique des actions d'administration.
func (h *APIHandler) GetAuditLogs(w http.ResponseWriter, r *http.Request) {
	entries, err := h.Audit.GetEntries()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entries)
}

// GetClusterConfig retourne la configuration actuelle de Patroni.
func (h *APIHandler) GetClusterConfig(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	cfg, _ := h.Config.GetConfig()

	if cfg.Mode == "docker" {
		cmd := []string{"patronictl", "-c", "/etc/patroni.yml", "show-config"}
		output, err := h.Docker.ExecCommand(ctx, "node1", cmd)
		if err == nil {
			w.Header().Set("Content-Type", "text/yaml")
			w.Write([]byte(output))
			return
		}
	}

	// Fallback API Patroni
	url := fmt.Sprintf("https://%s:%s/config", cfg.PatroniIP, cfg.PatroniPort)
	req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
	req.SetBasicAuth(os.Getenv("PATRONI_API_USER"), os.Getenv("PATRONI_API_PASSWORD"))
	resp, err := h.Health.DoRequest(req)
	if err != nil {
		http.Error(w, fmt.Sprintf("Erreur API Patroni: %v", err), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()
	io.Copy(w, resp.Body)
}

// UpdateClusterConfig met à jour la configuration Patroni.
func (h *APIHandler) UpdateClusterConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Config string `json:"config"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	cfg, _ := h.Config.GetConfig()

	if cfg.Mode == "docker" {
		cmd := []string{"sh", "-c", fmt.Sprintf("echo '%s' | patronictl -c /etc/patroni.yml edit-config --apply - --force", req.Config)}
		output, err := h.Docker.ExecCommand(ctx, "node1", cmd)
		if err == nil {
			h.Audit.LogAction("admin", "CONFIG_UPDATE", "cluster", "Configuration updated successfully (Docker)", "SUCCESS")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(map[string]string{"result": "success", "output": output})
			return
		}
	}

	// Fallback/Default: Patroni API
	url := fmt.Sprintf("https://%s:%s/config", cfg.PatroniIP, cfg.PatroniPort)
	patchData := strings.NewReader(req.Config)
	httpReq, _ := http.NewRequestWithContext(ctx, "PATCH", url, patchData)
	httpReq.SetBasicAuth(os.Getenv("PATRONI_API_USER"), os.Getenv("PATRONI_API_PASSWORD"))
	
	resp, err := h.Health.DoRequest(httpReq)
	if err != nil {
		h.Audit.LogAction("admin", "CONFIG_UPDATE", "cluster", "Failed to update config (API)", "FAILURE")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()
	
	h.Audit.LogAction("admin", "CONFIG_UPDATE", "cluster", "Configuration updated successfully (API)", "SUCCESS")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success"})
}

// ControlContainer permet de démarrer, arrêter ou redémarrer un container.
func (h *APIHandler) ControlContainer(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		ID     string `json:"id"`
		Name   string `json:"name"` // Ajout du nom pour le log
		Command string `json:"command"`
	}

	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	var err error

	switch action.Command {
	case "start":
		err = h.Docker.StartContainer(ctx, action.ID)
	case "stop":
		err = h.Docker.StopContainer(ctx, action.ID)
	case "restart":
		err = h.Docker.RestartContainer(ctx, action.ID)
	default:
		http.Error(w, "Commande inconnue", http.StatusBadRequest)
		return
	}

	status := "SUCCESS"
	if err != nil {
		status = "FAILURE"
	}
	h.Audit.LogAction("admin", strings.ToUpper(action.Command), action.Name, "", status)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success"})
}

// BatchControl permet de contrôler un groupe de containers (thème ou 'all').
func (h *APIHandler) BatchControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		Theme  string `json:"theme"`
		Command string `json:"command"`
	}

	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	err := h.Docker.BatchControl(ctx, action.Theme, action.Command)

	status := "SUCCESS"
	if err != nil {
		status = "FAILURE"
	}
	h.Audit.LogAction("admin", "BATCH_"+strings.ToUpper(action.Command), action.Theme, "", status)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success"})
}

// GetContainerStats retourne les stats d'un container spécifique.
func (h *APIHandler) GetContainerStats(w http.ResponseWriter, r *http.Request) {
	// ... (la suite reste identique jusqu'à Switchover)
	name := r.URL.Query().Get("name")
	if name == "" {
		http.Error(w, "Nom de container requis", http.StatusBadRequest)
		return
	}

	stats, err := h.Docker.GetContainerStats(r.Context(), name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

// GetContainerLogs retourne les derniers logs d'un container.
func (h *APIHandler) GetContainerLogs(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	tail := r.URL.Query().Get("tail")
	if tail == "" {
		tail = "100"
	}

	logs, err := h.Docker.GetContainerLogs(r.Context(), name, tail)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(logs))
}

// GetEtcdExplorer permet d'explorer les clés ETCD via etcdctl.
func (h *APIHandler) GetEtcdExplorer(w http.ResponseWriter, r *http.Request) {
	prefix := r.URL.Query().Get("prefix")
	if prefix == "" {
		prefix = "/"
	}

	ctx := r.Context()
	// Utilisation de etcdctl dans le container etcd1
	cmd := []string{"etcdctl", "get", prefix, "--prefix", "--keys-only"}
	output, err := h.Docker.ExecCommand(ctx, "etcd1", cmd)
	if err != nil {
		// On ne retourne pas d'erreur 500 si etcdctl renvoie vide ou erreur mineure
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{"keys": []string{}, "prefix": prefix, "error": output})
		return
	}

	keys := strings.Split(strings.TrimSpace(output), "\n")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"keys": keys, "prefix": prefix})
}

// ClusterSwitchover déclenche un basculement Patroni.
func (h *APIHandler) ClusterSwitchover(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		Leader    string `json:"leader"`
		Candidate string `json:"candidate"`
	}

	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	// Find the current leader to send the switchover request to ANY node (Patroni handles it)
	// But it's safer to target a node we know is UP.
	targetHost := action.Leader
	if targetHost == "" {
		targetHost = "node1" // Fallback
	}

	payload := map[string]string{
		"leader":    action.Leader,
		"candidate": action.Candidate,
		"scheduled": "", // Immediate
	}
	body, _ := json.Marshal(payload)
	
	// Determine the port for the target host from environment variables (mapping)
	// Example: EXT_PATRONI_PORT_NODE1 -> 8008
	portKey := fmt.Sprintf("EXT_PATRONI_PORT_%s", strings.ToUpper(targetHost))
	port := os.Getenv(portKey)
	if port == "" {
		port = "8008" // Default internal port
	}

	// If we are running on host, 'nodeX' is not resolvable. We use localhost + mapped port.
	// In production (in container), nodeX should work or we use container IPs.
	// For this lab, we use localhost + port mapping if possible.
	apiHost := targetHost
	if os.Getenv("MGMT_APP_IN_CONTAINER") != "true" {
		apiHost = "localhost"
	}
	
	url := fmt.Sprintf("https://%s:%s/switchover", apiHost, port)
	req, _ := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	req.SetBasicAuth(os.Getenv("PATRONI_API_USER"), os.Getenv("PATRONI_API_PASSWORD"))

	resp, err := h.Health.DoRequest(req)
	output := ""
	if err == nil {
		defer resp.Body.Close()
		b, _ := io.ReadAll(resp.Body)
		output = string(b)
		if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
			err = fmt.Errorf("Patroni API (%s) returned %d: %s", targetHost, resp.StatusCode, output)
		}
	} else {
		output = err.Error()
	}
	
	result := "SUCCESS"
	if err != nil {
		result = "FAILURE"
	}

	if h.Audit != nil {
		h.Audit.LogAction("postgres", "SWITCHOVER", fmt.Sprintf("Bascule de %s vers %s", action.Leader, action.Candidate), fmt.Sprintf("Output: %s", output), result)
	}

	if err != nil {
		http.Error(w, fmt.Sprintf("%v: %s", err, output), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success", "output": output})
}

// ClusterMaintenance active ou désactive le mode pause de Patroni.
func (h *APIHandler) ClusterMaintenance(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		Mode string `json:"mode"` // "on" or "off"
	}

	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	patroniCmd := "pause"
	if action.Mode == "off" {
		patroniCmd = "resume"
	}

	cmd := []string{"patronictl", "-c", "/etc/patroni.yml", patroniCmd, "--force"}
	output, err := h.Docker.ExecCommand(ctx, "node1", cmd)
	if err != nil {
		http.Error(w, fmt.Sprintf("%v: %s", err, output), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success", "output": output})
}

// HaproxyControl permet de gérer les backends HAProxy via le socket runtime.
func (h *APIHandler) HaproxyControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		Server  string `json:"server"`  // ex: node1
		Backend string `json:"backend"` // ex: nodes
		Command string `json:"command"` // "disable", "enable", "ready" (drain is 'maint')
	}

	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	// Mappage des commandes HAProxy
	hpCmd := action.Command
	if hpCmd == "drain" {
		hpCmd = "set server " + action.Backend + "/" + action.Server + " state maint"
	} else if hpCmd == "ready" {
		hpCmd = "set server " + action.Backend + "/" + action.Server + " state ready"
	} else {
		hpCmd = action.Command + " server " + action.Backend + "/" + action.Server
	}

	cmd := []string{"sh", "-c", fmt.Sprintf("echo '%s' | socat stdio /tmp/haproxy.sock", hpCmd)}
	output, err := h.Docker.ExecCommand(ctx, "haproxy", cmd)
	if err != nil {
		http.Error(w, fmt.Sprintf("%v: %s", err, output), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success", "output": output})
}
