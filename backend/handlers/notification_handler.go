// Package handlers – notification_handler.go provides endpoints for testing
// push notifications and managing device tokens.
package handlers

import (
	"backend/models"
	"backend/services"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// NotificationHandler exposes endpoints for notification management.
type NotificationHandler struct {
	db             *gorm.DB
	userLogService *services.UserLogService
}

// NewNotificationHandler creates a handler with the required dependencies.
func NewNotificationHandler(db *gorm.DB, uls *services.UserLogService) *NotificationHandler {
	return &NotificationHandler{
		db:             db,
		userLogService: uls,
	}
}

// TestNotification handles POST /notifications/test.
// It simulates a push notification by creating a user log entry.
func (h *NotificationHandler) TestNotification(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, err := uuid.Parse(fmt.Sprintf("%v", userIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Create a test notification log entry
	_ = h.userLogService.CreateLog(userID, "INFO", "Test notification triggered successfully")

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Test notification sent. Check your logs for confirmation.",
	})
}

// RegisterDeviceTokenRequest defines the expected body for device token registration.
type RegisterDeviceTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required"` // android, ios, web
}

// RegisterDeviceToken handles POST /notifications/device-token.
// It saves or updates a device token for push notifications.
func (h *NotificationHandler) RegisterDeviceToken(c *gin.Context) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID, err := uuid.Parse(fmt.Sprintf("%v", userIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var req RegisterDeviceTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing token or platform"})
		return
	}

	// Upsert device token
	var existing models.DeviceToken
	result := h.db.Where("token = ?", req.Token).First(&existing)
	if result.Error != nil {
		// Create new token
		token := models.DeviceToken{
			UserID:   userID,
			Token:    req.Token,
			Platform: req.Platform,
		}
		if err := h.db.Create(&token).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save device token"})
			return
		}
	} else {
		// Update existing token's user and platform
		h.db.Model(&existing).Updates(map[string]interface{}{
			"user_id":  userID,
			"platform": req.Platform,
		})
	}

	_ = h.userLogService.CreateLog(userID, "INFO", "Device token registered for "+req.Platform)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Device token registered",
	})
}
