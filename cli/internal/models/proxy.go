package models

// ClientProxyOption is one selectable proxy node, from
// GET /app/configs/client-proxy. Entries with an empty URL are dropped by the
// API layer.
type ClientProxyOption struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}
