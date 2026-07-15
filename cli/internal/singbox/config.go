package singbox

import (
	"fmt"
	"net/url"
	"strings"

	"github.com/mirrorstages/mstages/internal/app"
	"github.com/mirrorstages/mstages/internal/models"
)

// Outbound/inbound/route tags, matching the Flutter config builder.
const (
	httpInboundTag = "default-http"
	selectorTag    = "default-selector"
	directTag      = "direct"
)

// Config is a generated sing-box configuration plus metadata used to decide
// whether a running instance needs a full restart or just a live node switch.
type Config struct {
	// JSON is the pretty-printable config document.
	JSON map[string]any
	// DefaultTag is the selector's default outbound.
	DefaultTag string
	// Signature is the ordered "tag|host|port|tls" list of node outbounds; a
	// change means the outbound set changed and a restart is required.
	Signature string
}

// BuildConfig turns proxy options into a sing-box config. selectedURL, when it
// matches one of the options, becomes the selector default; otherwise the first
// option is used.
func BuildConfig(proxies []models.ClientProxyOption, selectedURL string) (*Config, error) {
	if len(proxies) == 0 {
		proxies = []models.ClientProxyOption{{Name: "default", URL: app.FallbackProxyURL}}
	}

	used := map[string]int{}
	tags := make([]string, 0, len(proxies))
	sigParts := make([]string, 0, len(proxies))
	outbounds := make([]map[string]any, 0, len(proxies)+2)
	var selectedTag string

	for _, p := range proxies {
		u, err := url.Parse(p.URL)
		if err != nil {
			return nil, fmt.Errorf("invalid proxy url %q: %w", p.URL, err)
		}
		overTLS := u.Scheme == "https"
		port := portOf(u, overTLS)
		tag := uniqueTag(p, u, used)
		tags = append(tags, tag)

		outbounds = append(outbounds, map[string]any{
			"type":        "http",
			"tag":         tag,
			"server":      u.Hostname(),
			"server_port": port,
			"tls":         map[string]any{"enabled": overTLS},
		})
		sigParts = append(sigParts, fmt.Sprintf("%s|%s|%d|%t", tag, u.Hostname(), port, overTLS))

		if p.URL == selectedURL {
			selectedTag = tag
		}
	}

	defaultTag := selectedTag
	if defaultTag == "" {
		defaultTag = tags[0]
	}

	selectorOutbounds := make([]any, len(tags))
	for i, t := range tags {
		selectorOutbounds[i] = t
	}
	outbounds = append(outbounds,
		map[string]any{
			"type":      "selector",
			"tag":       selectorTag,
			"outbounds": selectorOutbounds,
			"default":   defaultTag,
		},
		map[string]any{"type": "direct", "tag": directTag},
	)

	domainSuffix := make([]any, len(app.ProxyDomains))
	for i, d := range app.ProxyDomains {
		domainSuffix[i] = d
	}

	outboundsAny := make([]any, len(outbounds))
	for i, o := range outbounds {
		outboundsAny[i] = o
	}

	doc := map[string]any{
		"log": map[string]any{"level": "info"},
		"experimental": map[string]any{
			"clash_api": map[string]any{
				"external_controller": fmt.Sprintf("%s:%d", app.SingboxHost, app.SingboxAPIPort),
				"secret":              app.SingboxClashSecret,
			},
		},
		"inbounds": []any{
			map[string]any{
				"type":        "http",
				"tag":         httpInboundTag,
				"listen":      app.SingboxHost,
				"listen_port": app.SingboxProxyPort,
			},
		},
		"outbounds": outboundsAny,
		"route": map[string]any{
			"rules": []any{
				map[string]any{
					"inbound":       []any{httpInboundTag},
					"domain_suffix": domainSuffix,
					"outbound":      selectorTag,
				},
			},
			"final": directTag,
		},
	}

	return &Config{
		JSON:       doc,
		DefaultTag: defaultTag,
		Signature:  strings.Join(sigParts, ","),
	}, nil
}

func portOf(u *url.URL, overTLS bool) int {
	if p := u.Port(); p != "" {
		var n int
		if _, err := fmt.Sscanf(p, "%d", &n); err == nil {
			return n
		}
	}
	if overTLS {
		return 443
	}
	return 80
}

// uniqueTag derives a stable outbound tag from the node name (or host),
// deduplicating collisions with -2, -3, … suffixes.
func uniqueTag(p models.ClientProxyOption, u *url.URL, used map[string]int) string {
	base := strings.TrimSpace(p.Name)
	if base == "" {
		base = u.Hostname()
	}
	if base == "" {
		base = "node"
	}
	used[base]++
	if n := used[base]; n > 1 {
		return fmt.Sprintf("%s-%d", base, n)
	}
	return base
}
