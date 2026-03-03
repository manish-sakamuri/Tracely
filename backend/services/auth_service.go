// Package services contains the business logic layer of the application.
// This file implements the AuthService, which handles all authentication operations:
// user registration, login, JWT token generation/validation, and token refresh.
// It uses bcrypt for password hashing and JWT (JSON Web Tokens) for stateless authentication.
package services

import (
	"errors" // Standard Go package for creating error messages
	"time"   // Standard Go package for time operations (token expiration, etc.)

	"backend/config" // Application configuration – holds the JWT secret key
	"backend/models" // Database models – User, RefreshToken structs mapped to DB tables

	"github.com/golang-jwt/jwt/v5" // JWT library – creates and validates JSON Web Tokens
	"github.com/google/uuid"       // UUID library – generates unique identifiers
	"golang.org/x/crypto/bcrypt"   // Bcrypt library – securely hashes passwords
	"gorm.io/gorm"                 // GORM – Object-Relational Mapping (ORM) for database operations
)

// TokenPair holds both the access token and refresh token returned after login/register.
// Access tokens are short-lived (1 hour) for API requests.
// Refresh tokens are long-lived (30 days) for getting new access tokens.
type TokenPair struct {
	AccessToken  string // Short-lived JWT – sent with every API request in the Authorization header
	RefreshToken string // Long-lived token – stored securely, used to get new access tokens
}

// AuthService is the struct that holds dependencies needed for authentication logic.
// It follows the service pattern – handlers call these methods to perform auth operations.
type AuthService struct {
	db     *gorm.DB       // Database connection – used to query and store users, tokens
	config *config.Config // App configuration – contains the JWT secret key for signing tokens
}

// JWTClaims defines the custom data embedded inside each JWT token.
// When we create a token, we store the user's ID and email in the claims.
// When we validate a token, we extract these claims to identify the user.
type JWTClaims struct {
	UserID               string `json:"user_id"` // The user's unique ID stored inside the JWT
	Email                string `json:"email"`   // The user's email stored inside the JWT
	jwt.RegisteredClaims        // Standard JWT fields: expiration time, issued-at, etc.
}

// NewAuthService is a constructor function that creates an AuthService instance.
// It receives the database connection and config via dependency injection.
func NewAuthService(db *gorm.DB, cfg *config.Config) *AuthService {
	return &AuthService{
		db:     db,  // Store the database connection for later use
		config: cfg, // Store the config (contains JWT secret)
	}
}

// Register creates a new user account in the system.
// Steps: (1) Check if email already exists, (2) Hash the password, (3) Save user to DB,
// (4) Generate JWT tokens, (5) Create a default workspace, (6) Create default settings.
// Returns the new user, a token pair, and any error that occurred.
func (s *AuthService) Register(email, password, name string) (*models.User, *TokenPair, error) {
	// Step 1: Check if a user with this email already exists in the database
	var existingUser models.User
	if err := s.db.Where("email = ?", email).First(&existingUser).Error; err == nil {
		// If no error, the user was found – email is already taken
		return nil, nil, errors.New("email already exists")
	}

	// Step 2: Hash the password using bcrypt.
	// bcrypt adds a random "salt" and runs multiple rounds of hashing,
	// making it extremely difficult to reverse-engineer the original password.
	// DefaultCost = 10 rounds of hashing.
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err // Return error if hashing fails (very rare)
	}

	// Step 3: Create the user model with the hashed password (never store plain text passwords!)
	user := models.User{
		Email:    email,
		Password: string(hashedPassword), // Store the bcrypt hash, NOT the original password
		Name:     name,
	}

	// Save the new user to the database using GORM's Create method
	if err := s.db.Create(&user).Error; err != nil {
		return nil, nil, err // Return error if DB insert fails (e.g., constraint violation)
	}

	// Step 4a: Generate a short-lived JWT access token (expires in 1 hour)
	accessToken, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, nil, err
	}

	// Step 4b: Generate a long-lived refresh token (expires in 30 days)
	refreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, nil, err
	}

	// Step 5: Create a default workspace for the new user.
	// Every user gets their own workspace to start organizing their API requests.
	workspace := models.Workspace{
		Name:        "Default Workspace",
		Description: "Your default workspace",
		OwnerID:     user.ID, // The new user is the owner of this workspace
	}
	s.db.Create(&workspace) // Save workspace to database

	// Add the user as an "admin" member of the workspace (RBAC – Role-Based Access Control).
	// The "admin" role gives the user full control over this workspace.
	s.db.Create(&models.WorkspaceMember{
		WorkspaceID: workspace.ID,
		UserID:      user.ID,
		Role:        "admin", // RBAC role – can be "admin", "editor", or "viewer"
	})

	// Step 6: Create default user settings (theme, notification preferences, etc.)
	s.db.Create(&models.UserSettings{
		UserID: user.ID,
		Theme:  "light", // Default theme is "light" mode
	})

	// Return the user object and both tokens so the client is immediately logged in
	return &user, &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}

