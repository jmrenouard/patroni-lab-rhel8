package services

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

// User représente un utilisateur avec son rôle.
type User struct {
	Username string
	Role     string
}

// AuthService gère l'authentification et les utilisateurs via SQLite.
type AuthService struct {
	db *sql.DB
}

// NewAuthService initialise la base de données SQLite et crée la table users si nécessaire.
func NewAuthService() (*AuthService, error) {
	rootPath := os.Getenv("MGMT_APP_ROOT")
	if rootPath == "" {
		rootPath = "."
	}
	dbPath := filepath.Join(rootPath, "mgmt.db")

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("erreur ouverture SQLite: %v", err)
	}

	// Création de la table des utilisateurs avec rôle
	createTable := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE,
		password TEXT,
		role TEXT DEFAULT 'reader'
	);`
	_, err = db.Exec(createTable)
	if err != nil {
		return nil, fmt.Errorf("erreur création table users: %v", err)
	}

	// Mise à jour schéma pour les bases existantes (ajout colonne role si absente)
	_, _ = db.Exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'reader'")

	// Insertion des utilisateurs par défaut si absents
	// root -> admin
	// guest -> reader
	_, _ = db.Exec("INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)", "root", "rootpass", "admin")
	_, _ = db.Exec("INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)", "guest", "guestpass", "reader")

	return &AuthService{db: db}, nil
}

// Authenticate vérifie les identifiants et retourne le rôle.
func (s *AuthService) Authenticate(username, password string) (string, bool) {
	var storedPass, role string
	err := s.db.QueryRow("SELECT password, role FROM users WHERE username = ?", username).Scan(&storedPass, &role)
	if err != nil {
		return "", false
	}
	if storedPass == password {
		return role, true
	}
	return "", false
}

// Close ferme la connexion à la base de données.
func (s *AuthService) Close() error {
	return s.db.Close()
}
