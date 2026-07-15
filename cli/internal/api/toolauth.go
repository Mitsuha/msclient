package api

import (
	"context"
	"encoding/json"
)

// CodexAuth requests MirrorStages Codex credentials billed against userPackID
// (0 = pay-as-you-go). The raw JSON object is returned verbatim; it is written
// as-is to ~/.codex/auth.json.
func (c *Client) CodexAuth(ctx context.Context, token string, userPackID int) (json.RawMessage, error) {
	return c.toolAuth(ctx, "/user/codex-auth", token, userPackID)
}

// ClaudeAuth requests MirrorStages Claude credentials billed against
// userPackID (0 = pay-as-you-go). The raw JSON object (containing
// claudeAiOauth, oauthAccount, userID, machineID) is returned verbatim.
func (c *Client) ClaudeAuth(ctx context.Context, token string, userPackID int) (json.RawMessage, error) {
	return c.toolAuth(ctx, "/user/claude-auth", token, userPackID)
}

func (c *Client) toolAuth(ctx context.Context, path, token string, userPackID int) (json.RawMessage, error) {
	body := map[string]int{"user_pack_id": userPackID}
	var out json.RawMessage
	if err := c.postJSON(ctx, path, token, body, &out); err != nil {
		return nil, err
	}
	return out, nil
}
