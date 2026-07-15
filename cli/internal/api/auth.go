package api

import (
	"context"
	"strings"

	"github.com/mirrorstages/mstages/internal/models"
)

// Login authenticates with an account (email or phone) and password. The
// account is treated as an email when it contains '@', otherwise as a phone
// number — matching the desktop app's dispatch heuristic.
func (c *Client) Login(ctx context.Context, account, password string) (*models.LoginResult, error) {
	payload := map[string]string{"password": password}
	if strings.Contains(account, "@") {
		payload["email"] = account
	} else {
		payload["phone"] = account
	}

	var result models.LoginResult
	if err := c.postJSON(ctx, "/auth/login", "", payload, &result); err != nil {
		return nil, err
	}
	return &result, nil
}
