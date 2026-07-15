// Package app holds environment constants and filesystem paths shared across
// the mstages CLI. Values mirror the Flutter desktop app's AppConfig
// (desktop/lib/app/app_config.dart) so both clients behave identically.
package app

import "fmt"

// Backend endpoints.
const (
	// APIBaseURL already includes the /api path prefix; endpoint paths are
	// appended onto it (e.g. APIBaseURL + "/auth/login").
	APIBaseURL = "https://platform.mirrorstages.com/api"

	// FallbackProxyURL is the remote node used when the server list is empty.
	FallbackProxyURL = "https://api.mirrorstages.com:5211"

	AdminConsoleURL = "https://dashboard.mirrorstages.com"
)

// Data directory: ~/.mstages holds the sing-box binary, config, and runtime log.
const DataDirName = ".mstages"

// sing-box distribution and runtime.
const (
	// SingboxDownloadBaseURL has the platform asset name appended
	// (sing-box-darwin / sing-box-linux / sing-box.exe).
	SingboxDownloadBaseURL = "https://cnb.cool/mirrorstages/gost/-/git/raw/main"

	SingboxHost        = "127.0.0.1"
	SingboxProxyPort   = 18610
	SingboxAPIPort     = 18611
	SingboxClashSecret = "default-secret"
	SingboxConfigFile  = "sing-box.json"
	SingboxLogFile     = "sing-box.log"
)

// LocalProxyURL is the constant loopback proxy written into every tool config.
var LocalProxyURL = fmt.Sprintf("http://%s:%d", SingboxHost, SingboxProxyPort)

// ClashAPIBaseURL is the base URL of the loopback Clash API.
var ClashAPIBaseURL = fmt.Sprintf("http://%s:%d", SingboxHost, SingboxAPIPort)

// ProxyDomains is the split-tunnel whitelist: only these route through the
// selector, everything else goes direct.
var ProxyDomains = []string{
	"chatgpt.com",
	"anthropic.com",
	"openai.com",
	"claude.com",
	"claude.ai",
	"api.anthropic.com",
	"platform.claude.com",
}
