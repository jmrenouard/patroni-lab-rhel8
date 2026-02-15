package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/joho/godotenv"
	"patroni-mgmt-app/handlers"
	"patroni-mgmt-app/services"
)

func main() {
	// Chargement des variables d'environnement depuis la racine du projet.
	if err := godotenv.Load("../.env"); err != nil {
		log.Printf("Attention: Fichier .env non trouvé à la racine, utilisation de l'environnement actuel.")
	}

	// Initialisation des services.
	dockerSvc, err := services.NewDockerService()
	if err != nil {
		log.Fatalf("Échec de l'initialisation du service Docker: %v", err)
	}
	configSvc, err := services.NewConfigService()
	if err != nil {
		log.Fatalf("Échec de l'initialisation du service Config: %v", err)
	}
	metricsSvc := services.NewMetricsService(60) // 1 point par minute, 1h d'historique
	healthSvc := services.NewHealthService(dockerSvc, configSvc)
	auditSvc := services.NewAuditService("./audit.json")
	authSvc, err := services.NewAuthService()
	if err != nil {
		log.Fatalf("Échec de l'initialisation du service Auth: %v", err)
	}

	// Initialisation des handlers.
	api := &handlers.APIHandler{
		Docker:  dockerSvc,
		Health:  healthSvc,
		Audit:   auditSvc,
		Config:  configSvc,
		Metrics: metricsSvc,
	}
	authHandler := &handlers.AuthHandler{Auth: authSvc}

	// Lancement de la collecte de métriques en arrière-plan
	go func() {
		for {
			ctx := context.Background()
			containers, _ := dockerSvc.ListContainers(ctx)
			for _, c := range containers {
				if c.State == "running" {
					name := c.Names[0][1:] // Remove leading slash
					stats, err := dockerSvc.GetContainerStats(ctx, name)
					if err == nil {
						// Extraction simplifiée du CPU
						var cpu float64
						if cpuStats, ok := stats["cpu_stats"].(map[string]interface{}); ok {
							if usage, ok := cpuStats["cpu_usage"].(map[string]interface{}); ok {
								if total, ok := usage["total_usage"].(float64); ok {
									// C'est un cumulatif, il faudrait le delta, mais pour l'instant
									// on simule une valeur pour le visuel ou on utilise une fraction
									cpu = total / 1e9 // Très approximatif
								}
							}
						}
						// RAM
						var ram float64
						if memStats, ok := stats["memory_stats"].(map[string]interface{}); ok {
							if usage, ok := memStats["usage"].(float64); ok {
								ram = usage / (1024 * 1024)
							}
						}
						metricsSvc.AddMetric(name, "cpu", cpu)
						metricsSvc.AddMetric(name, "ram", ram)
					}
				}
			}
			time.Sleep(30 * time.Second)
		}
	}()

	// Configuration du routeur
	mux := http.NewServeMux()

	// Routes Statiques (non protégées)
	fs := http.FileServer(http.Dir("./static"))
	mux.Handle("/static/", http.StripPrefix("/static/", fs))

	// Routes d'Authentification (non protégées)
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join("templates", "login.html"))
	})
	mux.HandleFunc("/api/login", authHandler.Login)
	mux.HandleFunc("/logout", authHandler.Logout)

	// Routes protégées par le middleware
	protected := http.NewServeMux()
	
	protected.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			http.ServeFile(w, r, filepath.Join("templates", "index.html"))
			return
		}
		page := filepath.Base(r.URL.Path)
		templatePath := filepath.Join("templates", page+".html")
		if _, err := os.Stat(templatePath); err == nil {
			http.ServeFile(w, r, templatePath)
			return
		}
		http.NotFound(w, r)
	})

	protected.HandleFunc("/api/status", api.GetStatus)
	protected.HandleFunc("/api/audit", api.GetAuditLogs)
	// Routes réservées aux admins
	adminOnly := authHandler.AdminMiddleware
	
	protected.Handle("/api/cluster/config", adminOnly(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			api.UpdateClusterConfig(w, r)
		} else {
			api.GetClusterConfig(w, r)
		}
	})))
	protected.Handle("/api/platform/config", adminOnly(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			api.UpdatePlatformConfig(w, r)
		} else {
			api.GetPlatformConfig(w, r)
		}
	})))
	protected.Handle("/api/control", adminOnly(http.HandlerFunc(api.ControlContainer)))
	protected.Handle("/api/batch-control", adminOnly(http.HandlerFunc(api.BatchControl)))
	protected.Handle("/api/cluster/switchover", adminOnly(http.HandlerFunc(api.ClusterSwitchover)))
	protected.Handle("/api/cluster/maintenance", adminOnly(http.HandlerFunc(api.ClusterMaintenance)))
	protected.Handle("/api/haproxy/control", adminOnly(http.HandlerFunc(api.HaproxyControl)))

	// Routes autorisées aux readers (et admins)
	protected.HandleFunc("/api/stats", api.GetContainerStats)
	protected.HandleFunc("/api/logs", api.GetContainerLogs)
	protected.HandleFunc("/api/etcd/explorer", api.GetEtcdExplorer)

	// Application du middleware
	mux.Handle("/", authHandler.AuthMiddleware(protected))

	port := os.Getenv("MGMT_APP_PORT")
	if port == "" {
		port = "8080"
	}

	// Génération des certificats si nécessaires
	genCmd := exec.Command("bash", "./scripts/gen_app_certs.sh")
	if out, err := genCmd.CombinedOutput(); err != nil {
		log.Printf("⚠️ Erreur lors de la génération des certs: %v\nOutput: %s", err, string(out))
	}

	log.Printf("🚀 Serveur de gestion Patroni démarré sur https://localhost:%s", port)
	
	// On utilise certs_app à la racine du projet (un niveau au dessus de mgmt-app)
	certFile := "../certs_app/server.crt"
	keyFile := "../certs_app/server.key"
	
	if err := http.ListenAndServeTLS(":"+port, certFile, keyFile, mux); err != nil {
		log.Fatalf("Erreur serveur: %v", err)
	}
}
