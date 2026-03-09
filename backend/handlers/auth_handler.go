// Package handlers contains the HTTP request handlers (controllers) for the API.
// Handlers receive HTTP requests, validate input, call the appropriate service,
// and return JSON responses to the client.
package handlers

import (
	"backend/config"
	"backend/middlewares" // Custom middleware package – used here to extract user ID from JWT context
	"backend/services"    // Business logic layer – AuthService handles login, register, token operations
	"encoding/json"
	"fmt"
	"io"
	"net/http" // Standard Go HTTP library – provides status codes like 200, 400, 401
	"net/url"
	"strings"

	"github.com/gin-gonic/gin" // Gin is the web framework used for routing and request handling
)

// AuthHandler is the struct that groups all authentication-related HTTP handlers.
// It holds a reference to AuthService so each handler can call business logic methods.
type AuthHandler struct {
	authService *services.AuthService // Dependency injection: the service that handles auth logic
	cfg         *config.Config        // App config for OAuth client IDs and secrets
}

// NewAuthHandler is a constructor function that creates a new AuthHandler.
// It accepts an AuthService and config, and returns a pointer to the initialized AuthHandler.
func NewAuthHandler(authService *services.AuthService, cfg *config.Config) *AuthHandler {
	return &AuthHandler{authService: authService, cfg: cfg}
}

// LoginRequest defines the expected JSON body for the login endpoint.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"` // User's email – must be present and valid format
	Password string `json:"password" binding:"required"`    // User's password – must be present
}

// RegisterRequest defines the expected JSON body for the registration endpoint.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`    // Email for the new account
	Password string `json:"password" binding:"required,min=6"` // Password – minimum 6 characters for security
	Name     string `json:"name" binding:"required"`           // Display name for the user
}

// Login handles POST /api/v1/auth/login
// It authenticates a user with email and password, and returns JWT tokens on success.
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, token, err := h.authService.Login(req.Email, req.Password)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  token.AccessToken,
		"refresh_token": token.RefreshToken,
		"user_id":       user.ID,
		"email":         user.Email,
		"name":          user.Name,
	})

}

// Register handles POST /api/v1/auth/register
func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	user, token, err := h.authService.Register(req.Email, req.Password, req.Name)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message":       "User created successfully",
		"access_token":  token.AccessToken,
		"refresh_token": token.RefreshToken,
		"user_id":       user.ID,
		"email":         user.Email,
		"name":          user.Name,
	})

}

// Logout handles POST /api/v1/auth/logout
func (h *AuthHandler) Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// RefreshTokenRequest defines the expected JSON body for the token refresh endpoint.
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// RefreshToken handles POST /api/v1/auth/refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req RefreshTokenRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	token, err := h.authService.RefreshAccessToken(req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token": token,
	})
}

// VerifyToken handles GET /api/v1/auth/verify
func (h *AuthHandler) VerifyToken(c *gin.Context) {
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "unauthorized",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Token is valid",
		"user_id": userID.String(),
	})
}

// GoogleAuthRequest defines the expected JSON body for Google OAuth.
type GoogleAuthRequest struct {
	IDToken string `json:"id_token" binding:"required"` // Google ID token from the mobile client
}

// GoogleAuth handles POST /api/v1/auth/google
// It receives a Google ID token from the Flutter client, verifies it with
// Google's tokeninfo API, and creates or finds the corresponding user.
func (h *AuthHandler) GoogleAuth(c *gin.Context) {
	var req GoogleAuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing id_token"})
		return
	}

	// Verify the ID token with Google's tokeninfo endpoint
	resp, err := http.Get(fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", req.IDToken))
	if err != nil || resp.StatusCode != 200 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid Google ID token"})
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var tokenInfo map[string]interface{}
	if err := json.Unmarshal(body, &tokenInfo); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse Google token"})
		return
	}

	email, _ := tokenInfo["email"].(string)
	name, _ := tokenInfo["name"].(string)
	if email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Google token missing email"})
		return
	}
	if name == "" {
		name = email // Fallback to email as name
	}

	// Find or create the user with OAuth provider "google"
	user, token, err := h.authService.FindOrCreateOAuthUser(email, name, "google")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  token.AccessToken,
		"refresh_token": token.RefreshToken,
		"user_id":       user.ID,
		"email":         user.Email,
		"name":          user.Name,
	})
}

