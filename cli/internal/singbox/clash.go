package singbox

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/mirrorstages/mstages/internal/app"
)

// ClashHealthy reports whether the loopback Clash API answers GET /version.
func ClashHealthy(ctx context.Context) bool {
	reqCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, app.ClashAPIBaseURL+"/version", nil)
	if err != nil {
		return false
	}
	req.Header.Set("Authorization", "Bearer "+app.SingboxClashSecret)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

// SelectOutbound switches the selector's active node live via the Clash API:
// PUT /proxies/<selector> with body {"name": <tag>}.
func SelectOutbound(ctx context.Context, tag string) error {
	body, _ := json.Marshal(map[string]string{"name": tag})
	url := fmt.Sprintf("%s/proxies/%s", app.ClashAPIBaseURL, selectorTag)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+app.SingboxClashSecret)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		return fmt.Errorf("clash select outbound: status %d", resp.StatusCode)
	}
	return nil
}
