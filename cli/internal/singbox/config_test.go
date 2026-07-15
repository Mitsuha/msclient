package singbox

import (
	"testing"

	"github.com/mirrorstages/mstages/internal/models"
)

func TestBuildConfigSelectsNodeAndBuildsOutbounds(t *testing.T) {
	proxies := []models.ClientProxyOption{
		{Name: "tokyo", URL: "https://tokyo.example.com:5211"},
		{Name: "osaka", URL: "http://osaka.example.com"},
	}

	cfg, err := BuildConfig(proxies, "http://osaka.example.com")
	if err != nil {
		t.Fatalf("BuildConfig: %v", err)
	}

	if cfg.DefaultTag != "osaka" {
		t.Errorf("DefaultTag = %q, want osaka", cfg.DefaultTag)
	}

	outbounds := cfg.JSON["outbounds"].([]any)
	// 2 nodes + selector + direct.
	if len(outbounds) != 4 {
		t.Fatalf("outbounds len = %d, want 4", len(outbounds))
	}

	tokyo := outbounds[0].(map[string]any)
	if tokyo["server"] != "tokyo.example.com" || tokyo["server_port"] != 5211 {
		t.Errorf("tokyo outbound = %v", tokyo)
	}
	if tls := tokyo["tls"].(map[string]any); tls["enabled"] != true {
		t.Errorf("tokyo tls should be enabled")
	}

	osaka := outbounds[1].(map[string]any)
	if osaka["server_port"] != 80 {
		t.Errorf("osaka default port = %v, want 80", osaka["server_port"])
	}
	if tls := osaka["tls"].(map[string]any); tls["enabled"] != false {
		t.Errorf("osaka tls should be disabled")
	}

	selector := outbounds[2].(map[string]any)
	if selector["type"] != "selector" || selector["default"] != "osaka" {
		t.Errorf("selector = %v", selector)
	}
}

func TestBuildConfigDefaultsToFirstAndDedupesTags(t *testing.T) {
	proxies := []models.ClientProxyOption{
		{Name: "node", URL: "https://a.example.com"},
		{Name: "node", URL: "https://b.example.com"},
	}

	cfg, err := BuildConfig(proxies, "https://unknown.example.com")
	if err != nil {
		t.Fatalf("BuildConfig: %v", err)
	}
	if cfg.DefaultTag != "node" {
		t.Errorf("DefaultTag = %q, want first tag 'node'", cfg.DefaultTag)
	}

	outbounds := cfg.JSON["outbounds"].([]any)
	second := outbounds[1].(map[string]any)
	if second["tag"] != "node-2" {
		t.Errorf("duplicate tag = %v, want node-2", second["tag"])
	}
}

func TestBuildConfigEmptyUsesFallback(t *testing.T) {
	cfg, err := BuildConfig(nil, "")
	if err != nil {
		t.Fatalf("BuildConfig: %v", err)
	}
	outbounds := cfg.JSON["outbounds"].([]any)
	if len(outbounds) != 3 { // 1 fallback node + selector + direct
		t.Fatalf("outbounds len = %d, want 3", len(outbounds))
	}
}
