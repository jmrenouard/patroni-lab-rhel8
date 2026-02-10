package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"

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
	healthSvc := services.NewHealthService(dockerSvc)

	// Initialisation des handlers.
	api := &handlers.APIHandler{
		Docker: dockerSvc,
		Health: healthSvc,
	}

	// Configuration des routes.
	http.HandleFunc("/api/status", api.GetStatus)
	http.HandleFunc("/api/control", api.ControlContainer)
	http.HandleFunc("/api/batch-control", api.BatchControl)
	http.HandleFunc("/api/stats", api.GetContainerStats)
	http.HandleFunc("/api/logs", api.GetContainerLogs)
	http.HandleFunc("/api/cluster/switchover", api.ClusterSwitchover)
	http.HandleFunc("/api/cluster/maintenance", api.ClusterMaintenance)
	http.HandleFunc("/api/etcd/explorer", api.GetEtcdExplorer)
	http.HandleFunc("/api/haproxy/control", api.HaproxyControl)

	// Servir les fichiers statiques (CSS/JS).
	fs := http.FileServer(http.Dir("./static"))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	// Servir la page principale.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			http.ServeFile(w, r, filepath.Join("templates", "index.html"))
			return
		}
		
		// Gestion dynamique des sous-pages (etcd, patroni, haproxy)
		page := filepath.Base(r.URL.Path)
		templatePath := filepath.Join("templates", page+".html")
		if _, err := os.Stat(templatePath); err == nil {
			http.ServeFile(w, r, templatePath)
			return
		}

		http.NotFound(w, r)
	})

	port := os.Getenv("MGMT_APP_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 Serveur de gestion Patroni démarré sur http://localhost:%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Erreur serveur: %v", err)
	}
}
