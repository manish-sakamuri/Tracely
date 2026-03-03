// Package handlers – user_handler.go provides HTTP handlers for user
// profile management, audit log retrieval, and environment switching.
package handlers

import (
	"backend/models"
	"backend/services"
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// UserHandler exposes endpoints for user profile operations.
type UserHandler struct {
	db             *gorm.DB
	userLogService *services.UserLogService
}

// NewUserHandler creates a handler with the required dependencies.
func NewUserHandler(db *gorm.DB, uls *services.UserLogService) *UserHandler {
	return &UserHandler{
		db:             db,
		userLogService: uls,
	}
}

// GetMe handles GET /users/me. It returns the authenticated user's profile
// information (id, email, name, auth_provider, selected_environment).
func (h *UserHandler) GetMe(c *gin.Context) {
	// Extract authenticated user ID from JWT middleware context
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

	// Fetch user from database
	var user models.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":                   user.ID,
		"email":                user.Email,
		"name":                 user.Name,
		"auth_provider":        user.AuthProvider,
		"selected_environment": user.SelectedEnvironment,
		"created_at":           user.CreatedAt,
	})
}

// GetLogs handles GET /users/logs. It returns structured audit logs for
// the authenticated user with optional severity filtering and pagination.
func (h *UserHandler) GetLogs(c *gin.Context) {
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

	// Parse query parameters
	level := c.Query("level")
	limit := 50
	offset := 0
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	if o := c.Query("offset"); o != "" {
		if parsed, err := strconv.Atoi(o); err == nil && parsed >= 0 {
			offset = parsed
		}
	}

	// Fetch logs
	logs, total, err := h.userLogService.GetLogs(userID, level, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch logs"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"logs":   logs,
		"total":  total,
		"limit":  limit,
		"offset": offset,
	})
}

// UpdateEnvironment handles PUT /users/environment. It saves the user's
// selected environment preference so the dashboard filters by it.
func (h *UserHandler) UpdateEnvironment(c *gin.Context) {
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

	var body struct {
		Environment string `json:"environment" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing environment field"})
		return
	}

	// Update the user's selected environment
	if err := h.db.Model(&models.User{}).Where("id = ?", userID).
		Update("selected_environment", body.Environment).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update environment"})
		return
	}

	// Create an audit log entry
	_ = h.userLogService.CreateLog(userID, "INFO", "Environment switched to: "+body.Environment)

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"environment": body.Environment,
	})
}