// Login authenticates a user with their email and password.
// Steps: (1) Find the user by email, (2) Verify the password, (3) Generate tokens.
// Returns the user, a token pair, and any error.
func (s *AuthService) Login(email, password string) (*models.User, *TokenPair, error) {
	// Step 1: Look up the user by email in the database
	var user models.User
	if err := s.db.Where("email = ?", email).First(&user).Error; err != nil {
		// User not found – return a generic "invalid credentials" message
		// (we don't reveal whether the email or password is wrong, for security)
		return nil, nil, errors.New("invalid credentials")
	}

	// Step 2: Compare the provided password against the stored bcrypt hash.
	// bcrypt.CompareHashAndPassword handles the salt and hashing internally.
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password)); err != nil {
		// Password doesn't match – return the same generic error message
		return nil, nil, errors.New("invalid credentials")
	}

	// Step 3a: Generate a new JWT access token for the authenticated user
	accessToken, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, nil, err
	}

	// Step 3b: Generate a new refresh token for the authenticated user
	refreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, nil, err
	}

	// Return the user and both tokens
	return &user, &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}

// GenerateToken creates a JWT access token for the given user.
// The token contains the user's ID and email, and expires after 1 hour.
// It is signed with the JWT secret key using HMAC-SHA256 algorithm.
func (s *AuthService) GenerateToken(userID uuid.UUID, email string) (string, error) {
	// Set the token to expire 1 hour from now
	expirationTime := time.Now().Add(1 * time.Hour)

	// Build the JWT claims – the data embedded inside the token
	claims := &JWTClaims{
		UserID: userID.String(), // Convert UUID to string for JSON encoding
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime), // When the token expires
			IssuedAt:  jwt.NewNumericDate(time.Now()),     // When the token was created
		},
	}

	// Create a new unsigned token with the HS256 signing method and our claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Sign the token with our secret key – this produces the final JWT string.
	// The secret key is stored in the config and should never be exposed publicly.
	tokenString, err := token.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return "", err // Return error if signing fails
	}

	return tokenString, nil // Return the signed JWT string
}

// ValidateToken parses and validates a JWT access token.
// It checks that the token is properly signed and hasn't expired.
// Returns the claims (user ID, email) if valid, or an error if invalid.
func (s *AuthService) ValidateToken(tokenString string) (*JWTClaims, error) {
	claims := &JWTClaims{} // Empty claims struct to be populated by the parser

	// Parse the JWT string, validate the signature using our secret key,
	// and populate the claims struct with the decoded data.
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// This callback provides the secret key to verify the token's signature
		return []byte(s.config.JWTSecret), nil
	})

	if err != nil {
		return nil, err // Return error if parsing/validation fails (expired, malformed, etc.)
	}

	// Additional check: ensure the token object itself is marked as valid
	if !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil // Return the validated claims
}

