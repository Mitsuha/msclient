// Package api is a thin HTTP client for the MirrorStages backend. It mirrors
// desktop/lib/core/api/api_client.dart: JSON bodies, a fixed Accept-Language,
// and per-call Bearer auth.
package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/mirrorstages/mstages/internal/app"
)

// Client talks to the MirrorStages API. The zero value is not usable; use New.
type Client struct {
	baseURL string
	http    *http.Client
}

// New returns a Client targeting the production API base URL.
func New() *Client {
	return &Client{
		baseURL: app.APIBaseURL,
		http:    &http.Client{Timeout: 30 * time.Second},
	}
}

// Error is a non-2xx API response.
type Error struct {
	StatusCode int
	Err        string
	Message    string
}

func (e *Error) Error() string {
	if e.Message != "" {
		return fmt.Sprintf("api %d: %s", e.StatusCode, e.Message)
	}
	if e.Err != "" {
		return fmt.Sprintf("api %d: %s", e.StatusCode, e.Err)
	}
	return fmt.Sprintf("api %d", e.StatusCode)
}

// Unauthorized reports whether the error is an HTTP 401.
func (e *Error) Unauthorized() bool { return e.StatusCode == http.StatusUnauthorized }

func (c *Client) url(path string) string {
	return c.baseURL + path
}

// do performs a request. body, when non-nil, is JSON-encoded. token, when
// non-empty, is sent as a Bearer credential. The decoded response is written
// into out (which may be nil to discard the body).
func (c *Client) do(ctx context.Context, method, path, token string, body, out any) error {
	var reader io.Reader
	hasBody := body != nil
	if hasBody {
		buf, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(buf)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.url(path), reader)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Accept-Language", "zh-CN")
	if hasBody {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		apiErr := &Error{StatusCode: resp.StatusCode}
		var envelope struct {
			Error   string `json:"error"`
			Message string `json:"message"`
		}
		if json.Unmarshal(raw, &envelope) == nil {
			apiErr.Err = envelope.Error
			apiErr.Message = envelope.Message
		}
		return apiErr
	}

	if out == nil {
		return nil
	}
	if len(strings.TrimSpace(string(raw))) == 0 {
		return nil
	}
	return json.Unmarshal(raw, out)
}

// postJSON issues a POST expecting a JSON object response.
func (c *Client) postJSON(ctx context.Context, path, token string, body, out any) error {
	return c.do(ctx, http.MethodPost, path, token, body, out)
}

// getJSON issues a GET expecting a JSON response.
func (c *Client) getJSON(ctx context.Context, path, token string, out any) error {
	return c.do(ctx, http.MethodGet, path, token, nil, out)
}
