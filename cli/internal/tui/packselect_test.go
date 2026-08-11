package tui

import (
	"testing"

	"github.com/mirrorstages/mstages/internal/models"
)

func TestPackItemsPutsPayAsYouGoFirst(t *testing.T) {
	items := packItems([]models.UserPack{
		{ID: 7, RemainAmount: 12.5, ExpireAt: "2026-09-01T00:00:00Z",
			Product: models.UserPackProduct{Name: "Max 5X"}},
		{ID: 8, Status: models.PackExhausted, Product: models.UserPackProduct{Name: "Pro"}},
		{ID: 9},
	})

	if len(items) != 4 {
		t.Fatalf("len(items) = %d, want 4", len(items))
	}
	if items[0].id != PayAsYouGoPackID || items[0].name != "按量计费" {
		t.Errorf("items[0] = %+v, want the 按量计费 sentinel", items[0])
	}
	if items[0].detail != "" {
		t.Errorf("items[0].detail = %q, want empty", items[0].detail)
	}
	if got, want := items[1].detail, "剩余 12.5 · 至 2026-09-01"; got != want {
		t.Errorf("items[1].detail = %q, want %q", got, want)
	}
	if got, want := items[2].detail, "已用尽"; got != want {
		t.Errorf("items[2].detail = %q, want %q", got, want)
	}
	if got, want := items[3].name, "套餐 #9"; got != want {
		t.Errorf("items[3].name = %q, want %q", got, want)
	}
}

func TestTrimAmount(t *testing.T) {
	cases := map[float64]string{12: "12", 12.5: "12.5", 12.34: "12.34", 0: "0"}
	for in, want := range cases {
		if got := trimAmount(in); got != want {
			t.Errorf("trimAmount(%v) = %q, want %q", in, got, want)
		}
	}
}

func TestDatePart(t *testing.T) {
	cases := map[string]string{
		"2026-09-01T00:00:00Z": "2026-09-01",
		"2026-09-01 00:00:00":  "2026-09-01",
		"2026-09-01":           "2026-09-01",
		"":                     "",
		"bad":                  "",
	}
	for in, want := range cases {
		if got := datePart(in); got != want {
			t.Errorf("datePart(%q) = %q, want %q", in, got, want)
		}
	}
}
