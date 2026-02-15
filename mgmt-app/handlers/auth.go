package handlers

import (
	"encoding/json"
	"net/http"
	"patroni-mgmt-app/services"
	"time"
)

// AuthHandler gère les requêtes de connexion et déconnexion.
type AuthHandler struct {
	Auth *services.AuthService
}

// Login gère la soumission du formulaire de connexion.
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Méthode non autorisée", http.StatusMethodNotAllowed)
		return
	}

	var credentials struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}

	if err := json.NewDecoder(r.Body).Decode(&credentials); err != nil {
		http.Error(w, "Requête invalide", http.StatusBadRequest)
		return
	}

	role, ok := h.Auth.Authenticate(credentials.Username, credentials.Password)
	if ok {
		// Création d'un cookie de session simple incluant le rôle
		cookie := &http.Cookie{
			Name:     "session_token",
			Value:    "session:" + role,
			Path:     "/",
			HttpOnly: true,
			Expires:  time.Now().Add(24 * time.Hour),
		}
		http.SetCookie(w, cookie)
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"result": "success", "role": role})
	} else {
		http.Error(w, "Identifiants invalides", http.StatusUnauthorized)
	}
}

// Logout supprime le cookie de session.
func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	cookie := &http.Cookie{
		Name:     "session_token",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		MaxAge:   -1,
	}
	http.SetCookie(w, cookie)
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

// AuthMiddleware protège l'accès aux routes privées.
func (h *AuthHandler) AuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Pas d'auth pour /login, /api/login, et /static
		if r.URL.Path == "/login" || r.URL.Path == "/api/login" || 
		   (len(r.URL.Path) > 8 && r.URL.Path[:8] == "/static/") {
			next.ServeHTTP(w, r)
			return
		}

		cookie, err := r.Cookie("session_token")
		if err != nil || (cookie.Value != "session:admin" && cookie.Value != "session:reader") {
			// Si c'est une requête API, on renvoie 401
			if len(r.URL.Path) > 5 && r.URL.Path[:5] == "/api/" {
				http.Error(w, "Non autorisé", http.StatusUnauthorized)
				return
			}
			// Sinon redirection vers login
			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// AdminMiddleware restreint l'accès aux administrateurs uniquement.
func (h *AuthHandler) AdminMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("session_token")
		if err != nil || cookie.Value != "session:admin" {
			http.Error(w, "Accès refusé - Profil Administrateur requis", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
