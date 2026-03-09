// Package middlewares – response_timer.go adds an X-Response-Time-Ms header
// to every response and stores the duration in the Gin context for downstream
// middleware (like TraceRecorder) to consume.
package middlewares

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
)

// ResponseTimer measures the total request duration and sets:
//   - Response header: X-Response-Time-Ms (integer milliseconds)
//   - Gin context key: response_time_ms (int64)
//
// This middleware must be registered before other middlewares so it captures
// the full request lifecycle.
func ResponseTimer() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		c.Next()

		durationMs := time.Since(start).Milliseconds()
		c.Header("X-Response-Time-Ms", fmt.Sprintf("%d", durationMs))
		c.Set("response_time_ms", durationMs)
	}
}
