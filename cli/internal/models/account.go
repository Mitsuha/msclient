// Package models holds the wire/persistence data types shared by the CLI.
package models

// UserProfile mirrors the server's user object (snake_case JSON keys), matching
// the Flutter UserProfile in desktop/lib/data/models/account_models.dart.
type UserProfile struct {
	ID            int     `json:"id"`
	Phone         string  `json:"phone"`
	Email         string  `json:"email"`
	Nickname      string  `json:"nickname"`
	PriceRatio    float64 `json:"price_ratio"`
	InviteCode    string  `json:"invite_code"`
	AlipayAccount string  `json:"alipay_account"`
	AlipayName    string  `json:"alipay_name"`
	CreatedAt     string  `json:"created_at,omitempty"`
	UpdatedAt     string  `json:"updated_at,omitempty"`
}

// DisplayAccount returns the email when present, otherwise the phone.
func (u UserProfile) DisplayAccount() string {
	if u.Email != "" {
		return u.Email
	}
	return u.Phone
}

// LoginResult is the POST /auth/login response.
type LoginResult struct {
	Token string      `json:"token"`
	User  UserProfile `json:"user"`
}
