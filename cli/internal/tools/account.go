package tools

import (
	"encoding/base64"
	"encoding/json"
	"strings"

	"github.com/mirrorstages/mstages/internal/jwt"
)

// accountInfo is the non-sensitive summary of the upstream account currently
// configured for a tool. It is printed after the account step; tokens and other
// credential material never appear in it.
type accountInfo struct {
	Email    string
	Username string
	Plan     string
	// UserPackID is the pack this account bills against, 0 for 按量计费. It is
	// read back out of the credentials, which is where the backend records it.
	UserPackID int
}

// pendingAccount is an account granted by the backend but not yet written to
// disk. Holding it lets the caller back up the user's existing config between
// the request and the overwrite.
type pendingAccount struct {
	raw  json.RawMessage
	info *accountInfo
}

// unknownPlan matches the desktop client's placeholder.
const unknownPlan = "未知"

// claudeTokenPrefix is the OAuth token prefix Claude Code issues.
const claudeTokenPrefix = "sk-ant-oat01-"

// claudeUserPackID extracts the user_pack_id MirrorStages embeds in a Claude
// OAuth token. The token is "sk-ant-oat01-<content>-<sig>" where <content> is
// the URL-safe base64 of "user_id|account_sharing_member_id|user_pack_id|"
// plus random padding bytes.
//
// The content cannot be split on "-" because the base64url alphabet contains
// it, so the remainder is truncated to a multiple of 4, decoded, and scanned
// for the first three pipe bytes. A token without three pipes was not issued
// by MirrorStages.
func claudeUserPackID(token string) (int, bool) {
	if !strings.HasPrefix(token, claudeTokenPrefix) {
		return 0, false
	}
	rest := token[len(claudeTokenPrefix):]
	rest = rest[:len(rest)-len(rest)%4]
	raw, err := base64.RawURLEncoding.DecodeString(rest)
	if err != nil {
		return 0, false
	}

	// Locate the first three pipes; user_pack_id sits between #2 and #3.
	pipes := make([]int, 0, 3)
	for i, b := range raw {
		if b == '|' {
			pipes = append(pipes, i)
			if len(pipes) == 3 {
				break
			}
		}
	}
	if len(pipes) < 3 {
		return 0, false
	}

	id := 0
	for _, b := range raw[pipes[1]+1 : pipes[2]] {
		if b < '0' || b > '9' {
			return 0, false
		}
		id = id*10 + int(b-'0')
	}
	return id, true
}

// claudeAccessToken pulls claudeAiOauth.accessToken out of a credentials blob.
func claudeAccessToken(credentials []byte) string {
	var creds struct {
		Oauth struct {
			AccessToken string `json:"accessToken"`
		} `json:"claudeAiOauth"`
	}
	if err := json.Unmarshal(credentials, &creds); err != nil {
		return ""
	}
	return creds.Oauth.AccessToken
}

// claudeRateLimitTiers maps the organization tier in ~/.claude.json to the
// plan name shown to the user, matching claude_config_manager.dart.
var claudeRateLimitTiers = map[string]string{
	"default_claude_max_20x": "Max 20X",
	"default_claude_max_5x":  "Max 5X",
}

func claudePlan(tier string) string {
	if name, ok := claudeRateLimitTiers[tier]; ok {
		return name
	}
	return "Pro"
}

// codexAccessTokens holds the two JWTs in ~/.codex/auth.json.
type codexAccessTokens struct {
	Access string
	ID     string
}

// codexTokens reads tokens.{access_token,id_token} from an auth.json body.
func codexTokens(authJSON []byte) codexAccessTokens {
	var doc struct {
		Tokens struct {
			AccessToken string `json:"access_token"`
			IDToken     string `json:"id_token"`
		} `json:"tokens"`
	}
	if err := json.Unmarshal(authJSON, &doc); err != nil {
		return codexAccessTokens{}
	}
	return codexAccessTokens{Access: doc.Tokens.AccessToken, ID: doc.Tokens.IDToken}
}

// codexGrantsMirrorStages reports whether an access token was issued through
// MirrorStages: its payload carries both account_sharing_member_id and user_id.
func codexGrantsMirrorStages(accessToken string) bool {
	claims, err := jwt.DecodePayload(accessToken)
	if err != nil {
		return false
	}
	return jwt.String(claims, "account_sharing_member_id") != "" &&
		jwt.String(claims, "user_id") != ""
}

// codexUserPackID reads the user_pack_id claim MirrorStages puts in the Codex
// access token, mirroring codex_config_manager.dart. A token without the claim
// is pay-as-you-go, which is also the id 0 means everywhere else.
func codexUserPackID(accessToken string) int {
	claims, err := jwt.DecodePayload(accessToken)
	if err != nil {
		return 0
	}
	id, _ := jwt.Int(claims, "user_pack_id")
	return id
}

// codexAccount builds the display info from the id token, falling back to the
// access token when no id token is present.
func codexAccount(tokens codexAccessTokens) *accountInfo {
	claims, err := jwt.DecodePayload(tokens.ID)
	if err != nil {
		claims, err = jwt.DecodePayload(tokens.Access)
		if err != nil {
			return nil
		}
	}
	info := &accountInfo{
		Email:    jwt.String(claims, "email"),
		Username: jwt.String(claims, "name"),
		Plan:     unknownPlan,
	}
	// The pack lives on the access token, not the id token: the id token is
	// OpenAI's, the access token is the one MirrorStages mints.
	info.UserPackID = codexUserPackID(tokens.Access)
	if auth := jwt.Object(claims, "https://api.openai.com/auth"); auth != nil {
		if plan := jwt.String(auth, "chatgpt_plan_type"); plan != "" {
			info.Plan = capitalize(plan)
		}
	}
	return info
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	return strings.ToUpper(string(r[0])) + string(r[1:])
}
