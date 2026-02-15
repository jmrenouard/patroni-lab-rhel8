package services

import (
	"sync"
	"time"
)

// MetricPoint représente un point de donnée dans le temps.
type MetricPoint struct {
	Timestamp time.Time `json:"t"`
	Value     float64   `json:"v"`
}

// MetricsHistory stocke l'historique des métriques pour un composant.
type MetricsHistory struct {
	CPU []MetricPoint `json:"cpu"`
	RAM []MetricPoint `json:"ram"`
}

// MetricsService gère la collecte et le stockage temporaire des métriques.
type MetricsService struct {
	history map[string]*MetricsHistory
	mu      sync.RWMutex
	maxSize int
}

// NewMetricsService initialise le service de métriques.
func NewMetricsService(maxSize int) *MetricsService {
	return &MetricsService{
		history: make(map[string]*MetricsHistory),
		maxSize: maxSize,
	}
}

// AddMetric ajoute un point de donnée à l'historique d'un composant.
func (s *MetricsService) AddMetric(name string, metricType string, value float64) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.history[name]; !ok {
		s.history[name] = &MetricsHistory{
			CPU: []MetricPoint{},
			RAM: []MetricPoint{},
		}
	}

	var target *[]MetricPoint
	switch metricType {
	case "cpu":
		target = &s.history[name].CPU
	case "ram":
		target = &s.history[name].RAM
	default:
		return
	}

	*target = append(*target, MetricPoint{Timestamp: time.Now(), Value: value})
	if len(*target) > s.maxSize {
		*target = (*target)[1:]
	}
}

// GetHistory retourne l'historique complet pour tous les composants.
func (s *MetricsService) GetHistory() map[string]*MetricsHistory {
	s.mu.RLock()
	defer s.mu.RUnlock()
	
	// Deep copy pour éviter les problèmes de concurrence lors de la sérialisation JSON
	copy := make(map[string]*MetricsHistory)
	for k, v := range s.history {
		copy[k] = &MetricsHistory{
			CPU: append([]MetricPoint{}, v.CPU...),
			RAM: append([]MetricPoint{}, v.RAM...),
		}
	}
	return copy
}
