package api

import (
	"context"

	"github.com/mirrorstages/mstages/internal/models"
)

// UserPacks fetches the caller's packs, keeping only the ones still billable.
// The status=1 query mirrors desktop/lib/data/api/user_pack_api.dart.
func (c *Client) UserPacks(ctx context.Context, token string) ([]models.UserPack, error) {
	var list models.UserPackList
	if err := c.getJSON(ctx, "/user/pack?status=1", token, &list); err != nil {
		return nil, err
	}

	packs := make([]models.UserPack, 0, len(list.Packs))
	for _, p := range list.Packs {
		if p.IsActive() {
			packs = append(packs, p)
		}
	}
	return packs, nil
}
