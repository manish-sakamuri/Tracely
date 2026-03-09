// Package handlers – test_run_handler.go provides HTTP handlers for
// creating and retrieving test run records. Each test run represents
// an HTTP request the user sent from the Tests screen and its result.
package handlers

import (
	"backend/models"
	"backend/services"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TestRunHandler exposes endpoints for test run management.
type TestRunHandler struct {
	testRunService *services.TestRunService
	userLogService *services.UserLogService
	db             *gorm.DB
}

// NewTestRunHandler creates a handler with the required service dependencies.
func NewTestRunHandler(trs *services.TestRunService, uls *services.UserLogService, db *gorm.DB) *TestRunHandler {
	return &TestRunHandler{
		testRunService: trs,
		userLogService: uls,
		db:             db,
	}
}

// CreateTestRun handles POST /test-runs. It parses the request body,
// associates the test run with the authenticated user, persists it,
// creates a linked trace record, and writes an audit log.
func (h *TestRunHandler) CreateTestRun(c *gin.Context) {
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

	var run models.TestRun
	if err := c.ShouldBindJSON(&run); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body: " + err.Error()})
		return
	}

	run.UserID = userID
	if run.Environment == "" {
		run.Environment = "production"
	}
	if run.Headers == "" {
		run.Headers = "{}"
	}

	if err := h.testRunService.Create(&run); err != nil {
		log.Printf("[TestRunHandler] Failed to save test run: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save test run: " + err.Error()})
		return
	}

	// ── Create a trace record linked to this test run ──
	go h.createTestRunTrace(userID, &run)

	// ── Rich audit log with metadata ──
	level := "INFO"
	if run.StatusCode >= 500 {
		level = "ERROR"
	} else if run.StatusCode >= 400 {
		level = "WARN"
	}
	metadata := fmt.Sprintf(
		`{"method":"%s","url":"%s","status_code":%d,"response_time_ms":%d,"test_run_id":"%s"}`,
		run.Method, run.URL, run.StatusCode, run.ResponseTimeMs, run.ID,
	)
	_ = h.userLogService.CreateLogWithMetadata(userID, level,
		fmt.Sprintf("Test run: %s %s → %d (%dms)", run.Method, run.URL, run.StatusCode, run.ResponseTimeMs),
		metadata,
	)

	c.JSON(http.StatusCreated, gin.H{"test_run": run})
}

// createTestRunTrace creates a Trace row from a completed test run.
func (h *TestRunHandler) createTestRunTrace(userID uuid.UUID, run *models.TestRun) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[TestRunHandler] trace creation panic: %v", r)
		}
	}()

	// Find the user's workspace
	var member models.WorkspaceMember
	if err := h.db.Where("user_id = ?", userID).First(&member).Error; err != nil {
		log.Printf("[TestRunHandler] no workspace for trace: %v", err)
		return
	}

	status := "success"
	if run.StatusCode >= 400 {
		status = "error"
	}

	now := time.Now()
	durationMs := float64(run.ResponseTimeMs)
	startTime := now.Add(-time.Duration(run.ResponseTimeMs) * time.Millisecond)

	trace := models.Trace{
		ID:              uuid.New(),
		WorkspaceID:     member.WorkspaceID,
		ServiceName:     "test-run",
		HttpMethod:      run.Method,
		Endpoint:        run.URL,
		StatusCode:      run.StatusCode,
		Source:          "test_run",
		SpanCount:       1,
		TotalDurationMs: durationMs,
		StartTime:       startTime,
		EndTime:         now,
		Status:          status,
	}

	if err := h.db.Create(&trace).Error; err != nil {
		log.Printf("[TestRunHandler] failed to create trace: %v", err)
		return
	}

	span := models.Span{
		ID:            uuid.New(),
		TraceID:       trace.ID,
		OperationName: fmt.Sprintf("%s %s", run.Method, run.URL),
		ServiceName:   "test-run",
		StartTime:     startTime,
		DurationMs:    durationMs,
		Tags:          fmt.Sprintf(`{"http.method":"%s","http.url":"%s","http.status_code":%d}`, run.Method, run.URL, run.StatusCode),
		Logs:          "[]",
		Status:        status,
	}

	if err := h.db.Create(&span).Error; err != nil {
		log.Printf("[TestRunHandler] failed to create span: %v", err)
	}
}

// GetTestRuns handles GET /test-runs with pagination and filtering.
func (h *TestRunHandler) GetTestRuns(c *gin.Context) {
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

	environment := c.Query("environment")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	runs, total, err := h.testRunService.GetByUser(userID, environment, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"test_runs": runs,
		"total":     total,
		"limit":     limit,
		"offset":    offset,
	})
}

// DeleteTestRun handles DELETE /test-runs/:id.
func (h *TestRunHandler) DeleteTestRun(c *gin.Context) {
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

	runID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid test run ID"})
		return
	}

	if err := h.testRunService.Delete(runID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Test run deleted"})
}
