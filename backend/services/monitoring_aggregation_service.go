// Package services – monitoring_aggregation_service.go provides a
// monitoring aggregation engine that computes real-time metrics from
// stored traces and executions. It calculates total request counts,
// error rates, average latency, and per-service health status.
package services

import (
	"backend/models"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MonitoringAggregationService aggregates trace data into dashboard metrics.
type MonitoringAggregationService struct {
	db *gorm.DB
}

// ServiceMetric represents computed metrics for a single service.
type ServiceMetric struct {
	Name         string  `json:"name"`
	RequestCount int64   `json:"request_count"`
	ErrorCount   int64   `json:"error_count"`
	ErrorRate    float64 `json:"error_rate"`
	AvgLatencyMs float64 `json:"avg_latency_ms"`
	P99LatencyMs float64 `json:"p99_latency_ms"`
	Status       string  `json:"status"` // healthy, degraded, down
}

// AggregatedDashboard is the complete dashboard payload returned to the frontend.
type AggregatedDashboard struct {
	TotalRequests int64           `json:"total_requests"`
	ErrorRate     float64         `json:"error_rate"`
	AvgLatency    float64         `json:"avg_latency"`
	Services      []ServiceMetric `json:"services"`
	TopEndpoints  []EndpointStat  `json:"top_endpoints"`
	TimeRange     string          `json:"time_range"`
}

// EndpointStat represents usage statistics for a single endpoint.
type EndpointStat struct {
	Path         string  `json:"path"`
	Method       string  `json:"method"`
	RequestCount int64   `json:"request_count"`
	AvgLatencyMs float64 `json:"avg_latency_ms"`
	ErrorRate    float64 `json:"error_rate"`
}

// NewMonitoringAggregationService creates a new monitoring aggregation service.
func NewMonitoringAggregationService(db *gorm.DB) *MonitoringAggregationService {
	return &MonitoringAggregationService{db: db}
}

// AggregateDashboard computes dashboard metrics for the given workspace
// over the specified time range. Environment-based filtering is applied
// when the environment parameter is non-empty.
func (s *MonitoringAggregationService) AggregateDashboard(
	workspaceID uuid.UUID,
	timeRange string,
	environment string,
) (*AggregatedDashboard, error) {
	// Determine the time window based on the requested range
	since := timeRangeToSince(timeRange)

	// Count total traces in the window
	var totalCount int64
	traceQuery := s.db.Model(&models.Trace{}).
		Where("workspace_id = ? AND start_time >= ?", workspaceID, since)
	if environment != "" {
		traceQuery = traceQuery.Where("service_name LIKE ?", "%"+environment+"%")
	}
	traceQuery.Count(&totalCount)

	// Count error traces (status != 'success')
	var errorCount int64
	errorQuery := s.db.Model(&models.Trace{}).
		Where("workspace_id = ? AND start_time >= ? AND status != 'success'", workspaceID, since)
	if environment != "" {
		errorQuery = errorQuery.Where("service_name LIKE ?", "%"+environment+"%")
	}
	errorQuery.Count(&errorCount)

	// Compute average latency from total_duration_ms
	var avgLatency float64
	s.db.Model(&models.Trace{}).
		Where("workspace_id = ? AND start_time >= ?", workspaceID, since).
		Select("COALESCE(AVG(total_duration_ms), 0)").
		Scan(&avgLatency)

	// Calculate error rate
	var errorRate float64
	if totalCount > 0 {
		errorRate = float64(errorCount) / float64(totalCount) * 100
	}

	// Aggregate per-service metrics
	services, err := s.aggregateServices(workspaceID, since, environment)
	if err != nil {
		return nil, err
	}

	// Aggregate top endpoints from spans
	topEndpoints := s.aggregateTopEndpoints(workspaceID, since)

	return &AggregatedDashboard{
		TotalRequests: totalCount,
		ErrorRate:     errorRate,
		AvgLatency:    avgLatency,
		Services:      services,
		TopEndpoints:  topEndpoints,
		TimeRange:     timeRange,
	}, nil
}

// aggregateServices groups traces by service_name and computes per-service
// request counts, error rates, and latency to determine health status.
func (s *MonitoringAggregationService) aggregateServices(
	workspaceID uuid.UUID,
	since time.Time,
	environment string,
) ([]ServiceMetric, error) {
	type row struct {
		ServiceName  string
		Total        int64
		Errors       int64
		AvgLatencyMs float64
	}
	var rows []row

	query := s.db.Model(&models.Trace{}).
		Select("service_name, COUNT(*) as total, "+
			"SUM(CASE WHEN status != 'success' THEN 1 ELSE 0 END) as errors, "+
			"COALESCE(AVG(total_duration_ms), 0) as avg_latency_ms").
		Where("workspace_id = ? AND start_time >= ?", workspaceID, since).
		Group("service_name")

	if environment != "" {
		query = query.Where("service_name LIKE ?", "%"+environment+"%")
	}

	if err := query.Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("failed to aggregate services: %w", err)
	}

	metrics := make([]ServiceMetric, 0, len(rows))
	for _, r := range rows {
		errRate := float64(0)
		if r.Total > 0 {
			errRate = float64(r.Errors) / float64(r.Total) * 100
		}
		status := "healthy"
		if errRate > 10 {
			status = "down"
		} else if errRate > 2 || r.AvgLatencyMs > 1000 {
			status = "degraded"
		}
		metrics = append(metrics, ServiceMetric{
			Name:         r.ServiceName,
			RequestCount: r.Total,
			ErrorCount:   r.Errors,
			ErrorRate:    errRate,
			AvgLatencyMs: r.AvgLatencyMs,
			Status:       status,
		})
	}
	return metrics, nil
}

