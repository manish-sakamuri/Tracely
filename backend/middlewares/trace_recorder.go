// Package middlewares – trace_recorder.go automatically records a Trace and
// root Span for every authenticated API request. This populates the Traces
// screen with real data without requiring manual trace creation.
package middlewares

import (
	"fmt"
	"log"
	"time"

	"backend/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TraceRecorder creates a Gin middleware that automatically records a Trace
// and root Span for every API request that passes through protected routes.
// It captures method, endpoint, status code, duration, and workspace ID.
func TraceRecorder(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		startTime := time.Now()

		// Let the handler execute
		c.Next()

		// Record after handler finishes — don't block request
		go func() {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("[TraceRecorder] panic recovered: %v", r)
				}
			}()

			endTime := time.Now()
			durationMs := float64(endTime.Sub(startTime).Milliseconds())
			statusCode := c.Writer.Status()
			method := c.Request.Method
			endpoint := c.Request.URL.Path

			// Get user ID from context (set by auth middleware)
			userIDStr, exists := c.Get("user_id")
			if !exists {
				return // Skip unauthenticated requests
			}
			userID, err := uuid.Parse(fmt.Sprintf("%v", userIDStr))
			if err != nil {
				return
			}

			// Try to get workspace ID from route params
			var workspaceID uuid.UUID
			wsParam := c.Param("workspace_id")
			if wsParam != "" {
				parsed, err := uuid.Parse(wsParam)
				if err == nil {
					workspaceID = parsed
				}
			}
			// If no workspace in route, find user's first workspace
			if workspaceID == uuid.Nil {
				var member models.WorkspaceMember
				if err := db.Where("user_id = ?", userID).First(&member).Error; err == nil {
					workspaceID = member.WorkspaceID
				} else {
					return // No workspace — can't create trace
				}
			}

			// Determine status
			status := "success"
			if statusCode >= 400 {
				status = "error"
			}

			// Create the trace (matches models.Trace schema exactly)
			traceID := uuid.New()
			trace := models.Trace{
				ID:              traceID,
				WorkspaceID:     workspaceID,
				ServiceName:     "tracely-api",
				SpanCount:       1,
				TotalDurationMs: durationMs,
				StartTime:       startTime,
				EndTime:         endTime,
				Status:          status,
			}

			if err := db.Create(&trace).Error; err != nil {
				log.Printf("[TraceRecorder] failed to create trace: %v", err)
				return
			}

			// Create root span (matches models.Span schema exactly)
			span := models.Span{
				ID:            uuid.New(),
				TraceID:       traceID,
				OperationName: fmt.Sprintf("%s %s", method, endpoint),
				ServiceName:   "tracely-api",
				StartTime:     startTime,
				DurationMs:    durationMs,
				Tags:          "{}",
				Logs:          "[]",
				Status:        status,
			}

			if err := db.Create(&span).Error; err != nil {
				log.Printf("[TraceRecorder] failed to create span: %v", err)
			}
		}()
	}
}
