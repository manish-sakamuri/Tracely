/*
Package services contains business logic for the application.
This file implements the CollectionService, which provides CRUD operations
for collections within a workspace. Access control is enforced via WorkspaceService.
*/
package services

import (
	"backend/integrations"
	"backend/models"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// CollectionService provides methods to manage collections in a workspace.
type CollectionService struct {
	db               *gorm.DB
	workspaceService *WorkspaceService
}

// NewCollectionService creates a new CollectionService instance.
func NewCollectionService(db *gorm.DB) *CollectionService {
	return &CollectionService{
		db:               db,
		workspaceService: NewWorkspaceService(db),
	}
}

// Create creates a new collection in the specified workspace.
// Parameters:
// - workspaceID: ID of the workspace where collection is created
// - name: collection name
// - description: collection description
// - userID: ID of the user creating the collection
func (s *CollectionService) Create(workspaceID uuid.UUID, name, description string, userID uuid.UUID) (*models.Collection, error) {
	// Check if user has access to the workspace
	if !s.workspaceService.HasAccess(workspaceID, userID) {
		return nil, errors.New("access denied")
	}

	collection := models.Collection{
		Name:        name,
		Description: description,
		WorkspaceID: workspaceID,
	}

	// Save collection to database
	if err := s.db.Create(&collection).Error; err != nil {
		return nil, err
	}

	return &collection, nil
}

// GetAll retrieves all collections in a workspace for a user.
// Returns error if user does not have access.
func (s *CollectionService) GetAll(workspaceID, userID uuid.UUID) ([]models.Collection, error) {
	if !s.workspaceService.HasAccess(workspaceID, userID) {
		return nil, errors.New("access denied")
	}

	var collections []models.Collection
	err := s.db.Where("workspace_id = ?", workspaceID).Find(&collections).Error
	return collections, err
}

// GetByID retrieves a specific collection by ID.
// Returns error if user does not have access to the workspace.
func (s *CollectionService) GetByID(collectionID, userID uuid.UUID) (*models.Collection, error) {
	var collection models.Collection
	if err := s.db.First(&collection, collectionID).Error; err != nil {
		return nil, err
	}

	if !s.workspaceService.HasAccess(collection.WorkspaceID, userID) {
		return nil, errors.New("access denied")
	}

	return &collection, nil
}

// Update modifies the name and description of an existing collection.
// Returns error if the collection does not exist or user has no access.
func (s *CollectionService) Update(collectionID, userID uuid.UUID, name, description string) (*models.Collection, error) {
	var collection models.Collection
	if err := s.db.First(&collection, collectionID).Error; err != nil {
		return nil, err
	}

	// Check user access
	if !s.workspaceService.HasAccess(collection.WorkspaceID, userID) {
		return nil, errors.New("access denied")
	}

	// Update fields
	collection.Name = name
	collection.Description = description

	// Save updates
	if err := s.db.Save(&collection).Error; err != nil {
		return nil, err
	}

	return &collection, nil
}

// Delete removes a collection from the workspace.
// Returns error if user does not have access or collection does not exist.
func (s *CollectionService) Delete(collectionID, userID uuid.UUID) error {
	var collection models.Collection
	if err := s.db.First(&collection, collectionID).Error; err != nil {
		return err
	}

	// Verify access
	if !s.workspaceService.HasAccess(collection.WorkspaceID, userID) {
		return errors.New("access denied")
	}

	// Delete collection
	return s.db.Delete(&collection).Error
}

// ImportFromPostmanJSON creates a collection and requests from a Postman collection JSON payload.
// It enforces workspace access and uses the PostmanImporter to parse the payload.
func (s *CollectionService) ImportFromPostmanJSON(workspaceID, userID uuid.UUID, postmanJSON []byte) (*models.Collection, []models.Request, error) {
	// Check access to workspace
	if !s.workspaceService.HasAccess(workspaceID, userID) {
		return nil, nil, errors.New("access denied")
	}

	importer := integrations.NewPostmanImporter()
	collectionData, err := importer.ImportFromBytes(postmanJSON)
	if err != nil {
		return nil, nil, err
	}

	// Create the collection
	createdCollection, err := s.Create(workspaceID, collectionData.Info.Name, collectionData.Info.Description, userID)
	if err != nil {
		return nil, nil, err
	}

	requestService := NewRequestService(s.db)
	var createdRequests []models.Request

	for _, item := range collectionData.Item {
		headersMap := make(map[string]string)
		for _, h := range item.Request.Header {
			headersMap[h.Key] = h.Value
		}

		headersJSON, _ := json.Marshal(headersMap)

		reqModel, err := requestService.Create(
			createdCollection.ID,
			item.Name,
			item.Request.Method,
			item.Request.URL.Raw,
			string(headersJSON),
			"{}",
			item.Request.Body.Raw,
			"",
			userID,
		)
		if err != nil {
			return createdCollection, createdRequests, err
		}

		createdRequests = append(createdRequests, *reqModel)
	}

	return createdCollection, createdRequests, nil
}
