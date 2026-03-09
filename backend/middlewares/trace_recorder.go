// Package middlewares – trace_recorder.go automatically records a Trace and
// root Span for every authenticated API request.
//
// SAFETY: All gin.Context values are captured into local variables BEFORE
// the goroutine starts. gin.Context must never be accessed inside a goroutine.
package middlewares

import (
	"fmt"
	"log"
	"strings"
	"time"

	"backend/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TraceRecorder creates a Gin middleware that records a Trace and root Span
// for every API request, storing real HTTP method, path, and status code.
//
// Internal read-only API calls (fetching workspaces, traces, collections,
// settings, etc.) are excluded because they add noise — the user wants to
// see traces of actual operations like test executions and mutations.
func TraceRecorder(db *gorm.DB) gin.HandlerFunc {
	// Paths that are pure data-fetch / admin. Recording these creates
	// the "all GET 200" noise the user sees on the Traces page.
	excludePrefixes := []string{
		"/api/v1/workspaces",    // listing workspaces
		"/api/v1/users",         // user settings / profile
		"/api/v1/notifications", // notification management
	}
	// Exact paths to exclude
	excludeExact := map[string]bool{
		"/health": true,
	}

	return func(c *gin.Context) {
		endpoint := c.Request.URL.Path
		method := c.Request.Method

		// Skip pure reads — they are internal app fetches, not user-initiated operations.
		// Only exclude GET requests; mutations (POST/PUT/DELETE/PATCH) are always recorded.
		if method == "GET" {
			if excludeExact[endpoint] {
				c.Next()
				return
			}
			for _, prefix := range excludePrefixes {
				if len(endpoint) >= len(prefix) && endpoint[:len(prefix)] == prefix {
					c.Next()
					return
				}
			}
		}

		// Also skip the POST /test-runs endpoint itself — the test run handler
		// creates its own trace with the actual external API status code.
		if method == "POST" && strings.HasSuffix(endpoint, "/test-runs") {
			c.Next()
			return
		}

		startTime := time.Now()

		c.Next()

		// ── Capture all values from gin.Context BEFORE the goroutine ──
		endTime := time.Now()
		durationMs := float64(endTime.Sub(startTime).Milliseconds())
		statusCode := c.Writer.Status()
		method = c.Request.Method
		endpoint = c.Request.URL.Path

		userIDStr, exists := c.Get("user_id")
		if !exists {
			return
		}
		userID, err := uuid.Parse(fmt.Sprintf("%v", userIDStr))
		if err != nil {
			return
		}

		wsParam := c.Param("workspace_id")

		// ── Goroutine: only uses captured primitives ──
		go func() {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("[TraceRecorder] panic recovered: %v", r)
				}
			}()

			var workspaceID uuid.UUID
			if wsParam != "" {
				parsed, err := uuid.Parse(wsParam)
				if err == nil {
					workspaceID = parsed
				}
			}
			if workspaceID == uuid.Nil {
				var member models.WorkspaceMember
				if err := db.Where("user_id = ?", userID).First(&member).Error; err == nil {
					workspaceID = member.WorkspaceID
				} else {
					return
				}
			}

			// Derive status from real HTTP status code
			status := "success"
			if statusCode >= 400 {
				status = "error"
			}

			traceID := uuid.New()
			trace := models.Trace{
				ID:              traceID,
				WorkspaceID:     workspaceID,
				ServiceName:     "tracely-api",
				HttpMethod:      method,
				Endpoint:        endpoint,
				StatusCode:      statusCode,
				Source:          "api",
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

			span := models.Span{
				ID:            uuid.New(),
				TraceID:       traceID,
				OperationName: fmt.Sprintf("%s %s", method, endpoint),
				ServiceName:   "tracely-api",
				StartTime:     startTime,
				DurationMs:    durationMs,
				Tags:          fmt.Sprintf(`{"http.method":"%s","http.url":"%s","http.status_code":%d}`, method, endpoint, statusCode),
				Logs:          "[]",
				Status:        status,
			}

			if err := db.Create(&span).Error; err != nil {
				log.Printf("[TraceRecorder] failed to create span: %v", err)
			}
		}()
	}
}
