package jwt

import (
	"encoding/base64"
	"testing"
)

func makeToken(payload string) string {
	enc := base64.RawURLEncoding.EncodeToString([]byte(payload))
	return "header." + enc + ".signature"
}

func TestDecodePayload(t *testing.T) {
	token := makeToken(`{"email":"a@b.com","https://api.openai.com/auth":{"chatgpt_plan_type":"plus"}}`)
	claims, err := DecodePayload(token)
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if got := String(claims, "email"); got != "a@b.com" {
		t.Errorf("email = %q", got)
	}
	auth := Object(claims, "https://api.openai.com/auth")
	if auth == nil {
		t.Fatal("expected nested auth object")
	}
	if got := String(auth, "chatgpt_plan_type"); got != "plus" {
		t.Errorf("chatgpt_plan_type = %q", got)
	}
}

func TestDecodePayloadTolerantOfPadding(t *testing.T) {
	// Some issuers emit padded base64url; the decoder must accept both.
	enc := base64.URLEncoding.EncodeToString([]byte(`{"user_id":"7"}`))
	claims, err := DecodePayload("h." + enc + ".s")
	if err != nil {
		t.Fatalf("DecodePayload: %v", err)
	}
	if got := String(claims, "user_id"); got != "7" {
		t.Errorf("user_id = %q", got)
	}
}

func TestDecodePayloadRejectsMalformed(t *testing.T) {
	for _, token := range []string{"", "onlyone", "two.parts", "a.!!!.c"} {
		if _, err := DecodePayload(token); err == nil {
			t.Errorf("expected error for %q", token)
		}
	}
}

func TestStringAndObjectMissingKeys(t *testing.T) {
	claims := map[string]any{"n": 1}
	if String(claims, "n") != "" {
		t.Error("non-string claim should yield empty string")
	}
	if Object(claims, "missing") != nil {
		t.Error("missing object claim should yield nil")
	}
}

func TestInt(t *testing.T) {
	claims := map[string]any{"n": float64(42), "s": "42", "bad": "x", "obj": map[string]any{}}
	for key, want := range map[string]int{"n": 42, "s": 42} {
		got, ok := Int(claims, key)
		if !ok || got != want {
			t.Errorf("Int(%q) = (%d, %v), want (%d, true)", key, got, ok, want)
		}
	}
	for _, key := range []string{"bad", "obj", "missing"} {
		if got, ok := Int(claims, key); ok {
			t.Errorf("Int(%q) = (%d, true), want not-ok", key, got)
		}
	}
}
