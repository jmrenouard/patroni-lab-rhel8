package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"patroni-mgmt-app/services"
)

// APIHandler regroupe les services nécessaires pour les endpoints API.
type APIHandler struct {
	Docker *services.DockerService
	Health *services.HealthService
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
	}

	// Si un filtre de page est présent, on peut ajouter des diagnostics détaillés
	page := r.URL.Query().Get("page")
	if page != "" && page != "index" {
		response["details"] = h.Health.GetDetailedDiagnostic(ctx, page)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// ControlContainer permet de démarrer, arrêter ou redémarrer un container.
func (h *APIHandler) ControlContainer(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var action struct {
		ID     string `json:"id"`
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

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"result": "success"})
}

// GetContainerStats retourne les stats d'un container spécifique.
func (h *APIHandler) GetContainerStats(w http.ResponseWriter, r *http.Request) {
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

	ctx := r.Context()
	// On tente l'exécution sur node1 par défaut pour patronictl
	cmd := []string{"patronictl", "-c", "/etc/patroni.yml", "switchover", "--leader", action.Leader, "--candidate", action.Candidate, "--force"}
	output, err := h.Docker.ExecCommand(ctx, "node1", cmd)
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
