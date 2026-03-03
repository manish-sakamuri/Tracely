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

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// TestRunHandler exposes endpoints for test run management.
type TestRunHandler struct {
	testRunService *services.TestRunService
	userLogService *services.UserLogService
}

// NewTestRunHandler creates a handler with the required service dependencies.
func NewTestRunHandler(trs *services.TestRunService, uls *services.UserLogService) *TestRunHandler {
	return &TestRunHandler{
		testRunService: trs,
		userLogService: uls,
	}
}

// CreateTestRun handles POST /test-runs. It parses the request body,
// associates the test run with the authenticated user, persists it,
// and creates an audit log entry.
func (h *TestRunHandler) CreateTestRun(c *gin.Context) {
	// Extract the authenticated user's ID from the JWT middleware context
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

	// Bind the incoming JSON body to the TestRun model
	var run models.TestRun
	if err := c.ShouldBindJSON(&run); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body: " + err.Error()})
		return
	}

	// Associate with the authenticated user
	run.UserID = userID

	// Default environment if not provided
	if run.Environment == "" {
		run.Environment = "production"
	}

	// Ensure jsonb fields have valid JSON defaults
	if run.Headers == "" {
		run.Headers = "{}"
	}

	// Persist the test run
	if err := h.testRunService.Create(&run); err != nil {
		log.Printf("[TestRunHandler] Failed to save test run: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save test run: " + err.Error()})
		return
	}

	// Create an audit log entry for the test run
	_ = h.userLogService.CreateLog(userID, "INFO",
		"Test run executed: "+run.Method+" "+run.URL+" → "+strconv.Itoa(run.StatusCode))

	c.JSON(http.StatusCreated, gin.H{"test_run": run})
}

// GetTestRuns handles GET /test-runs. It returns all test runs for the
// authenticated user, with optional pagination and environment filtering.
func (h *TestRunHandler) GetTestRuns(c *gin.Context) {
	// Extract authenticated user ID
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

	// Parse pagination parameters
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

	// Environment-based filtering
	environment := c.Query("environment")

	// Fetch test runs from the database
	runs, total, err := h.testRunService.GetByUser(userID, environment, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch test runs"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"test_runs": runs,
		"total":     total,
		"limit":     limit,
		"offset":    offset,
	})
}

// DeleteTestRun handles DELETE /test-runs/:id. It soft-deletes a test run
// owned by the authenticated user.
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
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}
