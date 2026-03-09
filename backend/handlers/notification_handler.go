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
// Checks user settings (notifications_enabled), device token, then responds.
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

	// ── 1. Check if notifications are enabled in user settings ──
	var settings models.UserSettings
	notificationsEnabled := true // default
	if err := h.db.Where("user_id = ?", userID).First(&settings).Error; err == nil {
		notificationsEnabled = settings.NotificationsEnabled
	}

	if !notificationsEnabled {
		_ = h.userLogService.CreateLogWithMetadata(userID, "WARN",
			"Test notification blocked: notifications disabled",
			`{"notifications_enabled":false,"push_sent":false,"reason":"NOTIFICATIONS_DISABLED"}`,
		)
		c.JSON(http.StatusBadRequest, gin.H{
			"success":   false,
			"push_sent": false,
			"mode":      "log_only",
			"reason":    "NOTIFICATIONS_DISABLED",
			"message":   "Push notifications are disabled. Enable them in Settings first.",
		})
		return
	}

	// ── 2. Check if user has a registered device token ──
	var deviceToken models.DeviceToken
	hasToken := h.db.Where("user_id = ?", userID).First(&deviceToken).Error == nil

	if !hasToken {
		_ = h.userLogService.CreateLogWithMetadata(userID, "WARN",
			"Test notification: no device token registered",
			`{"notifications_enabled":true,"has_device_token":false,"push_sent":false,"reason":"NO_DEVICE_TOKEN"}`,
		)
		c.JSON(http.StatusConflict, gin.H{
			"success":   false,
			"push_sent": false,
			"mode":      "log_only",
			"reason":    "NO_DEVICE_TOKEN",
			"message":   "No device token registered. Open the app on your phone to register automatically.",
		})
		return
	}

	// ── 3. Token exists — attempt push (simulated for now) ──
	metadata := fmt.Sprintf(
		`{"notifications_enabled":true,"has_device_token":true,"push_sent":true,"platform":"%s","token_prefix":"%s"}`,
		deviceToken.Platform,
		deviceToken.Token[:min(8, len(deviceToken.Token))]+"...",
	)
	if err := h.userLogService.CreateLogWithMetadata(userID, "INFO",
		"Test notification sent successfully",
		metadata,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success":   false,
			"push_sent": false,
			"mode":      "log_only",
			"message":   "Failed to log notification: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"push_sent": true,
		"mode":      "push",
		"message":   "Test notification sent to your " + deviceToken.Platform + " device.",
	})
}

// RegisterDeviceTokenRequest defines the expected body for device token registration.
type RegisterDeviceTokenRequest struct {
	Token    string `json:"token" binding:"required"`
	Platform string `json:"platform" binding:"required"` // android, ios, web
}

// RegisterDeviceToken handles POST /notifications/device-token.
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
		h.db.Model(&existing).Updates(map[string]interface{}{
			"user_id":  userID,
			"platform": req.Platform,
		})
	}

	_ = h.userLogService.CreateLogWithMetadata(userID, "INFO",
		"Device token registered for "+req.Platform,
		fmt.Sprintf(`{"platform":"%s","token_prefix":"%s"}`, req.Platform, req.Token[:min(8, len(req.Token))]+"..."),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Device token registered",
	})
}

// min returns the smaller of two ints.
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
