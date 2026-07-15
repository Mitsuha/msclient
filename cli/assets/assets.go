// Package assets embeds static files bundled into the mstages binary.
package assets

import _ "embed"

// RootCA is the MirrorStages MITM proxy root certificate, trusted so the
// upstream proxy can TLS-intercept the whitelisted domains.
//
//go:embed mirrorstages-root-ca.cer
var RootCA []byte
