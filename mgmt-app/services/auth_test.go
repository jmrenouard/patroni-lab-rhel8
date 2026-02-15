package services

import (
	"os"
	"testing"
)

func TestAuthService(t *testing.T) {
	// Setup temporary DB
	os.Setenv("MGMT_APP_ROOT", t.TempDir())
	
	s, err := NewAuthService()
	if err != nil {
		t.Fatalf("Failed to create AuthService: %v", err)
	}
	defer s.Close()
	
	tests := []struct {
		user string
		pass string
		wantRole string
		wantOk   bool
	}{
		{"root", "rootpass", "admin", true},
		{"guest", "guestpass", "reader", true},
		{"invalid", "invalid", "", false},
	}
	
	for _, tt := range tests {
		role, ok := s.Authenticate(tt.user, tt.pass)
		if ok != tt.wantOk || role != tt.wantRole {
			t.Errorf("Auth(%s, %s) = (%s, %v); want (%s, %v)", tt.user, tt.pass, role, ok, tt.wantRole, tt.wantOk)
		}
	}
}
