// Package services – alert_engine_service.go provides an alert generation
// engine that scans monitoring data and automatically creates alerts when
// thresholds are breached. It works in conjunction with the AlertingService
// to evaluate rules and trigger alerts.
package services

import (
	"log"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AlertEngineService periodically scans trace data against alert rules
// and generates alerts when conditions are met.
type AlertEngineService struct {
	db              *gorm.DB
	alertingService *AlertingService
	monitoringAgg   *MonitoringAggregationService
}

// NewAlertEngineService creates a new alert engine with the required
// dependencies for rule evaluation and alert creation.
func NewAlertEngineService(
	db *gorm.DB,
	alertingService *AlertingService,
	monitoringAgg *MonitoringAggregationService,
) *AlertEngineService {
	return &AlertEngineService{
		db:              db,
		alertingService: alertingService,
		monitoringAgg:   monitoringAgg,
	}
}

// EvaluateRules checks all active alert rules for a workspace and triggers
// alerts when conditions are breached. This function is called periodically
// or on-demand to scan for anomalies.
func (s *AlertEngineService) EvaluateRules(workspaceID uuid.UUID) {
	// Fetch all alert rules for this workspace
	rules, err := s.alertingService.GetRulesByWorkspace(workspaceID)
	if err != nil {
		log.Printf("[AlertEngine] failed to fetch rules for workspace %s: %v", workspaceID, err)
		return
	}

	// Get current monitoring data to evaluate against
	dashboard, err := s.monitoringAgg.AggregateDashboard(workspaceID, "last_5m", "")
	if err != nil {
		log.Printf("[AlertEngine] failed to aggregate dashboard for workspace %s: %v", workspaceID, err)
		return
	}

	for _, rule := range rules {
		s.evaluateRule(rule, dashboard, workspaceID)
	}
}

// evaluateRule checks a single rule against the current dashboard metrics
// and triggers an alert if the threshold is breached.
func (s *AlertEngineService) evaluateRule(rule AlertRule, dashboard *AggregatedDashboard, workspaceID uuid.UUID) {
	switch rule.Type {
	case "latency":
		// Check if avg latency exceeds the threshold
		if dashboard.AvgLatency > rule.Threshold {
			s.alertingService.CheckLatencyThreshold(
				workspaceID,
				time.Duration(dashboard.AvgLatency)*time.Millisecond,
				time.Duration(rule.Threshold)*time.Millisecond,
			)
			log.Printf("[AlertEngine] latency alert triggered: %.0fms > %.0fms", dashboard.AvgLatency, rule.Threshold)
		}
	case "error_rate":
		// Check if error rate exceeds the threshold
		if dashboard.ErrorRate > rule.Threshold {
			s.alertingService.CheckErrorRate(
				workspaceID,
				dashboard.ErrorRate/100,
				rule.Threshold/100,
			)
			log.Printf("[AlertEngine] error rate alert triggered: %.1f%% > %.1f%%", dashboard.ErrorRate, rule.Threshold)
		}
	case "request_count":
		// Check if total requests drop below threshold (service down detection)
		if dashboard.TotalRequests < int64(rule.Threshold) {
			log.Printf("[AlertEngine] low traffic alert: %d requests < %.0f threshold", dashboard.TotalRequests, rule.Threshold)
		}
	default:
		log.Printf("[AlertEngine] unknown rule type: %s", rule.Type)
	}
}

// StartPeriodicEvaluation launches a background goroutine that evaluates
// alert rules every interval for the specified workspace. Call this once
// per workspace when the server starts.
func (s *AlertEngineService) StartPeriodicEvaluation(workspaceID uuid.UUID, interval time.Duration, stop <-chan struct{}) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				s.EvaluateRules(workspaceID)
			case <-stop:
				log.Printf("[AlertEngine] stopping periodic evaluation for workspace %s", workspaceID)
				return
			}
		}
	}()
}
