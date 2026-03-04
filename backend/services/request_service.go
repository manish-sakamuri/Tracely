/*
Package services contains business logic for the application.
This file implements the RequestService, which handles CRUD operations
for API requests, executing them, and retrieving execution history.
It also enforces workspace access control via WorkspaceService.
*/
package services

import (
	"backend/models"
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// RequestService handles operations on requests and their executions.
type RequestService struct {
	db               *gorm.DB
	workspaceService *WorkspaceService
}

// NewRequestService creates a new RequestService instance with DB connection.
func NewRequestService(db *gorm.DB) *RequestService {
	return &RequestService{
		db:               db,
		workspaceService: NewWorkspaceService(db),
	}
}

// Create adds a new request to a collection, enforcing workspace access.
func (s *RequestService) Create(
	collectionID uuid.UUID, name, method, url, headers, queryParams, body, description string, userID uuid.UUID,
) (*models.Request, error) {

	// Check if collection exists
	var collection models.Collection
	if err := s.db.First(&collection, collectionID).Error; err != nil {
		return nil, err
	}

	// Verify user has access to the workspace
	if !s.workspaceService.HasAccess(collection.WorkspaceID, userID) {
		return nil, errors.New("access denied")
	}

	// Create request object
	request := models.Request{
		Name:         name,
		Method:       method,
		URL:          url,
		Headers:      headers,
		QueryParams:  queryParams,
		Body:         body,
		Description:  description,
		CollectionID: collectionID,
	}

	// Save to DB
	if err := s.db.Create(&request).Error; err != nil {
		return nil, err
	}

	// Update collection's request count
	s.db.Model(&collection).Update("request_count", gorm.Expr("request_count + ?", 1))

	return &request, nil
}

// GetByID retrieves a request by ID and verifies workspace access.
func (s *RequestService) GetByID(requestID, userID uuid.UUID) (*models.Request, error) {
	var request models.Request
	if err := s.db.Preload("Collection").First(&request, requestID).Error; err != nil {
		return nil, err
	}

	// Check access
	if !s.workspaceService.HasAccess(request.Collection.WorkspaceID, userID) {
		return nil, errors.New("access denied")
	}

	return &request, nil
}

// Update modifies fields of a request after verifying access.
func (s *RequestService) Update(requestID, userID uuid.UUID, updates map[string]interface{}) (*models.Request, error) {
	request, err := s.GetByID(requestID, userID)
	if err != nil {
		return nil, err
	}

	if err := s.db.Model(request).Updates(updates).Error; err != nil {
		return nil, err
	}

	return request, nil
}

// Delete removes a request after verifying access.
func (s *RequestService) Delete(requestID, userID uuid.UUID) error {
	request, err := s.GetByID(requestID, userID)
	if err != nil {
		return err
	}

	return s.db.Delete(request).Error
}

// Execute sends an HTTP request based on stored request data and optional overrides.
// It records execution time, response, and trace/span IDs.
func (s *RequestService) Execute(
	requestID, userID uuid.UUID,
	overrideURL string,
	overrideHeaders map[string]string,
	traceID uuid.UUID,
	spanID, parentSpanID *uuid.UUID,
) (*models.Execution, error) {

	request, err := s.GetByID(requestID, userID)
	if err != nil {
		return nil, err
	}

	startTime := time.Now() // Track execution start

	// Determine URL to use
	url := request.URL
	if overrideURL != "" {
		url = overrideURL
	}

	// Prepare request body
	var reqBody io.Reader
	if request.Body != "" {
		reqBody = bytes.NewBufferString(request.Body)
	}

	// Create HTTP request
	httpReq, err := http.NewRequest(request.Method, url, reqBody)
	if err != nil {
		return nil, err
	}

	// Set headers from request
	var headers map[string]string
	if request.Headers != "" {
		json.Unmarshal([]byte(request.Headers), &headers)
		for k, v := range headers {
			httpReq.Header.Set(k, v)
		}
	}

	// Apply override headers
	for k, v := range overrideHeaders {
		httpReq.Header.Set(k, v)
	}

	// Add trace and span IDs
	if traceID != uuid.Nil {
		httpReq.Header.Set("X-Trace-ID", traceID.String())
	}
	if spanID == nil || *spanID == uuid.Nil {
		newSpanID := uuid.New()
		spanID = &newSpanID
	}
	httpReq.Header.Set("X-Span-ID", spanID.String())
	if parentSpanID != nil && *parentSpanID != uuid.Nil {
		httpReq.Header.Set("X-Parent-Span-ID", parentSpanID.String())
	}

	// Execute HTTP request
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(httpReq)
	responseTime := time.Since(startTime).Milliseconds() // Measure response time

	// Record execution details
	execution := models.Execution{
		RequestID:      requestID,
		ResponseTimeMs: responseTime,
		TraceID:        traceID,
		SpanID:         spanID,
		ParentSpanID:   parentSpanID,
		Timestamp:      startTime,
	}

	if err != nil {
		// Error during request execution
		execution.ErrorMessage = err.Error()
		execution.StatusCode = 0
	} else {
		defer resp.Body.Close()
		execution.StatusCode = resp.StatusCode

		// Capture response body
		bodyBytes, _ := io.ReadAll(resp.Body)
		execution.ResponseBody = string(bodyBytes)

		// Save response headers
		headersJSON, _ := json.Marshal(resp.Header)
		execution.ResponseHeaders = string(headersJSON)
	}

	// Persist execution record
	if err := s.db.Create(&execution).Error; err != nil {
		return nil, err
	}

	// Get collection and workspace info for trace
	var collection models.Collection
	s.db.First(&collection, request.CollectionID)

	// Create Trace record
	status := "success"
	if execution.StatusCode >= 400 || execution.ErrorMessage != "" {
		status = "error"
	}

	trace := models.Trace{
		ID:              traceID,
		WorkspaceID:     collection.WorkspaceID,
		ServiceName:     request.Name,
		SpanCount:       1,
		TotalDurationMs: float64(responseTime),
		StartTime:       startTime,
		EndTime:         time.Now(),
		Status:          status,
	}

	if err := s.db.Create(&trace).Error; err != nil {
		// Log but don't fail - execution was already saved
		return &execution, nil
	}

	// Create Span record
	span := models.Span{
		ID:            *spanID,
		TraceID:       traceID,
		ParentSpanID:  parentSpanID,
		OperationName: request.Name,
		ServiceName:   request.Name,
		StartTime:     startTime,
		DurationMs:    float64(responseTime),
		Status:        "ok",
	}

	// Add response status as tags
	tagsData := map[string]interface{}{
		"http.method":           request.Method,
		"http.url":              url,
		"http.status_code":      execution.StatusCode,
		"execution.response_ms": responseTime,
	}
	tagsJSON, _ := json.Marshal(tagsData)
	span.Tags = string(tagsJSON)

	s.db.Create(&span)

	return &execution, nil
}

// QuickExecute sends an ad-hoc HTTP request and records its trace without requiring a saved request object.
func (s *RequestService) QuickExecute(
	workspaceID, userID uuid.UUID,
	method, url, body string,
	headers map[string]string,
) (*models.Execution, error) {

	// Verify user has access to the workspace
	if !s.workspaceService.HasAccess(workspaceID, userID) {
		log.Printf("[DEBUG] QuickExecute: Access denied for WorkspaceID=%s, UserID=%s", workspaceID, userID)
		return nil, errors.New("access denied")
	}
	log.Printf("[DEBUG] QuickExecute: Starting for %s %s", method, url)

	startTime := time.Now()
	traceID := uuid.New()
	spanID := uuid.New()

	// Prepare request body
	var reqBody io.Reader
	if body != "" {
		reqBody = bytes.NewBufferString(body)
	}

	// Create HTTP request
	httpReq, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		return nil, err
	}

	// Set headers
	for k, v := range headers {
		httpReq.Header.Set(k, v)
	}

	// Add trace and span IDs for propagation
	httpReq.Header.Set("X-Trace-ID", traceID.String())
	httpReq.Header.Set("X-Span-ID", spanID.String())

	// Execute HTTP request
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(httpReq)
	responseTime := time.Since(startTime).Milliseconds()

	// Record execution details
	execution := models.Execution{
		ResponseTimeMs: responseTime,
		TraceID:        traceID,
		SpanID:         &spanID,
		Timestamp:      startTime,
	}

	if err != nil {
		execution.ErrorMessage = err.Error()
		execution.StatusCode = 0
	} else {
		defer resp.Body.Close()
		execution.StatusCode = resp.StatusCode
		bodyBytes, _ := io.ReadAll(resp.Body)
		execution.ResponseBody = string(bodyBytes)
		headersJSON, _ := json.Marshal(resp.Header)
		execution.ResponseHeaders = string(headersJSON)
	}

	// Create Trace record
	status := "success"
	if execution.StatusCode >= 400 || execution.ErrorMessage != "" {
		status = "error"
	}

	// For quick execute, we use the URL as the service name if no name is provided
	serviceName := "Ad-hoc Request"
	if len(url) > 30 {
		serviceName = url[:27] + "..."
	} else {
		serviceName = url
	}

	trace := models.Trace{
		ID:              traceID,
		WorkspaceID:     workspaceID,
		ServiceName:     serviceName,
		SpanCount:       1,
		TotalDurationMs: float64(responseTime),
		StartTime:       startTime,
		EndTime:         time.Now(),
		Status:          status,
	}

	log.Printf("[DEBUG] QuickExecute: Creating Trace ID=%s", traceID)
	if err := s.db.Create(&trace).Error; err != nil {
		log.Printf("[ERROR] QuickExecute: Failed to create Trace: %v", err)
		return nil, err
	}

	// Create Span record
	span := models.Span{
		ID:            spanID,
		TraceID:       traceID,
		OperationName: method + " " + url,
		ServiceName:   serviceName,
		StartTime:     startTime,
		DurationMs:    float64(responseTime),
		Status:        "ok",
		Logs:          "[]", // Valid empty JSON array for logs
	}

	tagsData := map[string]interface{}{
		"http.method":           method,
		"http.url":              url,
		"http.status_code":      execution.StatusCode,
		"execution.response_ms": responseTime,
		"request.type":          "quick_execute",
	}
	tagsJSON, _ := json.Marshal(tagsData)
	span.Tags = string(tagsJSON)

	log.Printf("[DEBUG] QuickExecute: Creating Span ID=%s", spanID)
	if err := s.db.Create(&span).Error; err != nil {
		log.Printf("[ERROR] QuickExecute: Failed to create Span: %v", err)
		return nil, err
	}
	log.Printf("[DEBUG] QuickExecute: Successfully completed")

	return &execution, nil
}

// GetHistory retrieves a paginated list of executions for a request.
func (s *RequestService) GetHistory(requestID, userID uuid.UUID, limit, offset int) ([]models.Execution, int64, error) {
	request, err := s.GetByID(requestID, userID)
	if err != nil {
		return nil, 0, err
	}

	var executions []models.Execution
	var total int64

	// Get total executions count
	s.db.Model(&models.Execution{}).Where("request_id = ?", request.ID).Count(&total)

	// Fetch paginated executions
	err = s.db.Where("request_id = ?", request.ID).
		Order("timestamp DESC").
		Limit(limit).
		Offset(offset).
		Find(&executions).Error

	return executions, total, err
}
