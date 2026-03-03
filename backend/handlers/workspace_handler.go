// Package handlers – this file contains the WorkspaceHandler which manages
// workspace CRUD operations (Create, Read, Update, Delete).
// Workspaces are the top-level organizational unit in Tracely.
// Each workspace belongs to an owner and can have multiple members with different roles (RBAC).
// All workspace operations verify user identity through JWT authentication.
package handlers

import (
	"backend/middlewares" // Custom middleware – extracts authenticated user ID from JWT context
	"backend/services"    // Business logic layer – WorkspaceService handles workspace database operations
	"net/http"            // Standard HTTP library – provides status codes (200, 201, 204, 400, 401, 404, 500)

	"github.com/gin-gonic/gin" // Gin web framework for HTTP routing and request handling
	"github.com/google/uuid"   // UUID library – used to parse and validate workspace IDs from URL params
)

// WorkspaceHandler groups all workspace-related HTTP handlers.
// It depends on WorkspaceService, which enforces RBAC (Role-Based Access Control)
// by checking if the requesting user has permission to access each workspace.
type WorkspaceHandler struct {
	workspaceService *services.WorkspaceService // Reference to the workspace business logic service
}

// NewWorkspaceHandler is a constructor that creates a WorkspaceHandler.
// It uses dependency injection to receive the WorkspaceService.
func NewWorkspaceHandler(workspaceService *services.WorkspaceService) *WorkspaceHandler {
	return &WorkspaceHandler{workspaceService: workspaceService}
}

// CreateWorkspaceRequest defines the expected JSON body for creating a workspace.
// The "name" field is required, while "description" is optional.
type CreateWorkspaceRequest struct {
	Name        string `json:"name" binding:"required"` // Workspace name – must be provided
	Description string `json:"description"`             // Optional description of the workspace
}

// Create handles POST /api/v1/workspaces
// It creates a new workspace owned by the authenticated user.
// The user is automatically added as an "admin" member of the workspace (RBAC).
func (h *WorkspaceHandler) Create(c *gin.Context) {
	// Step 1: Extract the authenticated user's ID from the JWT token in the request context.
	// This is set by the AuthMiddleware that runs before this handler.
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		// If user ID is missing, the request is unauthorized
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Step 2: Parse and validate the JSON request body
	var req CreateWorkspaceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// Return HTTP 400 if the JSON is invalid or "name" is missing
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Step 3: Call the WorkspaceService to create the workspace in the database.
	// The service sets the owner_id to the authenticated user and saves it.
	workspace, err := h.workspaceService.Create(req.Name, req.Description, userID)
	if err != nil {
		// Return HTTP 500 if the database operation fails
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Step 4: Return HTTP 201 Created with the new workspace object
	c.JSON(http.StatusCreated, workspace)
}

// GetAll handles GET /api/v1/workspaces
// It returns all workspaces that the authenticated user is a member of.
// This enforces RBAC – users only see workspaces they belong to.
func (h *WorkspaceHandler) GetAll(c *gin.Context) {
	// Extract the authenticated user's ID from the JWT context
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Fetch all workspaces where this user is a member (owner, admin, or member role)
	workspaces, err := h.workspaceService.GetAll(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return the list of workspaces wrapped in a "workspaces" key
	c.JSON(http.StatusOK, gin.H{"workspaces": workspaces})
}

// GetByID handles GET /api/v1/workspaces/:workspace_id
// It returns a single workspace if the authenticated user has access to it (RBAC check).
func (h *WorkspaceHandler) GetByID(c *gin.Context) {
	// Extract the authenticated user's ID
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse the workspace_id from the URL path parameter and validate it's a valid UUID.
	// Example URL: /api/v1/workspaces/550e8400-e29b-41d4-a716-446655440000
	workspaceID, err := uuid.Parse(c.Param("workspace_id"))
	if err != nil {
		// Return HTTP 400 if the ID is not a valid UUID format
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workspace ID"})
		return
	}

	// Fetch the workspace – the service checks that the user has access (RBAC enforcement)
	workspace, err := h.workspaceService.GetByID(workspaceID, userID)
	if err != nil {
		// Return HTTP 404 if the workspace doesn't exist or user lacks access
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	// Return the workspace details
	c.JSON(http.StatusOK, workspace)
}

// Update handles PUT /api/v1/workspaces/:workspace_id
// It updates a workspace's name and/or description.
// Only users with access to the workspace can update it (RBAC check in service layer).
func (h *WorkspaceHandler) Update(c *gin.Context) {
	// Extract the authenticated user's ID
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse and validate the workspace_id from the URL
	workspaceID, err := uuid.Parse(c.Param("workspace_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workspace ID"})
		return
	}

	// Parse the updated workspace data from the request body
	var req CreateWorkspaceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Call the service to update the workspace – includes RBAC access check
	workspace, err := h.workspaceService.Update(workspaceID, userID, req.Name, req.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return HTTP 200 OK with the updated workspace
	c.JSON(http.StatusOK, workspace)
}

// Delete handles DELETE /api/v1/workspaces/:workspace_id
// It permanently removes a workspace and all its associated data.
// Only users with access can delete (RBAC check in service layer).
func (h *WorkspaceHandler) Delete(c *gin.Context) {
	// Extract the authenticated user's ID
	userID, err := middlewares.GetUserID(c)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Parse and validate the workspace_id from the URL
	workspaceID, err := uuid.Parse(c.Param("workspace_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid workspace ID"})
		return
	}

	// Call the service to delete the workspace – includes RBAC access check
	if err := h.workspaceService.Delete(workspaceID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Return HTTP 204 No Content – standard response for successful deletion with no body
	c.Status(http.StatusNoContent)
}
