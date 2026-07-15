// Package auth persists the MirrorStages session and drives the login flow.
package auth

import (
	"encoding/json"
	"errors"
	"os"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/models"
)

// ErrNotLoggedIn is returned when no valid credentials are stored.
var ErrNotLoggedIn = errors.New("not logged in: run `mstages auth login` first")

// Credentials is the on-disk session: ~/.mstages/credentials.json.
type Credentials struct {
	Token string             `json:"token"`
	User  models.UserProfile `json:"user"`
}

// Load reads and validates the stored credentials. A missing file or an empty
// token yields ErrNotLoggedIn.
func Load() (*Credentials, error) {
	path, err := app.CredentialsPath()
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrNotLoggedIn
		}
		return nil, err
	}
	var creds Credentials
	if err := json.Unmarshal(raw, &creds); err != nil {
		return nil, ErrNotLoggedIn
	}
	if creds.Token == "" {
		return nil, ErrNotLoggedIn
	}
	return &creds, nil
}

// Save writes the credentials to ~/.mstages/credentials.json with 0600
// permissions (it holds a bearer token).
func Save(creds *Credentials) error {
	path, err := app.CredentialsPath()
	if err != nil {
		return err
	}
	raw, err := json.MarshalIndent(creds, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, raw, 0o600)
}

// Clear removes the stored credentials, e.g. after a 401.
func Clear() error {
	path, err := app.CredentialsPath()
	if err != nil {
		return err
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