// GitHubAuthRequest defines the expected JSON body for GitHub OAuth.
type GitHubAuthRequest struct {
	Code  string `json:"code" binding:"required"` // Authorization code from GitHub OAuth redirect
	State string `json:"state"`                   // CSRF state parameter for validation
}

// GitHubAuth handles POST /api/v1/auth/github
// It receives a GitHub authorization code, exchanges it for an access token
// with GitHub's API, fetches the user's profile, and creates or finds the user.
// CSRF protection: validates the state parameter matches the expected value.
func (h *AuthHandler) GitHubAuth(c *gin.Context) {
	var req GitHubAuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing authorization code"})
		return
	}

	// CSRF Protection: validate the state parameter
	if h.cfg.GitHubOAuthState != "" && req.State != "" && req.State != h.cfg.GitHubOAuthState {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid OAuth state – possible CSRF attack"})
		return
	}

	// Exchange the authorization code for an access token
	tokenURL := "https://github.com/login/oauth/access_token"
	formData := url.Values{
		"client_id":     {h.cfg.GitHubClientID},
		"client_secret": {h.cfg.GitHubClientSecret},
		"code":          {req.Code},
	}

	tokenReq, _ := http.NewRequest("POST", tokenURL, nil)
	tokenReq.URL.RawQuery = formData.Encode()
	tokenReq.Header.Set("Accept", "application/json")

	client := &http.Client{}
	tokenResp, err := client.Do(tokenReq)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exchange GitHub code"})
		return
	}
	defer tokenResp.Body.Close()

	tokenBody, _ := io.ReadAll(tokenResp.Body)
	var tokenData map[string]interface{}
	if err := json.Unmarshal(tokenBody, &tokenData); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse GitHub response"})
		return
	}

	ghToken, ok := tokenData["access_token"].(string)
	if !ok || ghToken == "" {
		errMsg, _ := tokenData["error_description"].(string)
		if errMsg == "" {
			errMsg = "Failed to get GitHub access token"
		}
		c.JSON(http.StatusUnauthorized, gin.H{"error": errMsg})
		return
	}

	// Fetch the GitHub user's profile using the access token
	userReq, _ := http.NewRequest("GET", "https://api.github.com/user", nil)
	userReq.Header.Set("Authorization", "token "+ghToken)
	userReq.Header.Set("Accept", "application/json")

	userResp, err := client.Do(userReq)
	if err != nil || userResp.StatusCode != 200 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch GitHub profile"})
		return
	}
	defer userResp.Body.Close()

	userBody, _ := io.ReadAll(userResp.Body)
	var ghUser map[string]interface{}
	json.Unmarshal(userBody, &ghUser)

	// Extract email — GitHub may not return email in profile, fetch from /user/emails
	email, _ := ghUser["email"].(string)
	if email == "" {
		emailReq, _ := http.NewRequest("GET", "https://api.github.com/user/emails", nil)
		emailReq.Header.Set("Authorization", "token "+ghToken)
		emailReq.Header.Set("Accept", "application/json")
		emailResp, err := client.Do(emailReq)
		if err == nil && emailResp.StatusCode == 200 {
			defer emailResp.Body.Close()
			emailBody, _ := io.ReadAll(emailResp.Body)
			var emails []map[string]interface{}
			json.Unmarshal(emailBody, &emails)
			for _, e := range emails {
				if primary, ok := e["primary"].(bool); ok && primary {
					email, _ = e["email"].(string)
					break
				}
			}
		}
	}

	if email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not retrieve email from GitHub"})
		return
	}

	name, _ := ghUser["name"].(string)
	if name == "" {
		name, _ = ghUser["login"].(string)
	}

	// Find or create user with "github" provider
	user, token, err := h.authService.FindOrCreateOAuthUser(email, name, "github")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  token.AccessToken,
		"refresh_token": token.RefreshToken,
		"user_id":       user.ID,
		"email":         user.Email,
		"name":          user.Name,
	})
}

