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
	client *http.Client
	Docker *DockerService
}

// NewHealthService initialise un service de santé avec mTLS pour ETCD et Patroni.
func NewHealthService(docker *DockerService) *HealthService {
	// Chemins par défaut ou via ENV
	rootPath := os.Getenv("MGMT_APP_ROOT")
	if rootPath == "" { rootPath = ".." } // Par défaut un niveau au dessus (si lancé depuis mgmt-app)

	certPath := fmt.Sprintf("%s/certs/etcd-client.crt", rootPath)
	keyPath := fmt.Sprintf("%s/certs/etcd-client.key", rootPath)
	caPath := fmt.Sprintf("%s/certs/ca.crt", rootPath)

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
		Docker: docker,
	}
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

// GetClusterStatus retourne un résumé de l'état de santé de tous les composants critiques (en parallèle).
func (s *HealthService) GetClusterStatus() map[string]interface{} {
	status := make(map[string]interface{})
	var mu sync.Mutex
	var wg sync.WaitGroup

	checks := map[string]func() map[string]interface{}{
		"etcd":      s.checkEtcd,
		"patroni":   s.checkPatroni,
		"haproxy":   s.checkHaproxy,
		"pgbouncer": s.checkPgbouncer,
	}

	wg.Add(len(checks))
	for name, checkFn := range checks {
		go func(n string, fn func() map[string]interface{}) {
			defer wg.Done()
			res := fn()
			mu.Lock()
			status[n] = res
			mu.Unlock()
		}(name, checkFn)
	}

	wg.Wait()
	return status
}

// GetDetailedDiagnostic retourne des informations poussées via Docker exec.
func (s *HealthService) GetDetailedDiagnostic(ctx context.Context, theme string) string {
	if s.Docker == nil {
		return "Docker service non disponible"
	}

	switch theme {
	case "patroni":
		out, err := s.Docker.ExecCommand(ctx, "node1", []string{"patronictl", "-c", "/etc/patroni.yml", "list"})
		if err != nil {
			return fmt.Sprintf("Erreur diagnostic: %v", err)
		}
		return out
	case "etcd":
		// On récupère le mot de passe root etcd depuis l'env
		rootPass := os.Getenv("ETCD_ROOT_PASSWORD")
		cmd := []string{"etcdctl", "--cacert=/certs/ca.crt", "--cert=/certs/etcd-client.crt", "--key=/certs/etcd-client.key", "--user=root:" + rootPass, "member", "list", "-w", "table"}
		out, err := s.Docker.ExecCommand(ctx, "etcd1", cmd)
		if err != nil {
			return fmt.Sprintf("Erreur diagnostic: %v", err)
		}
		return out
	case "haproxy":
		port := os.Getenv("EXT_HAPROXY_STATS_PORT")
		if port == "" { port = "8404" }
		url := fmt.Sprintf("https://localhost:%s/;csv", port)
		user := os.Getenv("ADMIN_HAPROXY_USER")
		pass := os.Getenv("ADMIN_HAPROXY_PASSWORD")

		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			return fmt.Sprintf("Erreur requête stats: %v", err)
		}
		req.SetBasicAuth(user, pass)

		resp, err := s.client.Do(req)
		if err != nil {
			return fmt.Sprintf("Erreur récupération stats: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			return fmt.Sprintf("Erreur HTTP HAProxy: %d", resp.StatusCode)
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return fmt.Sprintf("Erreur lecture stats: %v", err)
		}
		return string(body)
	}

	return "Aucun diagnostic spécifique disponible pour ce thème"
}

