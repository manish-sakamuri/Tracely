// Package services – this file implements the AuditService which provides
// security audit logging for all workspace activities.
// Every significant action (create, update, delete, execute) is recorded in an audit log,
// enabling compliance tracking, security monitoring, and anomaly detection.
package services

import (
	"encoding/json" // Standard Go package for JSON serialization
	"time"          // Standard time package – for timestamps and time-based calculations

	"github.com/google/uuid" // UUID library – for unique identifiers
	"gorm.io/gorm"           // GORM – ORM for database operations
)

// AuditLog represents a single audit log entry stored in the database.
// Each entry records WHO did WHAT, WHEN, and WHERE in the system.
// This is essential for security monitoring and compliance requirements.
type AuditLog struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key"` // Unique audit log entry ID
	WorkspaceID  uuid.UUID `gorm:"type:uuid;not null"`    // Which workspace the action occurred in
	UserID       uuid.UUID `gorm:"type:uuid;not null"`    // Which user performed the action
	Action       string    `gorm:"not null"`              // What was done: "create", "update", "delete", "execute", "view"
	ResourceType string    `gorm:"not null"`              // What type of resource was affected: "request", "trace", "workspace", etc.
	ResourceID   uuid.UUID `gorm:"type:uuid"`             // The specific resource that was acted upon
	Changes      string    `gorm:"type:jsonb"`            // JSON storing before/after state for update operations
	IPAddress    string    // IP address of the client that made the request
	UserAgent    string    // Browser/client identifier string
	Success      bool      `gorm:"default:true"` // Whether the action succeeded or failed
	ErrorMessage string    // Error details if the action failed
	CreatedAt    time.Time // Timestamp when the action occurred (auto-set by GORM)
}

// AuditService is the struct that handles audit log operations.
// It provides methods to create log entries, retrieve logs with filters,
// and detect anomalous access patterns.
type AuditService struct {
	db *gorm.DB // Database connection for querying and storing audit logs
}

// NewAuditService is a constructor that creates a new AuditService instance.
// It receives the database connection via dependency injection.
func NewAuditService(db *gorm.DB) *AuditService {
	return &AuditService{db: db}
}

// Log creates a new audit log entry in the database.
// This method is called by other services/handlers whenever a significant action occurs.
// Parameters:
//   - workspaceID: which workspace the action happened in
//   - userID: who performed the action
//   - resourceID: the specific resource affected (e.g., a request ID, trace ID)
//   - action: what was done ("create", "update", "delete", "execute", "view")
//   - resourceType: what kind of resource ("request", "trace", "workspace")
//   - ipAddress: client's IP address for security tracking
//   - userAgent: client's browser/app identifier
//   - changes: map of before/after values for update operations
//   - success: whether the operation succeeded
//   - errorMsg: error description if the operation failed
func (s *AuditService) Log(workspaceID, userID, resourceID uuid.UUID, action, resourceType, ipAddress, userAgent string, changes map[string]interface{}, success bool, errorMsg string) error {
	// Serialize the changes map to JSON for database storage
	changesJSON, _ := json.Marshal(changes)

	// Build the audit log record with all the provided information
	log := AuditLog{
		ID:           uuid.New(),          // Generate a unique ID for this log entry
		WorkspaceID:  workspaceID,         // Link to the workspace
		UserID:       userID,              // Link to the user who performed the action
		Action:       action,              // What was done (e.g., "create")
		ResourceType: resourceType,        // What type of resource (e.g., "request")
		ResourceID:   resourceID,          // Which specific resource was affected
		Changes:      string(changesJSON), // JSON string of changes (before/after state)
		IPAddress:    ipAddress,           // Client's IP address
		UserAgent:    userAgent,           // Client identifier
		Success:      success,             // Was the operation successful?
		ErrorMessage: errorMsg,            // Error message if operation failed
	}

	// Insert the audit log entry into the database
	return s.db.Create(&log).Error
}

// GetLogs retrieves audit log entries for a workspace with optional filters.
// Supports filtering by user_id, action type, and resource type.
// Results are paginated using limit/offset and sorted by newest first.
// Parameters:
//   - workspaceID: which workspace to get logs for
//   - filters: optional filters like {"user_id": uuid, "action": "create", "resource_type": "request"}
//   - limit: maximum number of entries to return (for pagination)
//   - offset: number of entries to skip (for pagination)
func (s *AuditService) GetLogs(workspaceID uuid.UUID, filters map[string]interface{}, limit, offset int) ([]AuditLog, error) {
	var logs []AuditLog

	// Start building the database query – always filter by workspace
	query := s.db.Where("workspace_id = ?", workspaceID)

	// Apply optional filters if provided:

	// Filter by specific user – shows only actions by a particular user
	if userID, ok := filters["user_id"].(uuid.UUID); ok {
		query = query.Where("user_id = ?", userID)
	}

	// Filter by action type – e.g., show only "delete" actions
	if action, ok := filters["action"].(string); ok {
		query = query.Where("action = ?", action)
	}

	// Filter by resource type – e.g., show only actions on "request" resources
	if resourceType, ok := filters["resource_type"].(string); ok {
		query = query.Where("resource_type = ?", resourceType)
	}

	// Execute the query: sort by newest first, apply pagination (limit and offset)
	err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&logs).Error
	return logs, err
}

// DetectAnomalies analyzes a user's recent activity in a workspace to identify
// suspicious or unusual access patterns. This is a security feature that helps
// detect potential account compromises or abuse.
// Returns a list of anomaly descriptions (empty list = no anomalies detected).
func (s *AuditService) DetectAnomalies(workspaceID, userID uuid.UUID) ([]string, error) {
	anomalies := []string{} // Start with an empty list of anomalies

	// ── Check 1: Rapid successive actions ──
	// Count how many actions this user performed in the last 5 minutes.
	// More than 100 actions in 5 minutes is suspicious (possible bot or attack).
	var count int64
	s.db.Model(&AuditLog{}).
		Where("workspace_id = ? AND user_id = ? AND created_at > ?", workspaceID, userID, time.Now().Add(-5*time.Minute)).
		Count(&count)

	if count > 100 {
		// Flag as anomaly if activity rate is unusually high
		anomalies = append(anomalies, "Unusually high activity (100+ actions in 5 minutes)")
	}

	// ── Check 2: Access from multiple IP addresses ──
	// Get the distinct IP addresses this user used in the last hour.
	// More than 5 different IPs could indicate a compromised account.
	var ips []string
	s.db.Model(&AuditLog{}).
		Where("workspace_id = ? AND user_id = ? AND created_at > ?", workspaceID, userID, time.Now().Add(-1*time.Hour)).
		Distinct("ip_address"). // Only unique IP addresses
		Pluck("ip_address", &ips)

	if len(ips) > 5 {
		// Flag as anomaly if user is connecting from many different locations
		anomalies = append(anomalies, "Access from multiple IP addresses (5+ IPs in 1 hour)")
	}

	// ── Check 3: Multiple failed actions ──
	// Count failed actions in the last 10 minutes.
	// More than 10 failures could indicate a brute-force attack or permission issues.
	var failedCount int64
	s.db.Model(&AuditLog{}).
		Where("workspace_id = ? AND user_id = ? AND success = false AND created_at > ?", workspaceID, userID, time.Now().Add(-10*time.Minute)).
		Count(&failedCount)

	if failedCount > 10 {
		// Flag as anomaly if there are many failed attempts
		anomalies = append(anomalies, "Multiple failed actions (10+ failures in 10 minutes)")
	}

	return anomalies, nil // Return the list of detected anomalies (may be empty)
}
