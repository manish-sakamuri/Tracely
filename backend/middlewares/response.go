// Package middlewares – response.go provides a centralized, consistent
// JSON error/success response format used across all handlers.
package middlewares

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// APIResponse is the standardized response envelope returned by every endpoint.
type APIResponse struct {
	// Success indicates whether the request completed without errors.
	Success bool `json:"success"`
	// Data holds the payload for successful responses (omitted on errors).
	Data interface{} `json:"data,omitempty"`
	// Error holds a human-readable error message (omitted on success).
	Error string `json:"error,omitempty"`
	// Code is a machine-readable error code for the frontend to branch on.
	Code string `json:"code,omitempty"`
}

// RespondSuccess sends a 200 OK with a standardized success envelope.
func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, APIResponse{
		Success: true,
		Data:    data,
	})
}

// RespondCreated sends a 201 Created with a standardized success envelope.
func RespondCreated(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, APIResponse{
		Success: true,
		Data:    data,
	})
}

// RespondError sends an error response with the given HTTP status, message,
// and an optional machine-readable error code.
func RespondError(c *gin.Context, status int, message string, code string) {
	c.JSON(status, APIResponse{
		Success: false,
		Error:   message,
		Code:    code,
	})
}

// RespondBadRequest is a convenience wrapper for 400 errors.
func RespondBadRequest(c *gin.Context, message string) {
	RespondError(c, http.StatusBadRequest, message, "BAD_REQUEST")
}

// RespondUnauthorized is a convenience wrapper for 401 errors.
func RespondUnauthorized(c *gin.Context, message string) {
	RespondError(c, http.StatusUnauthorized, message, "UNAUTHORIZED")
}

// RespondForbidden is a convenience wrapper for 403 errors.
func RespondForbidden(c *gin.Context, message string) {
	RespondError(c, http.StatusForbidden, message, "FORBIDDEN")
}

// RespondNotFound is a convenience wrapper for 404 errors.
func RespondNotFound(c *gin.Context, message string) {
	RespondError(c, http.StatusNotFound, message, "NOT_FOUND")
}

// RespondInternalError is a convenience wrapper for 500 errors.
func RespondInternalError(c *gin.Context, message string) {
	RespondError(c, http.StatusInternalServerError, message, "INTERNAL_ERROR")
}
