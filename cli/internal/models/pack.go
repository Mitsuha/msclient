package models

// UserPackStatus is the pack lifecycle state the backend reports as an int,
// matching UserPackStatus in desktop/lib/data/models/pack_models.dart.
type UserPackStatus int

const (
	// PackActive still has balance left.
	PackActive UserPackStatus = 0
	// PackExhausted has run out of balance but is still selectable.
	PackExhausted UserPackStatus = 1
	// PackExpired is past its expiry date.
	PackExpired UserPackStatus = 2
)

// UserPackProduct is the product a pack was bought from.
type UserPackProduct struct {
	ID       int     `json:"id"`
	Name     string  `json:"name"`
	Balance  float64 `json:"balance"`
	Grouping string  `json:"grouping"`
}

// UserPack is one purchased pack, from GET /user/pack. Its ID is the
// user_pack_id sent when requesting tool credentials.
type UserPack struct {
	ID           int             `json:"id"`
	Product      UserPackProduct `json:"product"`
	RemainAmount float64         `json:"remain_amount"`
	Status       UserPackStatus  `json:"status"`
	APIKeyCount  int             `json:"api_key_count"`
	ExpireAt     string          `json:"expire_at"`
}

// IsActive reports whether the pack can still be billed against. Exhausted
// packs count as active, matching the desktop client: the backend, not us,
// decides whether a request against them is refused.
func (p UserPack) IsActive() bool {
	return p.Status == PackActive || p.Status == PackExhausted
}

// UserPackList is the GET /user/pack envelope.
type UserPackList struct {
	Packs []UserPack `json:"packs"`
}
