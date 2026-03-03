// Package services – this file implements the SessionService which manages
// API session state (cookies, authentication tokens, variables) for workspace requests.
// Sessions allow users to save and reuse authentication state across multiple API calls,
// similar to how a browser maintains cookies across page visits.
package services

import (
	"encoding/json" // Standard Go package for JSON serialization/deserialization
	"net/http"      // Standard HTTP library – used to manipulate HTTP request objects
	"time"          // Standard time package – for timestamps

	"github.com/google/uuid" // UUID library – generates unique session identifiers
	"gorm.io/gorm"           // GORM – ORM for database operations
)

// Session represents an API session stored in the database.
// It captures the authentication state (cookies, tokens) so they can be reused
// across multiple API requests within a workspace.
type Session struct {
	ID          uuid.UUID `gorm:"type:uuid;primary_key"` // Unique session identifier (primary key)
	WorkspaceID uuid.UUID `gorm:"type:uuid;not null"`    // Which workspace this session belongs to
	Name        string    `gorm:"not null"`              // Human-readable session name (e.g., "Dev Auth Session")
	State       string    `gorm:"type:jsonb"`            // JSON blob storing cookies, tokens, and variables
	CreatedAt   time.Time // Timestamp when the session was created (auto-set by GORM)
	UpdatedAt   time.Time // Timestamp when the session was last updated (auto-set by GORM)
}

// SessionService is the struct that handles all session-related business logic.
// It uses the database to persist session state.
type SessionService struct {
	db *gorm.DB // Database connection for querying and storing sessions
}

// NewSessionService is a constructor that creates a new SessionService instance.
// It receives the database connection via dependency injection.
func NewSessionService(db *gorm.DB) *SessionService {
	return &SessionService{db: db}
}

// CaptureSession saves the current session state (cookies and tokens) to the database.
// This is called after a successful API request to store any cookies or auth tokens
// that were returned, so they can be automatically applied to future requests.
// Parameters:
//   - workspaceID: which workspace this session belongs to
//   - name: a human-readable label for this session
//   - cookies: key-value map of HTTP cookies to store
//   - tokens: key-value map of authentication tokens to store
func (s *SessionService) CaptureSession(workspaceID uuid.UUID, name string, cookies map[string]string, tokens map[string]string) (*Session, error) {
	// Build the state object combining cookies, tokens, and a timestamp
	state := map[string]interface{}{
		"cookies":     cookies,    // HTTP cookies to persist (e.g., session cookies)
		"tokens":      tokens,     // Auth tokens to persist (e.g., Bearer tokens)
		"captured_at": time.Now(), // When this session state was captured
	}

	// Serialize the state map to a JSON string for database storage
	stateJSON, _ := json.Marshal(state)

	// Create the session record with a new UUID and the serialized state
	session := Session{
		ID:          uuid.New(),        // Generate a unique ID for this session
		WorkspaceID: workspaceID,       // Link session to its workspace
		Name:        name,              // Store the human-readable name
		State:       string(stateJSON), // Store the JSON state as a string
	}

	// Save the session to the database
	if err := s.db.Create(&session).Error; err != nil {
		return nil, err // Return error if the database insert fails
	}

	return &session, nil // Return the created session
}

// GetSession retrieves a session's state from the database by its ID.
// It returns the deserialized state map containing cookies and tokens.
func (s *SessionService) GetSession(sessionID uuid.UUID) (map[string]interface{}, error) {
	var session Session
	// Look up the session by its primary key (ID)
	if err := s.db.First(&session, sessionID).Error; err != nil {
		return nil, err // Return error if session not found
	}

	// Deserialize the JSON state string back into a Go map
	var state map[string]interface{}
	json.Unmarshal([]byte(session.State), &state)

	return state, nil // Return the session state (cookies, tokens)
}

// ApplySession applies a saved session's state to an outgoing HTTP request.
// It reads the stored cookies and auth tokens from the database and adds them
// to the request headers, so the API call is authenticated automatically.
// This enables "session replay" – making API requests with previously captured auth state.
func (s *SessionService) ApplySession(sessionID uuid.UUID, req *http.Request) error {
	// Retrieve the session state from the database
	state, err := s.GetSession(sessionID)
	if err != nil {
		return err // Return error if session lookup fails
	}

	// Apply stored cookies to the HTTP request.
	// Each cookie is added to the request's Cookie header.
	if cookies, ok := state["cookies"].(map[string]interface{}); ok {
		for name, value := range cookies {
			req.AddCookie(&http.Cookie{
				Name:  name,           // Cookie name (e.g., "session_id")
				Value: value.(string), // Cookie value
			})
		}
	}

	// Apply stored authentication tokens to the HTTP request.
	// If an "auth" token exists, it's set as a Bearer token in the Authorization header.
	if tokens, ok := state["tokens"].(map[string]interface{}); ok {
		if authToken, ok := tokens["auth"].(string); ok {
			// Set the Authorization header with the Bearer token scheme
			req.Header.Set("Authorization", "Bearer "+authToken)
		}
	}

	return nil // Session state applied successfully
}
