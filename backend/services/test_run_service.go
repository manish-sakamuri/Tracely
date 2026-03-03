// Package services – test_run_service.go provides business logic for
// persisting and retrieving HTTP test run results. Each test run stores
// the request's method, URL, headers, body, and the resulting status
// code and response time. This enables users to track test history.
package services

import (
	"backend/models"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TestRunService handles CRUD operations for test runs.
type TestRunService struct {
	db *gorm.DB
}

// NewTestRunService creates a new TestRunService with the given DB handle.
func NewTestRunService(db *gorm.DB) *TestRunService {
	return &TestRunService{db: db}
}

// Create persists a new test run to the database. The caller must supply
// the user ID, HTTP method, URL, and response details.
func (s *TestRunService) Create(run *models.TestRun) error {
	if err := s.db.Create(run).Error; err != nil {
		return fmt.Errorf("failed to create test run: %w", err)
	}
	return nil
}

// GetByUser retrieves test runs for a given user, ordered by most recent
// first. The environment parameter filters results when non-empty. Limit
// and offset support pagination.
func (s *TestRunService) GetByUser(userID uuid.UUID, environment string, limit, offset int) ([]models.TestRun, int64, error) {
	var runs []models.TestRun
	var total int64

	// Build query with environment-based filtering
	query := s.db.Where("user_id = ?", userID)
	if environment != "" {
		query = query.Where("environment = ?", environment)
	}

	// Count total before pagination
	if err := query.Model(&models.TestRun{}).Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to count test runs: %w", err)
	}

	// Fetch paginated results
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&runs).Error; err != nil {
		return nil, 0, fmt.Errorf("failed to get test runs: %w", err)
	}

	return runs, total, nil
}

// GetByID fetches a single test run by its primary key.
func (s *TestRunService) GetByID(id uuid.UUID) (*models.TestRun, error) {
	var run models.TestRun
	if err := s.db.First(&run, "id = ?", id).Error; err != nil {
		return nil, fmt.Errorf("test run not found: %w", err)
	}
	return &run, nil
}

// Delete soft-deletes a test run by ID.
func (s *TestRunService) Delete(id uuid.UUID, userID uuid.UUID) error {
	result := s.db.Where("id = ? AND user_id = ?", id, userID).Delete(&models.TestRun{})
	if result.Error != nil {
		return fmt.Errorf("failed to delete test run: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("test run not found or not owned by user")
	}
	return nil
}