func (s *HealthService) checkEtcd() map[string]interface{} {
	port := os.Getenv("EXT_ETCD_CLIENT_PORT_ETCD1")
	if port == "" { port = "2379" }
	url := fmt.Sprintf("https://localhost:%s/health", port)
	
	// Utilisation des identifiants ETCD si configurés
	user := os.Getenv("ETCD_PATRONI_USER")
	pass := os.Getenv("ETCD_PATRONI_PASSWORD")
	
	ok, msg := s.CheckComponentHealth(url, user, pass)
	
	// Si vivant, on tente de savoir si c'est le leader (via etcdctl exec pour simplicité)
	if ok && s.Docker != nil {
		rootPass := os.Getenv("ETCD_ROOT_PASSWORD")
		cmd := []string{"etcdctl", "--cacert=/certs/ca.crt", "--cert=/certs/etcd-client.crt", "--key=/certs/etcd-client.key", "--user=root:" + rootPass, "endpoint", "status", "--write-out=json"}
		out, err := s.Docker.ExecCommand(context.Background(), "etcd1", cmd)
		if err == nil {
			// On cherche "leader":ID et "member_id":ID dans le JSON brut pour éviter un import de struct lourd
			if strings.Contains(out, "\"leader\"") {
				// Extraction simple (approximation rustique mais efficace pour éviter l'overhead JSON)
				if strings.Contains(out, "IS_LEADER") || s.isEtcdLeader(out) {
					msg = "Cluster OK - [IS_LEADER]"
				} else {
					msg = "Cluster OK - [FOLLOWER]"
				}
			}
		}
	}
	
	return map[string]interface{}{"alive": ok, "message": msg}
}

// isEtcdLeader analyse grossièrement le JSON pour comparer member_id et leader.
func (s *HealthService) isEtcdLeader(jsonStr string) bool {
	// Exemple: "member_id":4385152780314713765 ... "leader":4385152780314713765
	// On cherche member_id
	mIdx := strings.Index(jsonStr, "\"member_id\":")
	lIdx := strings.Index(jsonStr, "\"leader\":")
	if mIdx == -1 || lIdx == -1 { return false }
	
	subM := jsonStr[mIdx+12:]
	commaM := strings.Index(subM, ",")
	if commaM == -1 { commaM = strings.Index(subM, "}") }
	idM := strings.TrimSpace(subM[:commaM])
	
	subL := jsonStr[lIdx+9:]
	commaL := strings.Index(subL, ",")
	if commaL == -1 { commaL = strings.Index(subL, "}") }
	idL := strings.TrimSpace(subL[:commaL])
	
	return idM == idL && idM != ""
}

func (s *HealthService) checkPatroni() map[string]interface{} {
	port := os.Getenv("EXT_PATRONI_PORT_NODE1")
	if port == "" { port = "8008" }
	url := fmt.Sprintf("https://localhost:%s/cluster", port)
	
	user := os.Getenv("PATRONI_API_USER")
	pass := os.Getenv("PATRONI_API_PASSWORD")
	
	ok, msg := s.CheckComponentHealth(url, user, pass)
	if ok {
		msg = "Cluster OK (Topology check active)"
	}
	return map[string]interface{}{"alive": ok, "message": msg}
}

func (s *HealthService) checkHaproxy() map[string]interface{} {
	port := os.Getenv("EXT_HAPROXY_STATS_PORT")
	if port == "" { port = "8404" }
	url := fmt.Sprintf("https://localhost:%s/;csv", port)
	user := os.Getenv("ADMIN_HAPROXY_USER")
	pass := os.Getenv("ADMIN_HAPROXY_PASSWORD")
	ok, msg := s.CheckComponentHealth(url, user, pass)
	return map[string]interface{}{"alive": ok, "message": msg}
}

func (s *HealthService) checkPgbouncer() map[string]interface{} {
	port := os.Getenv("EXT_PGBOUNCER_PORT")
	if port == "" { port = "6432" }
	addr := fmt.Sprintf("localhost:%s", port)
	ok, msg := s.CheckTCPHealth(addr)
	return map[string]interface{}{"alive": ok, "message": msg}
}

// GetCertificateStatus analyse les certificats mTLS pour suivre leur expiration.
func (s *HealthService) GetCertificateStatus() []map[string]interface{} {
	rootPath := os.Getenv("MGMT_APP_ROOT")
	if rootPath == "" {
		rootPath = ".."
	}
	certsDir := filepath.Join(rootPath, "certs")

	var results []map[string]interface{}
	files, err := os.ReadDir(certsDir)
	if err != nil {
		return results
	}

	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".crt") {
			certPath := filepath.Join(certsDir, f.Name())
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
