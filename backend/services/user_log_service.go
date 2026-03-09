// Package services – user_log_service.go provides structured audit logging
// for user actions. Logs are persisted to the database so they can be
// retrieved on the Settings → View Logs screen. Each log entry has a
// severity level (INFO, WARN, ERROR) and a freeform message.
package services

import (
	"backend/models"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// UserLogService handles CRUD operations for user audit logs.
type UserLogService struct {
	db *gorm.DB
}

// NewUserLogService creates a new service with the given database handle.
func NewUserLogService(db *gorm.DB) *UserLogService {
	return &UserLogService{db: db}
}

// CreateLog inserts a new audit log entry for the specified user.
func (s *UserLogService) CreateLog(userID uuid.UUID, level, message string) error {
	return s.CreateLogWithMetadata(userID, level, message, "{}")
}

// CreateLogWithMetadata inserts a log entry with structured JSON metadata.
// The metadata string is validated and normalized before insertion to prevent
// JSONB SQL errors from empty or malformed strings.
func (s *UserLogService) CreateLogWithMetadata(userID uuid.UUID, level, message, metadata string) error {
	metadata = normalizeJSON(metadata)
	logEntry := models.UserLog{
		UserID:   userID,
		Level:    level,
		Message:  message,
		Metadata: metadata,
	}
	if err := s.db.Create(&logEntry).Error; err != nil {
		return fmt.Errorf("failed to create user log: %w", err)
	}
	return nil
}

// GetLogs retrieves logs for a user with optional severity filtering.
// Results are ordered most-recent-first. Limit and offset support pagination.
func (s *UserLogService) GetLogs(userID uuid.UUID, level string, limit, offset int) ([]models.UserLog, int64, error) {
	var logs []models.UserLog
	var total int64

	query := s.db.Where("user_id = ?", userID)
	if level != "" && level != "All" {
		query = query.Where("level = ?", level)
	}

	if err := query.Model(&models.UserLog{}).Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to count logs: %w", err)
	}

	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&logs).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to get logs: %w", err)
	}

	return logs, total, nil
}

// normalizeJSON ensures a string is valid JSON for JSONB columns.
// Returns "{}" if the input is empty or invalid JSON.
func normalizeJSON(s string) string {
	if s == "" {
		return "{}"
	}
	if json.Valid([]byte(s)) {
		return s
	}
	return "{}"
}
