// Package services – this file implements the SettingsService which manages
// user preferences and account settings stored in the database.
// Settings include: theme (light/dark), notification preferences, language, and timezone.
// If a user has no settings record yet, default settings are created automatically.
package services

import (
	"backend/models" // Database models – UserSettings struct mapped to the user_settings DB table

	"github.com/google/uuid" // UUID library – used for user IDs
	"gorm.io/datatypes"      // GORM data types – provides JSON column support for PostgreSQL jsonb
	"gorm.io/gorm"           // GORM – ORM for database operations
)

// SettingsService is the struct that handles user settings business logic.
// It provides methods to get and update user preferences.
type SettingsService struct {
	db *gorm.DB // Database connection for querying and updating settings
}

// NewSettingsService is a constructor that creates a new SettingsService instance.
// It receives the database connection via dependency injection.
func NewSettingsService(db *gorm.DB) *SettingsService {
	return &SettingsService{db: db}
}

// DB returns the underlying database handle (used by handlers that need
// to perform additional lookups, e.g. fetching user email for settings).
func (s *SettingsService) DB() *gorm.DB {
	return s.db
}

// GetSettings retrieves the settings for a specific user.
// If no settings record exists for this user (e.g., they were created before
// the settings feature was added), default settings are created automatically.
// This ensures every user always has a valid settings record.
func (s *SettingsService) GetSettings(userID uuid.UUID) (*models.UserSettings, error) {
	var settings models.UserSettings

	// Attempt to find the user's settings in the database
	err := s.db.Where("user_id = ?", userID).First(&settings).Error

	// If no settings record was found, create one with sensible defaults
	if err == gorm.ErrRecordNotFound {
		// Create a default settings record for this user
		settings = models.UserSettings{
			UserID:               userID,                       // Link settings to this user
			Theme:                "light",                      // Default theme is light mode
			NotificationsEnabled: true,                         // Notifications enabled by default
			EmailNotifications:   true,                         // Email alerts enabled by default
			Language:             "en",                         // Default language is English
			Timezone:             "UTC",                        // Default timezone is UTC
			Preferences:          datatypes.JSON([]byte("{}")), // Empty JSON object for extra preferences
		}
		s.db.Create(&settings) // Save the default settings to the database
		return &settings, nil  // Return the newly created default settings
	}

	// Return the existing settings (or any database error that occurred)
	return &settings, err
}

// UpdateSettings applies partial updates to a user's settings.
// It first fetches the existing settings (creating defaults if needed),
// then applies only the fields that were provided in the updates map.
// This allows the client to update just one field (e.g., only the theme)
// without needing to resend all other settings.
func (s *SettingsService) UpdateSettings(userID uuid.UUID, updates map[string]interface{}) (*models.UserSettings, error) {
	// Step 1: Get the current settings (this also creates defaults if none exist)
	settings, err := s.GetSettings(userID)
	if err != nil {
		return nil, err // Return error if settings retrieval fails
	}

	// Step 2: Apply the updates to the settings record in the database.
	// GORM's Updates() method only modifies the fields present in the map,
	// leaving all other fields unchanged (partial update behavior).
	if err := s.db.Model(settings).Updates(updates).Error; err != nil {
		return nil, err // Return error if the database update fails
	}

	// Return the updated settings object
	return settings, nil
}
