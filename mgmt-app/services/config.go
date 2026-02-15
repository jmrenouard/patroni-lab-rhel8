package services

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

// ConfigService gère la configuration dynamique de l'application (IPs, Ports, Mode).
type ConfigService struct {
	db *sql.DB
}

// PlatformConfig représente la configuration de la plateforme.
type PlatformConfig struct {
	Mode          string `json:"mode"` // "docker" ou "network"
	EtcdIP        string `json:"etcd_ip"`
	PatroniIP     string `json:"patroni_ip"`
	HAProxyIP     string `json:"haproxy_ip"`
	PgBouncerIP   string `json:"pgbouncer_ip"`
	EtcdPort      string `json:"etcd_port"`
	PatroniPort   string `json:"patroni_port"`
	HAProxyPort   string `json:"haproxy_port"`
	PgBouncerPort string `json:"pgbouncer_port"`
}

// NewConfigService initialise le service de configuration.
func NewConfigService() (*ConfigService, error) {
	rootPath := os.Getenv("MGMT_APP_ROOT")
	if rootPath == "" {
		rootPath = "."
	}
	dbPath := filepath.Join(rootPath, "mgmt.db")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("erreur ouverture SQLite (config): %v", err)
	}

	// Création de la table des réglages
	createTable := `
	CREATE TABLE IF NOT EXISTS settings (
		key TEXT PRIMARY KEY,
		value TEXT
	);`
	_, err = db.Exec(createTable)
	if err != nil {
		return nil, fmt.Errorf("erreur création table settings: %v", err)
	}

	// Valeurs par défaut
	defaults := map[string]string{
		"mode":           "docker",
		"etcd_ip":        "localhost",
		"patroni_ip":     "localhost",
		"haproxy_ip":     "localhost",
		"pgbouncer_ip":   "localhost",
		"etcd_port":      "2379",
		"patroni_port":   "8008",
		"haproxy_port":   "8404",
		"pgbouncer_port": "6432",
	}

	for k, v := range defaults {
		_, _ = db.Exec("INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)", k, v)
	}

	return &ConfigService{db: db}, nil
}

// GetConfig récupère la configuration complète.
func (s *ConfigService) GetConfig() (PlatformConfig, error) {
	var cfg PlatformConfig
	rows, err := s.db.Query("SELECT key, value FROM settings")
	if err != nil {
		return cfg, err
	}
	defer rows.Close()

	for rows.Next() {
		var key, val string
		if err := rows.Scan(&key, &val); err != nil {
			return cfg, err
		}
		switch key {
		case "mode": cfg.Mode = val
		case "etcd_ip": cfg.EtcdIP = val
		case "patroni_ip": cfg.PatroniIP = val
		case "haproxy_ip": cfg.HAProxyIP = val
		case "pgbouncer_ip": cfg.PgBouncerIP = val
		case "etcd_port": cfg.EtcdPort = val
		case "patroni_port": cfg.PatroniPort = val
		case "haproxy_port": cfg.HAProxyPort = val
		case "pgbouncer_port": cfg.PgBouncerPort = val
		}
	}
	return cfg, nil
}

// UpdateConfig met à jour un ou plusieurs réglages.
func (s *ConfigService) UpdateConfig(cfg PlatformConfig) error {
	settings := map[string]string{
		"mode":           cfg.Mode,
		"etcd_ip":        cfg.EtcdIP,
		"patroni_ip":     cfg.PatroniIP,
		"haproxy_ip":     cfg.HAProxyIP,
		"pgbouncer_ip":   cfg.PgBouncerIP,
		"etcd_port":      cfg.EtcdPort,
		"patroni_port":   cfg.PatroniPort,
		"haproxy_port":   cfg.HAProxyPort,
		"pgbouncer_port": cfg.PgBouncerPort,
	}

	tx, err := s.db.Begin()
	if err != nil {
		return err
	}

	for k, v := range settings {
		_, err := tx.Exec("UPDATE settings SET value = ? WHERE key = ?", v, k)
		if err != nil {
			tx.Rollback()
			return err
		}
	}

	return tx.Commit()
}
