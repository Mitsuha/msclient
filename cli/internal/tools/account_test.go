package tools

import (
	"encoding/base64"
	"strings"
	"testing"
)

// makeClaudeToken builds a token shaped like the ones MirrorStages issues:
// base64url of "<user_id>|<member_id>|<pack_id>|" plus random padding, with a
// signature appended after a dash.
func makeClaudeToken(payload, signature string) string {
	content := base64.RawURLEncoding.EncodeToString([]byte(payload + "PADPADPA"))
	return claudeTokenPrefix + content + "-" + signature
}

func TestClaudeUserPackID(t *testing.T) {
	token := makeClaudeToken("9|abc|42|", "ZZZZ")
	id, ok := claudeUserPackID(token)
	if !ok {
		t.Fatalf("expected a MirrorStages token: %s", token)
	}
	if id != 42 {
		t.Errorf("user_pack_id = %d, want 42", id)
	}
}

func TestClaudeUserPackIDPayAsYouGo(t *testing.T) {
	id, ok := claudeUserPackID(makeClaudeToken("9|abc|0|", "QQQQ"))
	if !ok || id != 0 {
		t.Errorf("got (%d, %v), want (0, true)", id, ok)
	}
}

// The base64url alphabet contains "-", so the token cannot be split on it. A
// payload whose encoding contains a dash must still parse.
func TestClaudeUserPackIDPayloadContainingDash(t *testing.T) {
	var payload string
	for i := 0; i < 64; i++ {
		candidate := "1|m" + strings.Repeat("\xfb", i) + "|7|"
		if strings.Contains(base64.RawURLEncoding.EncodeToString([]byte(candidate+"PADPADPA")), "-") {
			payload = candidate
			break
		}
	}
	if payload == "" {
		t.Skip("could not construct a payload encoding to a dash")
	}
	id, ok := claudeUserPackID(makeClaudeToken(payload, "ZZZZ"))
	if !ok || id != 7 {
		t.Errorf("got (%d, %v), want (7, true)", id, ok)
	}
}

func TestClaudeUserPackIDRejectsForeignTokens(t *testing.T) {
	cases := map[string]string{
		"wrong prefix": "sk-ant-api03-" + base64.RawURLEncoding.EncodeToString([]byte("1|2|3|xxxxxxxx")),
		"fewer pipes":  makeClaudeToken("no-pipes-here", "ZZZZ"),
		"two pipes":    makeClaudeToken("9|abc", "ZZZZ"),
		"non-numeric":  makeClaudeToken("9|abc|xx|", "ZZZZ"),
		"empty token":  "",
		"prefix only":  claudeTokenPrefix,
		"undecodable":  claudeTokenPrefix + "!!!!!!!!",
	}
	for name, token := range cases {
		if _, ok := claudeUserPackID(token); ok {
			t.Errorf("%s: expected rejection", name)
		}
	}
}

func TestClaudeAccessToken(t *testing.T) {
	got := claudeAccessToken([]byte(`{"claudeAiOauth":{"accessToken":"sk-ant-oat01-abc"}}`))
	if got != "sk-ant-oat01-abc" {
		t.Errorf("accessToken = %q", got)
	}
	if claudeAccessToken([]byte(`not json`)) != "" {
		t.Error("malformed credentials should yield an empty token")
	}
}

func TestClaudePlan(t *testing.T) {
	cases := map[string]string{
		"default_claude_max_20x": "Max 20X",
		"default_claude_max_5x":  "Max 5X",
		"something_else":         "Pro",
		"":                       "Pro",
	}
	for tier, want := range cases {
		if got := claudePlan(tier); got != want {
			t.Errorf("claudePlan(%q) = %q, want %q", tier, got, want)
		}
	}
}

func jwtToken(payload string) string {
	return "h." + base64.RawURLEncoding.EncodeToString([]byte(payload)) + ".s"
}

func TestCodexGrantsMirrorStages(t *testing.T) {
	granted := jwtToken(`{"account_sharing_member_id":"m-1","user_id":"u-1"}`)
	if !codexGrantsMirrorStages(granted) {
		t.Error("token with both claims should be recognized")
	}
	for name, token := range map[string]string{
		"missing member": jwtToken(`{"user_id":"u-1"}`),
		"missing user":   jwtToken(`{"account_sharing_member_id":"m-1"}`),
		"empty member":   jwtToken(`{"account_sharing_member_id":"","user_id":"u-1"}`),
		"not a jwt":      "plain-token",
		"empty":          "",
	} {
		if codexGrantsMirrorStages(token) {
			t.Errorf("%s: should not be recognized as MirrorStages-issued", name)
		}
	}
}

func TestCodexAccountPrefersIDToken(t *testing.T) {
	tokens := codexTokens([]byte(`{"tokens":{
		"access_token":"` + jwtToken(`{"email":"access@x.com","name":"Access"}`) + `",
		"id_token":"` + jwtToken(`{"email":"id@x.com","name":"Id","https://api.openai.com/auth":{"chatgpt_plan_type":"pro"}}`) + `"
	}}`))
	info := codexAccount(tokens)
	if info == nil {
		t.Fatal("expected account info")
	}
	if info.Email != "id@x.com" || info.Username != "Id" {
		t.Errorf("should prefer the id token: %+v", info)
	}
	if info.Plan != "Pro" {
		t.Errorf("Plan = %q, want %q", info.Plan, "Pro")
	}
}

func TestCodexAccountFallsBackToAccessToken(t *testing.T) {
	tokens := codexTokens([]byte(`{"tokens":{"access_token":"` +
		jwtToken(`{"email":"access@x.com","name":"Access"}`) + `"}}`))
	info := codexAccount(tokens)
	if info == nil {
		t.Fatal("expected account info")
	}
	if info.Email != "access@x.com" {
		t.Errorf("Email = %q", info.Email)
	}
	if info.Plan != unknownPlan {
		t.Errorf("Plan = %q, want %q", info.Plan, unknownPlan)
	}
}

func TestCodexAccountUndecodable(t *testing.T) {
	if info := codexAccount(codexAccessTokens{}); info != nil {
		t.Errorf("expected nil for empty tokens, got %+v", info)
	}
}
