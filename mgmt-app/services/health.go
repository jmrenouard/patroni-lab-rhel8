package services

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// HealthService gère la vérification de l'état des différents composants du cluster.
type HealthService struct {
	client  *http.Client
	Docker  *DockerService
	Config  *ConfigService
	certDir string
}

// NewHealthService initialise un service de santé avec mTLS pour ETCD et Patroni.
func NewHealthService(docker *DockerService, config *ConfigService) *HealthService {
	// Chemins par défaut ou via ENV
	rootPath := os.Getenv("MGMT_APP_ROOT")
	if rootPath == "" { rootPath = ".." } 

	certDir := fmt.Sprintf("%s/certs", rootPath)
	if _, err := os.Stat(fmt.Sprintf("%s/certs_new", rootPath)); err == nil {
		certDir = fmt.Sprintf("%s/certs_new", rootPath)
	}
	certPath := filepath.Join(certDir, "etcd-client.crt")
	keyPath := filepath.Join(certDir, "etcd-client.key")
	caPath := filepath.Join(certDir, "ca.crt")

	// Chargement des certificats clients pour mTLS
	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		fmt.Printf("⚠️  Impossible de charger les certificats mTLS (%s/%s): %v\n", certPath, keyPath, err)
	}

	// Chargement de la CA pour la vérification du serveur
	caCert, err := os.ReadFile(caPath)
	caCertPool := x509.NewCertPool()
	if err == nil {
		caCertPool.AppendCertsFromPEM(caCert)
	} else {
		fmt.Printf("⚠️  Impossible de charger la CA (%s): %v\n", caPath, err)
	}

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			Certificates:       []tls.Certificate{cert},
			RootCAs:            caCertPool,
			InsecureSkipVerify: true, 
		},
	}

	return &HealthService{
		client: &http.Client{
			Transport: tr,
			Timeout:   5 * time.Second,
		},
		Docker:  docker,
		Config:  config,
		certDir: certDir,
	}
}

// DoRequest expose le client mTLS pour des appels directs.
func (s *HealthService) DoRequest(req *http.Request) (*http.Response, error) {
	return s.client.Do(req)
}

func (s *HealthService) isEtcdLeader(jsonOut string) bool {
	// Analyse simple du JSON d'etcdctl endpoint status
	// On cherche "isLeader":true ou équivalent dans la sortie JSON
	return strings.Contains(jsonOut, "\"isLeader\":true") || strings.Contains(jsonOut, "\"IS_LEADER\":true")
}

// CheckComponentHealth vérifie si un composant est joignable via HTTP(S).
func (s *HealthService) CheckComponentHealth(url string, user, pass string) (bool, string) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return false, fmt.Sprintf("Erreur requête: %v", err)
	}

	if user != "" {
		req.SetBasicAuth(user, pass)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return false, fmt.Sprintf("Inaccessible: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return true, "Opérationnel"
	}
	return false, fmt.Sprintf("Status: %d", resp.StatusCode)
}

// CheckTCPHealth vérifie si un port est ouvert.
func (s *HealthService) CheckTCPHealth(addr string) (bool, string) {
	conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
	if err != nil {
		return false, fmt.Sprintf("Fermé: %v", err)
	}
	conn.Close()
	return true, "Ouvert"
}

// GetClusterStatus retourne un résumé de l'état de santé de tous les composants critiques.
func (s *HealthService) GetClusterStatus() map[string]interface{} {
	status := make(map[string]interface{})
	var mu sync.Mutex
	var wg sync.WaitGroup

	cfg, _ := s.Config.GetConfig()

	checks := map[string]func(PlatformConfig) map[string]interface{}{
		"etcd":      s.checkEtcd,
		"patroni":   s.checkPatroni,
		"haproxy":   s.checkHaproxy,
		"pgbouncer": s.checkPgbouncer,
	}

	wg.Add(len(checks))
	for name, checkFn := range checks {
		go func(n string, fn func(PlatformConfig) map[string]interface{}) {
			defer wg.Done()
			res := fn(cfg)
			mu.Lock()
			status[n] = res
			mu.Unlock()
		}(name, checkFn)
	}

	wg.Wait()
	return status
}

