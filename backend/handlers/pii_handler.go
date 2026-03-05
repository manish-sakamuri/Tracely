package handlers

import (
	"backend/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type PIIHandler struct {
	masker *utils.PIIMasker
}

func NewPIIHandler() *PIIHandler {
	return &PIIHandler{
		masker: utils.NewPIIMasker(),
	}
}

type MaskPIIRequest struct {
	Body    string            `json:"body"`
	Headers map[string]string `json:"headers"`
}

func (h *PIIHandler) Mask(c *gin.Context) {
	var req MaskPIIRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	maskedBody := ""
	if req.Body != "" {
		maskedBody = h.masker.MaskJSON(req.Body)
	}

	maskedHeaders := map[string]string{}
	if req.Headers != nil {
		maskedHeaders = h.masker.MaskHeaders(req.Headers)
	}

	c.JSON(http.StatusOK, gin.H{
		"body":    maskedBody,
		"headers": maskedHeaders,
	})
}

