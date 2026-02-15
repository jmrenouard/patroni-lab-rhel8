package services

import (
	"testing"
)

func TestIsEtcdLeader(t *testing.T) {
	s := &HealthService{}
	
	tests := []struct {
		json     string
		isLeader bool
	}{
		{`{"isLeader":true}`, true},
		{`{"IS_LEADER":true}`, true},
		{`{"isLeader":false}`, false},
		{`{"something": else}`, false},
	}
	
	for _, tt := range tests {
		got := s.isEtcdLeader(tt.json)
		if got != tt.isLeader {
			t.Errorf("isEtcdLeader(%s) = %v; want %v", tt.json, got, tt.isLeader)
		}
	}
}

func TestCheckComponentHealth(t *testing.T) {
	// Ce test nécessiterait un serveur HTTP de mock, mais on peut tester la structure
	s := NewHealthService(nil, nil)
	ok, _ := s.CheckComponentHealth("http://invalid.url", "", "")
	if ok {
		t.Error("CheckComponentHealth should fail for invalid URL")
	}
}