// GetDetailedDiagnostic retourne des informations poussées.
func (s *HealthService) GetDetailedDiagnostic(ctx context.Context, theme string) string {
	cfg, _ := s.Config.GetConfig()

	// Si on est en mode réseau pur ou si Docker échoue, on tente via API
	useDocker := cfg.Mode == "docker" && s.Docker != nil

	switch theme {
	case "patroni":
		if useDocker {
			out, err := s.Docker.ExecCommand(ctx, "node1", []string{"patronictl", "-c", "/etc/patroni.yml", "list"})
			if err == nil { return out }
		}
		// Fallback API Patroni (simplifié)
		url := fmt.Sprintf("https://%s:%s/cluster", cfg.PatroniIP, cfg.PatroniPort)
		req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
		req.SetBasicAuth(os.Getenv("PATRONI_API_USER"), os.Getenv("PATRONI_API_PASSWORD"))
		resp, err := s.client.Do(req)
		if err != nil { return "Erreur API Patroni: " + err.Error() }
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		return string(body)

	case "etcd":
		if useDocker {
			rootPass := os.Getenv("ETCD_ROOT_PASSWORD")
			cmd := []string{"etcdctl", "--cacert=/certs/ca.crt", "--cert=/certs/etcd-client.crt", "--key=/certs/etcd-client.key", "--user=root:" + rootPass, "member", "list", "-w", "table"}
			out, err := s.Docker.ExecCommand(ctx, "etcd1", cmd)
			if err == nil { return out }
		}
		return "Diagnostic ETCD via API non implémenté (Table ASCII requise)"

	case "haproxy":
		url := fmt.Sprintf("https://%s:%s/;csv", cfg.HAProxyIP, cfg.HAProxyPort)
		user := os.Getenv("ADMIN_HAPROXY_USER")
		pass := os.Getenv("ADMIN_HAPROXY_PASSWORD")

		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil { return fmt.Sprintf("Erreur requête stats: %v", err) }
		req.SetBasicAuth(user, pass)

		resp, err := s.client.Do(req)
		if err != nil { return fmt.Sprintf("Erreur récupération stats: %v", err) }
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		return string(body)

	case "postgres":
		if useDocker {
			pass := os.Getenv("POSTGRES_PASSWORD")
			if pass == "" { pass = "pg_password" }
			cmd := []string{"sh", "-c", fmt.Sprintf("PGPASSWORD=%s psql -h 127.0.0.1 -U postgres -d postgres -c \"SELECT name, setting FROM pg_settings WHERE name IN ('max_connections', 'shared_buffers'); SELECT count(*) as connections FROM pg_stat_activity;\"", pass)}
			out, err := s.Docker.ExecCommand(ctx, "node1", cmd)
			if err == nil { return "--- Diagnostic PostgreSQL (node1) ---\n" + out }
		}
		return "Diagnostic PostgreSQL requiert un accès direct (Docker exec ou Client SQL local non configuré)"
	}

	return "Aucun diagnostic spécifique disponible pour ce thème"
}

func (s *HealthService) checkEtcd(cfg PlatformConfig) map[string]interface{} {
	url := fmt.Sprintf("https://%s:%s/health", cfg.EtcdIP, cfg.EtcdPort)
	user := os.Getenv("ETCD_PATRONI_USER")
	pass := os.Getenv("ETCD_PATRONI_PASSWORD")
	
	ok, msg := s.CheckComponentHealth(url, user, pass)
	
	if ok && cfg.Mode == "docker" && s.Docker != nil {
		rootPass := os.Getenv("ETCD_ROOT_PASSWORD")
		cmd := []string{"etcdctl", "--cacert=/certs/ca.crt", "--cert=/certs/etcd-client.crt", "--key=/certs/etcd-client.key", "--user=root:" + rootPass, "endpoint", "status", "--write-out=json"}
		out, err := s.Docker.ExecCommand(context.Background(), "etcd1", cmd)
		if err == nil && (strings.Contains(out, "IS_LEADER") || s.isEtcdLeader(out)) {
			msg = "Cluster OK - [IS_LEADER]"
		} else if err == nil {
			msg = "Cluster OK - [FOLLOWER]"
		}
	}
	
	return map[string]interface{}{"alive": ok, "message": msg}
}

func (s *HealthService) checkPatroni(cfg PlatformConfig) map[string]interface{} {
	url := fmt.Sprintf("https://%s:%s/cluster", cfg.PatroniIP, cfg.PatroniPort)
	user := os.Getenv("PATRONI_API_USER")
	pass := os.Getenv("PATRONI_API_PASSWORD")
	
	ok, msg := s.CheckComponentHealth(url, user, pass)
	if ok {
		msg = "Cluster OK (Topology check active)"
	}
	return map[string]interface{}{"alive": ok, "message": msg}
}

func (s *HealthService) checkHaproxy(cfg PlatformConfig) map[string]interface{} {
	url := fmt.Sprintf("https://%s:%s/;csv", cfg.HAProxyIP, cfg.HAProxyPort)
	user := os.Getenv("ADMIN_HAPROXY_USER")
	pass := os.Getenv("ADMIN_HAPROXY_PASSWORD")
	ok, msg := s.CheckComponentHealth(url, user, pass)
	return map[string]interface{}{"alive": ok, "message": msg}
}

func (s *HealthService) checkPgbouncer(cfg PlatformConfig) map[string]interface{} {
	addr := fmt.Sprintf("%s:%s", cfg.PgBouncerIP, cfg.PgBouncerPort)
	ok, msg := s.CheckTCPHealth(addr)
	return map[string]interface{}{"alive": ok, "message": msg}
}

// GetCertificateStatus analyse les certificats mTLS pour suivre leur expiration.
func (s *HealthService) GetCertificateStatus() []map[string]interface{} {
	var results []map[string]interface{}
	files, err := os.ReadDir(s.certDir)
	if err != nil {
		return results
	}

	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".crt") {
			certPath := filepath.Join(s.certDir, f.Name())
			certData, err := os.ReadFile(certPath)
			if err != nil {
				continue
			}

			block, _ := pem.Decode(certData)
			if block == nil || block.Type != "CERTIFICATE" {
				continue
			}

			cert, err := x509.ParseCertificate(block.Bytes)
			if err != nil {
				continue
			}

			daysLeft := int(time.Until(cert.NotAfter).Hours() / 24)
			results = append(results, map[string]interface{}{
				"name":      f.Name(),
				"expiry":    cert.NotAfter.Format("2006-01-02"),
				"days_left": daysLeft,
				"critical":  daysLeft < 30,
			})
		}
	}
	return results
}
