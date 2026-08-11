// Package jwt decodes JWT payloads without verifying signatures. It mirrors
// desktop/lib/core/utils/jwt.dart: the tokens come from our own backend over
// TLS and are only read for display, never trusted for authorization.
package jwt

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"strconv"
	"strings"
)

// ErrMalformed is returned when the token is not a three-part JWT.
var ErrMalformed = errors.New("malformed jwt")

// DecodePayload returns the token's claims. The signature is not checked and
// exp is not enforced, matching the desktop client.
func DecodePayload(token string) (map[string]any, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, ErrMalformed
	}
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return nil, err
	}
	claims := map[string]any{}
	if err := json.Unmarshal(raw, &claims); err != nil {
		return nil, err
	}
	return claims, nil
}

// String reads a string claim, returning "" when absent or of another type.
func String(claims map[string]any, key string) string {
	s, _ := claims[key].(string)
	return s
}

// Int reads a numeric claim. JSON numbers decode as float64, but the backend
// also emits some ids as strings, so both are accepted. The second result
// reports whether the claim was present and numeric.
func Int(claims map[string]any, key string) (int, bool) {
	switch v := claims[key].(type) {
	case float64:
		return int(v), true
	case string:
		n, err := strconv.Atoi(v)
		if err != nil {
			return 0, false
		}
		return n, true
	}
	return 0, false
}

// Object reads a nested object claim, returning nil when absent.
func Object(claims map[string]any, key string) map[string]any {
	m, _ := claims[key].(map[string]any)
	return m
}
