package services

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AlertRule struct {
	ID                  uuid.UUID `gorm:"type:uuid;primary_key" json:"id"`
	WorkspaceID         uuid.UUID `gorm:"type:uuid;not null" json:"workspace_id"`
	Name                string    `gorm:"not null" json:"name"`
	Type                string    `gorm:"not null;default:'latency'" json:"type"` // latency, error_rate, request_count
	Condition           string    `gorm:"not null" json:"condition"`              // latency_threshold, error_rate, etc.
	Threshold           float64   `gorm:"not null" json:"threshold"`
	TimeWindow          int       `gorm:"not null" json:"time_window"` // minutes
	Enabled             bool      `gorm:"default:true" json:"enabled"`
	NotificationChannel string    `gorm:"not null" json:"notification_channel"` // slack, email, pagerduty
	NotificationConfig  string    `gorm:"type:jsonb" json:"notification_config"`
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

type Alert struct {
	ID          uuid.UUID  `gorm:"type:uuid;primary_key" json:"id"`
	RuleID      uuid.UUID  `gorm:"type:uuid;not null" json:"rule_id"`
	WorkspaceID uuid.UUID  `gorm:"type:uuid;not null" json:"workspace_id"`
	Severity    string     `gorm:"not null" json:"severity"` // critical, warning, info
	Message     string     `gorm:"type:text" json:"message"`
	TriggeredAt time.Time  `gorm:"not null" json:"triggered_at"`
	ResolvedAt  *time.Time `json:"resolved_at"`
	Status      string     `gorm:"default:'active'" json:"status"` // active, resolved, acknowledged
	Metadata    string     `gorm:"type:jsonb" json:"metadata"`
	CreatedAt   time.Time  `json:"created_at"`
}

type AlertingService struct {
	db *gorm.DB
}

func NewAlertingService(db *gorm.DB) *AlertingService {
	return &AlertingService{db: db}
}

// CreateRule creates a new alert rule
func (s *AlertingService) CreateRule(userID uuid.UUID, workspaceID uuid.UUID, name, condition string, threshold float64, timeWindow int, channel string) (*AlertRule, error) {
	rule := AlertRule{
		ID:                  uuid.New(),
		WorkspaceID:         workspaceID,
		Name:                name,
		Type:                condition, // Use condition as the type
		Condition:           condition,
		Threshold:           threshold,
		TimeWindow:          timeWindow,
		Enabled:             true,
		NotificationChannel: channel,
	}

	if err := s.db.Create(&rule).Error; err != nil {
		return nil, err
	}

	return &rule, nil
}

// GetRulesByWorkspace returns all enabled alert rules for a workspace.
// Used by the alert engine to evaluate rules periodically.
func (s *AlertingService) GetRulesByWorkspace(workspaceID uuid.UUID) ([]AlertRule, error) {
	var rules []AlertRule
	err := s.db.Where("workspace_id = ? AND enabled = true", workspaceID).Find(&rules).Error
	return rules, err
}

// CheckLatencyThreshold checks if latency exceeds threshold
func (s *AlertingService) CheckLatencyThreshold(workspaceID uuid.UUID, currentLatency, threshold time.Duration) error {
	if currentLatency > threshold {
		s.TriggerAlert(uuid.Nil, workspaceID, "critical",
			fmt.Sprintf("Average latency (%.0fms) exceeded threshold (%.0fms)",
				float64(currentLatency.Milliseconds()), float64(threshold.Milliseconds())),
			map[string]interface{}{
				"current_value": currentLatency.Milliseconds(),
				"threshold":     threshold.Milliseconds(),
			})
	}
	return nil
}

// CheckErrorRate checks if error rate exceeds threshold
func (s *AlertingService) CheckErrorRate(workspaceID uuid.UUID, currentRate, threshold float64) error {
	if currentRate > threshold {
		s.TriggerAlert(uuid.Nil, workspaceID, "critical",
			fmt.Sprintf("Error rate (%.2f%%) exceeded threshold (%.2f%%)", currentRate*100, threshold*100),
			map[string]interface{}{
				"error_rate": currentRate,
				"threshold":  threshold,
			})
	}
	return nil
}

// TriggerAlert creates and sends an alert
func (s *AlertingService) TriggerAlert(ruleID, workspaceID uuid.UUID, severity, message string, metadata map[string]interface{}) error {
	metadataJSON, _ := json.Marshal(metadata)

	alert := Alert{
		ID:          uuid.New(),
		RuleID:      ruleID,
		WorkspaceID: workspaceID,
		Severity:    severity,
		Message:     message,
		TriggeredAt: time.Now(),
		Status:      "active",
		Metadata:    string(metadataJSON),
	}

	if err := s.db.Create(&alert).Error; err != nil {
		return err
	}

	// Only look up rule for notifications if ruleID is not nil
	if ruleID != uuid.Nil {
		var rule AlertRule
		if err := s.db.First(&rule, ruleID).Error; err != nil {
			return err
		}

		// Send notification based on channel
		switch rule.NotificationChannel {
		case "slack":
			return s.SendSlackNotification(&alert, &rule)
		case "email":
			return s.SendEmailNotification(&alert, &rule)
		case "pagerduty":
			return s.SendPagerDutyNotification(&alert, &rule)
		}
	}

	return nil
}

// SendSlackNotification sends alert to Slack
func (s *AlertingService) SendSlackNotification(alert *Alert, rule *AlertRule) error {
	// Implementation would use Slack webhook
	fmt.Printf("SLACK ALERT: [%s] %s\n", alert.Severity, alert.Message)
	return nil
}

// SendEmailNotification sends alert via email
func (s *AlertingService) SendEmailNotification(alert *Alert, rule *AlertRule) error {
	// Implementation would use SMTP or email service
	fmt.Printf("EMAIL ALERT: [%s] %s\n", alert.Severity, alert.Message)
	return nil
}

// SendPagerDutyNotification sends alert to PagerDuty
func (s *AlertingService) SendPagerDutyNotification(alert *Alert, rule *AlertRule) error {
	// Implementation would use PagerDuty API
	fmt.Printf("PAGERDUTY ALERT: [%s] %s\n", alert.Severity, alert.Message)
	return nil
}

// AcknowledgeAlert marks an alert as acknowledged
func (s *AlertingService) AcknowledgeAlert(alertID uuid.UUID) error {
	return s.db.Model(&Alert{}).Where("id = ?", alertID).Update("status", "acknowledged").Error
}

// ResolveAlert marks an alert as resolved
func (s *AlertingService) ResolveAlert(alertID uuid.UUID) error {
	now := time.Now()
	return s.db.Model(&Alert{}).Where("id = ?", alertID).Updates(map[string]interface{}{
		"status":      "resolved",
		"resolved_at": now,
	}).Error
}

// GetActiveAlerts gets all active alerts for a workspace
func (s *AlertingService) GetActiveAlerts(workspaceID uuid.UUID) ([]Alert, error) {
	var alerts []Alert
	err := s.db.Where("workspace_id = ? AND status = 'active'", workspaceID).
		Order("triggered_at DESC").
		Find(&alerts).Error
	return alerts, err
}

// GetAllAlerts gets all alerts for a workspace (active, resolved, acknowledged)
// with optional severity filtering and pagination.
func (s *AlertingService) GetAllAlerts(workspaceID uuid.UUID, severity string, limit, offset int) ([]Alert, int64, error) {
	var alerts []Alert
	var total int64

	query := s.db.Where("workspace_id = ?", workspaceID)
	if severity != "" && severity != "All" {
		query = query.Where("severity = ?", severity)
	}

	if err := query.Model(&Alert{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	err := query.Order("triggered_at DESC").Limit(limit).Offset(offset).Find(&alerts).Error
	return alerts, total, err
}
