// Package middlewares – this file implements the Request Logger Middleware.
// This middleware logs every incoming HTTP request with useful debugging information:
// HTTP method, URL path, client IP, response status code, processing duration,
// and distributed tracing IDs (trace_id, span_id, parent_span_id).
//
// The middleware runs BEFORE and AFTER the request handler:
//   - BEFORE: Records the start time
//   - AFTER: Calculates the duration and logs all request details
//
// This is essential for debugging, performance monitoring, and observability.
package middlewares

import (
	"log"  // Standard Go logging package – writes log messages to stdout/stderr
	"time" // Standard time package – used to measure request processing duration

	"github.com/gin-gonic/gin" // Gin web framework – provides the middleware pattern
)

// RequestLogger creates a Gin middleware function that logs every HTTP request.
// It measures how long each request takes to process and logs a structured log line
// with all relevant details for debugging and monitoring.
// Usage in router: router.Use(RequestLogger())
func RequestLogger() gin.HandlerFunc {
	// Return a closure that Gin calls for each incoming request
	return func(c *gin.Context) {

		// ── BEFORE the request handler ──

		// Record the exact time when the request arrived
		startTime := time.Now()

		// Store the start time in the Gin context so other middleware/handlers
		// can access it (e.g., the error handler uses it for the timestamp)
		c.Set("request_time", startTime)

		// ── Pass control to the next handler in the chain ──
		// c.Next() calls the actual route handler (and any remaining middleware).
		// Everything below this line runs AFTER the handler has finished.
		c.Next()

		// ── AFTER the request handler ──

		// Calculate how long the request took to process
		duration := time.Since(startTime) // e.g., "2.5ms", "150µs"

		// Log a structured message with all request details.
		// Format: [METHOD] /path client_ip - Status: 200 - Duration: 2.5ms - TraceID: ... - SpanID: ... - ParentSpanID: ...
		log.Printf(
			"[%s] %s %s - Status: %d - Duration: %v - TraceID: %s - SpanID: %s - ParentSpanID: %s",
			c.Request.Method,              // HTTP method: GET, POST, PUT, DELETE, etc.
			c.Request.URL.Path,            // The URL path that was requested (e.g., /api/v1/workspaces)
			c.ClientIP(),                  // The IP address of the client making the request
			c.Writer.Status(),             // The HTTP status code returned by the handler (e.g., 200, 404, 500)
			duration,                      // How long the request took to process
			c.GetString("trace_id"),       // Distributed tracing ID (links related requests across services)
			c.GetString("span_id"),        // Span ID (identifies this specific operation within a trace)
			c.GetString("parent_span_id"), // Parent span ID (the operation that triggered this one)
		)
	}
}
