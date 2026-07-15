package api

import (
	"context"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/models"
)

// ClientProxyOptions fetches the selectable proxy nodes (public, no token).
// Entries with an empty URL are dropped. When the server returns nothing, a
// single fallback node is returned so callers always have at least one option.
func (c *Client) ClientProxyOptions(ctx context.Context) ([]models.ClientProxyOption, error) {
	var raw []models.ClientProxyOption
	if err := c.getJSON(ctx, "/app/configs/client-proxy", "", &raw); err != nil {
		return nil, err
	}

	options := make([]models.ClientProxyOption, 0, len(raw))
	for _, o := range raw {
		if o.URL == "" {
			continue
		}
		options = append(options, o)
	}
	if len(options) == 0 {
		options = append(options, models.ClientProxyOption{Name: "default", URL: app.FallbackProxyURL})
	}
	return options, nil
}
