// Package middlewares – this file implements the Global Error Handler Middleware.
// This middleware acts as a safety net that catches any unhandled errors from route handlers.
// It runs AFTER the request handler and checks if any errors were recorded during processing.
// If errors exist, it logs them and returns a structured error response to the client.
//
// The flow is:
//
//	Client Request → Other Middleware → Handler → ErrorHandler (catches any errors)
//
// This ensures that the API always returns a consistent JSON error format,
// even if a handler encounters an unexpected error.
package middlewares

import (
	"log"      // Standard Go logging package – writes error details to the server log
	"net/http" // Standard HTTP library – provides status codes like 500 Internal Server Error

	"github.com/gin-gonic/gin" // Gin web framework – provides the error collection mechanism
)

// ErrorHandler creates a Gin middleware function that catches unhandled errors.
// It should be one of the first middleware in the chain so it can catch errors
// from all subsequent handlers.
// Usage in router: router.Use(ErrorHandler())
func ErrorHandler() gin.HandlerFunc {
	// Return a closure that Gin calls for each request
	return func(c *gin.Context) {

		// ── Pass control to the next handler first ──
		// c.Next() runs all subsequent middleware and the route handler.
		// Any errors they add using c.Error() are collected in c.Errors.
		c.Next()

		// ── After the handler has finished, check for errors ──

		// c.Errors is a slice of errors that handlers added during processing.
		// If any handler called c.Error(err), those errors are captured here.
		if len(c.Errors) > 0 {
			// Get the most recent error (last one added)
			err := c.Errors.Last()

			// Log the error to the server console for debugging
			log.Printf("Error: %v", err.Error())

			// Return a structured JSON error response to the client.
			// This ensures all error responses have a consistent format.
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":     "Internal server error",   // Generic error message for the client (don't leak internal details)
				"details":   err.Error(),               // Specific error details for debugging
				"timestamp": c.GetTime("request_time"), // When the request started (set by RequestLogger middleware)
			})
		}
	}
}
