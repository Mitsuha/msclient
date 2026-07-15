package auth

import (
	"context"

	"github.com/mirrorstages/mstages/internal/api"
)

// Login authenticates with the backend and persists the resulting session.
func Login(ctx context.Context, account, password string) (*Credentials, error) {
	client := api.New()
	result, err := client.Login(ctx, account, password)
	if err != nil {
		return nil, err
	}
	creds := &Credentials{Token: result.Token, User: result.User}
	if err := Save(creds); err != nil {
		return nil, err
	}
	return creds, nil
}
