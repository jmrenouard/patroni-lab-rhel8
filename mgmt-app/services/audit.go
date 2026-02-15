package services

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

// AuditEntry représente une ligne dans le journal d'audit.
type AuditEntry struct {
	Timestamp time.Time `json:"timestamp"`
	User      string    `json:"user"`
	Action    string    `json:"action"`
	Target    string    `json:"target"`
	Details   string    `json:"details"`
	Result    string    `json:"result"`
}

// AuditService gère la persistance et la consultation des logs d'audit.
type AuditService struct {
	filePath string
	mu       sync.RWMutex
}

// NewAuditService initialise le service d'audit avec un fichier de stockage.
func NewAuditService(filePath string) *AuditService {
	return &AuditService{
		filePath: filePath,
	}
}

// LogAction enregistre une action administrative.
func (s *AuditService) LogAction(user, action, target, details, result string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	entry := AuditEntry{
		Timestamp: time.Now(),
		User:      user,
		Action:    action,
		Target:    target,
		Details:   details,
		Result:    result,
	}

	entries, _ := s.readAll()
	entries = append(entries, entry)

	// On garde les 1000 dernières entrées pour éviter une croissance infinie
	if len(entries) > 1000 {
		entries = entries[len(entries)-1000:]
	}

	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(s.filePath, data, 0644)
}

// GetEntries retourne la liste des entrées d'audit.
func (s *AuditService) GetEntries() ([]AuditEntry, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.readAll()
}

func (s *AuditService) readAll() ([]AuditEntry, error) {
	data, err := os.ReadFile(s.filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return []AuditEntry{}, nil
		}
		return nil, err
	}

	var entries []AuditEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return []AuditEntry{}, fmt.Errorf("erreur de lecture audit: %v", err)
	}

	return entries, nil
}