// aggregateTopEndpoints returns the most frequently called endpoints
// derived from span operation names.
func (s *MonitoringAggregationService) aggregateTopEndpoints(
	workspaceID uuid.UUID,
	since time.Time,
) []EndpointStat {
	type row struct {
		OperationName string
		Total         int64
		AvgDuration   float64
		Errors        int64
	}
	var rows []row

	s.db.Model(&models.Span{}).
		Joins("JOIN traces ON traces.id = spans.trace_id").
		Where("traces.workspace_id = ? AND spans.start_time >= ?", workspaceID, since).
		Select("spans.operation_name, COUNT(*) as total, " +
			"COALESCE(AVG(spans.duration_ms), 0) as avg_duration, " +
			"SUM(CASE WHEN spans.status_code >= 400 THEN 1 ELSE 0 END) as errors").
		Group("spans.operation_name").
		Order("total DESC").
		Limit(10).
		Scan(&rows)

	stats := make([]EndpointStat, 0, len(rows))
	for _, r := range rows {
		errRate := float64(0)
		if r.Total > 0 {
			errRate = float64(r.Errors) / float64(r.Total) * 100
		}
		stats = append(stats, EndpointStat{
			Path:         r.OperationName,
			RequestCount: r.Total,
			AvgLatencyMs: r.AvgDuration,
			ErrorRate:    errRate,
		})
	}
	return stats
}

// timeRangeToSince converts a time range string (e.g. "last_hour") into
// a time.Time representing the start of that window.
func timeRangeToSince(timeRange string) time.Time {
	now := time.Now()
	switch timeRange {
	case "last_5m":
		return now.Add(-5 * time.Minute)
	case "last_15m":
		return now.Add(-15 * time.Minute)
	case "last_hour":
		return now.Add(-1 * time.Hour)
	case "last_6h":
		return now.Add(-6 * time.Hour)
	case "last_24h":
		return now.Add(-24 * time.Hour)
	case "last_7d":
		return now.Add(-7 * 24 * time.Hour)
	case "last_30d":
		return now.Add(-30 * 24 * time.Hour)
	default:
		return now.Add(-1 * time.Hour)
	}
}