// GitHubCallback handles GET /api/v1/auth/github/callback
// This is the OAuth redirect endpoint that GitHub calls after the user authorizes.
// It performs the same code→token→user flow as GitHubAuth, but redirects the
// result to the Android app via a deep link (tracely://auth/github/callback).
func (h *AuthHandler) GitHubCallback(c *gin.Context) {
	code := c.Query("code")
	if code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing authorization code"})
		return
	}

	// Exchange the authorization code for a GitHub access token
	tokenURL := "https://github.com/login/oauth/access_token"
	formData := url.Values{
		"client_id":     {h.cfg.GitHubClientID},
		"client_secret": {h.cfg.GitHubClientSecret},
		"code":          {code},
	}

	tokenReq, _ := http.NewRequest("POST", tokenURL, nil)
	tokenReq.URL.RawQuery = formData.Encode()
	tokenReq.Header.Set("Accept", "application/json")

	client := &http.Client{}
	tokenResp, err := client.Do(tokenReq)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exchange GitHub code"})
		return
	}
	defer tokenResp.Body.Close()

	tokenBody, _ := io.ReadAll(tokenResp.Body)
	var tokenData map[string]interface{}
	if err := json.Unmarshal(tokenBody, &tokenData); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse GitHub response"})
		return
	}

	ghToken, ok := tokenData["access_token"].(string)
	if !ok || ghToken == "" {
		errMsg, _ := tokenData["error_description"].(string)
		if errMsg == "" {
			errMsg = "Failed to get GitHub access token"
		}
		c.JSON(http.StatusUnauthorized, gin.H{"error": errMsg})
		return
	}

	// Fetch the GitHub user's profile
	userReq, _ := http.NewRequest("GET", "https://api.github.com/user", nil)
	userReq.Header.Set("Authorization", "token "+ghToken)
	userReq.Header.Set("Accept", "application/json")

	userResp, err := client.Do(userReq)
	if err != nil || userResp.StatusCode != 200 {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch GitHub profile"})
		return
	}
	defer userResp.Body.Close()

	userBody, _ := io.ReadAll(userResp.Body)
	var ghUser map[string]interface{}
	json.Unmarshal(userBody, &ghUser)

	// Extract email
	email, _ := ghUser["email"].(string)
	if email == "" {
		emailReq, _ := http.NewRequest("GET", "https://api.github.com/user/emails", nil)
		emailReq.Header.Set("Authorization", "token "+ghToken)
		emailReq.Header.Set("Accept", "application/json")
		emailResp, err := client.Do(emailReq)
		if err == nil && emailResp.StatusCode == 200 {
			defer emailResp.Body.Close()
			emailBody, _ := io.ReadAll(emailResp.Body)
			var emails []map[string]interface{}
			json.Unmarshal(emailBody, &emails)
			for _, e := range emails {
				if primary, ok := e["primary"].(bool); ok && primary {
					email, _ = e["email"].(string)
					break
				}
			}
		}
	}

	if email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not retrieve email from GitHub"})
		return
	}

	name, _ := ghUser["name"].(string)
	if name == "" {
		name, _ = ghUser["login"].(string)
	}

	// Find or create user
	user, token, err := h.authService.FindOrCreateOAuthUser(email, name, "github")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Redirect with tokens — detect platform:
	// If the request includes a "redirect_uri" query parameter pointing to
	// a web URL, redirect there. Otherwise fall back to the Android deep link.
	redirectURI := c.Query("redirect_uri")
	if redirectURI == "" {
		// Default to the first configured CORS origin (the web app)
		if len(h.cfg.CORSOrigins) > 0 && h.cfg.CORSOrigins[0] != "" {
			redirectURI = strings.TrimSpace(h.cfg.CORSOrigins[0])
		}
	}

	if redirectURI != "" && (strings.HasPrefix(redirectURI, "http://") || strings.HasPrefix(redirectURI, "https://")) {
		// Web redirect: pass tokens as hash fragment so JS can read them
		webRedirect := fmt.Sprintf(
			"%s/#/auth/callback?access_token=%s&refresh_token=%s&user_id=%s&email=%s",
			strings.TrimRight(redirectURI, "/"),
			url.QueryEscape(token.AccessToken),
			url.QueryEscape(token.RefreshToken),
			url.QueryEscape(user.ID.String()),
			url.QueryEscape(user.Email),
		)
		c.Redirect(http.StatusTemporaryRedirect, webRedirect)
		return
	}

	// Native app deep link fallback
	redirectURL := fmt.Sprintf(
		"tracely://auth/github/callback?access_token=%s&refresh_token=%s&user_id=%s&email=%s",
		url.QueryEscape(token.AccessToken),
		url.QueryEscape(token.RefreshToken),
		url.QueryEscape(user.ID.String()),
		url.QueryEscape(user.Email),
	)
	c.Redirect(http.StatusTemporaryRedirect, redirectURL)
}
