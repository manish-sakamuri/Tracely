// Package handlers – this file contains the SettingsHandler which manages
// user preferences and account settings (theme, notifications, language, etc.).
// These settings are tied to the authenticated user via the JWT token.
package handlers

import (
	"backend/middlewares" // Custom middleware – used to extract the authenticated user's ID from JWT
	"backend/models"
	"backend/services" // Business logic layer – SettingsService handles CRUD for user settings
	"net/http"         // Standard HTTP library – provides status codes (200, 400, 500)

	"github.com/gin-gonic/gin" // Gin web framework for HTTP routing and JSON response handling
)

// SettingsHandler groups all user-settings-related HTTP handlers.
// It depends on SettingsService to perform the actual database operations.
type SettingsHandler struct {
	settingsService *services.SettingsService // Reference to the settings business logic service
}

// NewSettingsHandler is a constructor function that creates a SettingsHandler.
// It takes a SettingsService as a parameter (dependency injection pattern)
// and returns a pointer to the new handler.
func NewSettingsHandler(settingsService *services.SettingsService) *SettingsHandler {
	return &SettingsHandler{settingsService: settingsService}
}

// GetSettings handles GET /api/v1/users/settings
// This endpoint retrieves the authenticated user's preferences (theme, notifications, etc.)
// plus the user's email and account ID from the User table.
func (h *SettingsHandler) GetSettings(c *gin.Context) {
	userID, _ := middlewares.GetUserID(c)

	settings, err := h.settingsService.GetSettings(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Build response map from settings struct
	response := gin.H{
		"id":                    settings.ID,
		"user_id":               settings.UserID,
		"theme":                 settings.Theme,
		"notifications_enabled": settings.NotificationsEnabled,
		"email_notifications":   settings.EmailNotifications,
		"language":              settings.Language,
		"timezone":              settings.Timezone,
		"preferences":           settings.Preferences,
	}

	// Also fetch the user's email and name so the Settings screen can display them
	if settings.User.Email != "" {
		response["email"] = settings.User.Email
		response["name"] = settings.User.Name
	} else {
		// Preload wasn't used, so fetch user separately
		var user models.User
		if err := h.settingsService.DB().First(&user, "id = ?", userID).Error; err == nil {
			response["email"] = user.Email
			response["name"] = user.Name
		}
	}

	c.JSON(http.StatusOK, response)
}

// UpdateSettings handles PUT /api/v1/users/settings
// This endpoint allows the authenticated user to update their preferences.
// The client sends a JSON body with only the fields they want to change.
// Example: {"theme": "dark", "notifications_enabled": false}
func (h *SettingsHandler) UpdateSettings(c *gin.Context) {
	// Extract the authenticated user's ID from the JWT context
	userID, _ := middlewares.GetUserID(c)

	// Parse the request body into a generic map.
	// Using map[string]interface{} allows the client to send any subset of settings fields,
	// making partial updates possible (only the provided fields are changed).
	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		// Return HTTP 400 Bad Request if the JSON body is malformed or missing
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Call the SettingsService to apply the updates to the user's settings in the database.
	// The service first fetches existing settings, then applies only the changed fields.
	settings, err := h.settingsService.UpdateSettings(userID, updates)
	if err != nil {
		// Return HTTP 500 Internal Server Error if the database update fails
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return HTTP 200 OK with the updated settings object
	c.JSON(http.StatusOK, settings)
}