// GenerateRefreshToken creates a long-lived refresh token for the given user.
// Unlike JWT access tokens, refresh tokens are random UUIDs stored in the database.
// They expire after 30 days and can be revoked (invalidated) at any time.
func (s *AuthService) GenerateRefreshToken(userID uuid.UUID) (string, error) {
	// Generate a random UUID string as the refresh token value
	refreshToken := uuid.New().String()

	// Set expiration to 30 days from now (720 hours)
	expiresAt := time.Now().Add(720 * time.Hour)

	// Create the refresh token database record
	token := models.RefreshToken{
		UserID:    userID,       // Link the token to the user who owns it
		Token:     refreshToken, // The random token string
		ExpiresAt: expiresAt,    // When this token expires
	}

	// Save the token to the database – this allows us to validate and revoke it later
	if err := s.db.Create(&token).Error; err != nil {
		return "", err
	}

	return refreshToken, nil // Return the token string to be sent to the client
}

// RefreshAccessToken generates a new access token using a valid refresh token.
// This is used when the client's access token has expired but they still have a valid refresh token.
// Steps: (1) Find the refresh token in DB, (2) Check it's not expired or revoked,
// (3) Look up the user, (4) Generate a new access token.
func (s *AuthService) RefreshAccessToken(refreshToken string) (string, error) {
	// Step 1: Look up the refresh token in the database.
	// Only find tokens that haven't been revoked (revoked_at IS NULL).
	var token models.RefreshToken
	if err := s.db.Where("token = ? AND revoked_at IS NULL", refreshToken).First(&token).Error; err != nil {
		return "", errors.New("invalid refresh token") // Token not found or already revoked
	}

	// Step 2: Check if the refresh token has expired
	if time.Now().After(token.ExpiresAt) {
		return "", errors.New("refresh token expired")
	}

	// Step 3: Look up the user associated with this refresh token
	var user models.User
	if err := s.db.First(&user, token.UserID).Error; err != nil {
		return "", err // User not found (shouldn't happen, but defensive coding)
	}

	// Step 4: Generate a new access token for the user
	accessToken, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return "", err
	}

	return accessToken, nil // Return the new access token
}

// RevokeRefreshToken invalidates a refresh token so it can no longer be used.
// This is typically called during logout to prevent the token from being reused.
// Instead of deleting the token, we set its "revoked_at" timestamp (soft revocation).
func (s *AuthService) RevokeRefreshToken(refreshToken string) error {
	now := time.Now()
	// Update the token's revoked_at field to the current time
	return s.db.Model(&models.RefreshToken{}).
		Where("token = ?", refreshToken).
		Update("revoked_at", now).Error
}

// FindOrCreateOAuthUser locates a user by email or creates one for OAuth sign-in.
// For new users, a random bcrypt hash is used as the password (since OAuth users
// don't log in with passwords). The auth_provider field records "google" or "github".
func (s *AuthService) FindOrCreateOAuthUser(email, name, provider string) (*models.User, *TokenPair, error) {
	var user models.User
	err := s.db.Where("email = ?", email).First(&user).Error
	if err != nil {
		// User doesn't exist — create a new account
		// Generate a random password hash so the password field is never empty
		randomHash, _ := bcrypt.GenerateFromPassword([]byte(uuid.New().String()), bcrypt.DefaultCost)
		user = models.User{
			Email:        email,
			Name:         name,
			Password:     string(randomHash),
			AuthProvider: provider,
		}
		if err := s.db.Create(&user).Error; err != nil {
			return nil, nil, errors.New("failed to create OAuth user: " + err.Error())
		}

		// Create default workspace for the new user
		workspace := models.Workspace{
			Name:        "My Workspace",
			Description: "Default workspace",
			OwnerID:     user.ID,
		}
		s.db.Create(&workspace)

		// Create default user settings
		settings := models.UserSettings{
			UserID: user.ID,
			Theme:  "dark",
		}
		s.db.Create(&settings)
	}

	// Generate JWT tokens for the user
	accessToken, err := s.GenerateToken(user.ID, user.Email)
	if err != nil {
		return nil, nil, err
	}
	refreshToken, err := s.GenerateRefreshToken(user.ID)
	if err != nil {
		return nil, nil, err
	}

	return &user, &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}
