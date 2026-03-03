// Package middlewares – this file implements the JWT Authentication Middleware.
// Middleware is code that runs BEFORE the actual handler for every protected API route.
// This middleware:
//  1. Checks that the request has an Authorization header with a Bearer token
//  2. Validates the JWT token (checks signature and expiration)
//  3. Extracts the user ID from the token and stores it in the request context
//  4. If any check fails, the request is rejected with HTTP 401 Unauthorized
//
// The flow is: Client Request → AuthMiddleware → Handler (only if token is valid)
package middlewares

import (
	"net/http" // Standard HTTP library – provides status codes and error types
	"strings"  // Standard string utilities – used to split the "Bearer <token>" header

	"backend/services" // Business logic layer – AuthService validates the JWT token

	"github.com/gin-gonic/gin" // Gin web framework – provides context and middleware patterns
	"github.com/google/uuid"   // UUID library – parses the user ID from the JWT claims
)

// AuthMiddleware creates a Gin middleware function that protects API routes.
// It takes an AuthService as a parameter because it needs to validate JWT tokens.
// Usage in router: router.Use(AuthMiddleware(authService))
// All routes registered after this middleware will require a valid JWT token.
func AuthMiddleware(authService *services.AuthService) gin.HandlerFunc {
	// Return a closure (anonymous function) that Gin will call for each request
	return func(c *gin.Context) {

		// ── Step 1: Check for the Authorization header ──
		// Every authenticated request must include: "Authorization: Bearer <token>"
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			// No Authorization header found – reject the request
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Authorization header required",
			})
			c.Abort() // Stop the middleware chain – don't let the request reach the handler
			return
		}

		// ── Step 2: Extract the token from the "Bearer <token>" format ──
		// Split the header value by spaces: ["Bearer", "<actual-token>"]
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			// Header format is wrong – it should be exactly "Bearer <token>"
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid authorization header format",
			})
			c.Abort() // Stop processing
			return
		}

		// ── Step 3: Validate the JWT token ──
		token := parts[1] // The actual JWT token string
		// Call the AuthService to verify the token's signature and check if it's expired
		claims, err := authService.ValidateToken(token)
		if err != nil {
			// Token is invalid (expired, tampered with, or malformed)
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired token",
			})
			c.Abort() // Stop processing
			return
		}

		// ── Step 4: Extract and store the user ID in the request context ──
		// Parse the user ID string from the JWT claims into a UUID type
		userID, err := uuid.Parse(claims.UserID)
		if err != nil {
			// The user ID in the token is not a valid UUID (shouldn't happen normally)
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid user ID in token",
			})
			c.Abort() // Stop processing
			return
		}

		// Store the user ID and email in the Gin context.
		// Subsequent handlers can retrieve these using c.Get("user_id") or middlewares.GetUserID(c).
		c.Set("user_id", userID)          // Store user UUID for use in handlers
		c.Set("user_email", claims.Email) // Store user email for use in handlers

		// ── Step 5: Continue to the next middleware or handler ──
		// c.Next() passes control to the next item in the middleware chain.
		// If we reach this point, the token is valid and the request is authenticated.
		c.Next()
	}
}

// GetUserID is a helper function that retrieves the authenticated user's ID
// from the Gin request context. This is set by the AuthMiddleware above.
// Handlers call this to get the user ID without parsing the JWT themselves.
// Returns the user's UUID and an error if the ID is not in the context.
func GetUserID(c *gin.Context) (uuid.UUID, error) {
	// Look up the "user_id" value that was set by AuthMiddleware
	userID, exists := c.Get("user_id")
	if !exists {
		// User ID not found in context – request likely didn't go through AuthMiddleware
		return uuid.Nil, http.ErrNoCookie // Returns an error indicating missing auth data
	}
	// Type-assert the value to uuid.UUID (it was stored as this type by AuthMiddleware)
	return userID.(uuid.UUID), nil
}
