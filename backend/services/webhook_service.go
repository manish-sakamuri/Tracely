package services

import (
	"encoding/json"
	"time"

	"backend/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type WebhookService struct {
	db *gorm.DB
}

func NewWebhookService(db *gorm.DB) *WebhookService {
	return &WebhookService{db: db}
}

// CreateWebhook creates a new webhook
func (s *WebhookService) CreateWebhook(workspaceID uuid.UUID, name, url, secret string, events []string) (*models.Webhook, error) {
	eventsJSON, _ := json.Marshal(events)

	webhook := models.Webhook{
		WorkspaceID: workspaceID,
		Name:        name,
		URL:         url,
		Secret:      secret,
		Events:      string(eventsJSON),
		Enabled:     true,
	}

	if err := s.db.Create(&webhook).Error; err != nil {
		return nil, err
	}

	return &webhook, nil
}

// TriggerWebhook triggers webhooks for an event
func (s *WebhookService) TriggerWebhook(workspaceID uuid.UUID, eventType string, payload map[string]interface{}) error {
	var webhooks []models.Webhook
	s.db.Where("workspace_id = ? AND enabled = true", workspaceID).Find(&webhooks)

	for _, webhook := range webhooks {
		// Check if webhook subscribes to this event
		var events []string
		json.Unmarshal([]byte(webhook.Events), &events)

		subscribed := false
		for _, e := range events {
			if e == eventType || e == "*" {
				subscribed = true
				break
			}
		}

		if !subscribed {
			continue
		}

		// Create webhook event
		payloadJSON, _ := json.Marshal(payload)
		event := models.WebhookEvent{
			WebhookID: webhook.ID,
			EventType: eventType,
			Payload:   string(payloadJSON),
			Status:    "pending",
		}

		s.db.Create(&event)

		// Send webhook async
		go s.sendWebhook(&webhook, &event)
	}

	return nil
}

func (s *WebhookService) sendWebhook(webhook *models.Webhook, event *models.WebhookEvent) {
	// Implementation would send HTTP POST to webhook.URL with event.Payload
	// For now, just mark as sent
	now := time.Now()
	s.db.Model(event).Updates(map[string]interface{}{
		"status":       "sent",
		"attempts":     event.Attempts + 1,
		"last_attempt": now,
	})
}
