package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestUserPacksKeepsBillablePacks(t *testing.T) {
	var gotPath, gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.RequestURI()
		gotAuth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"packs":[
			{"id":7,"status":0,"remain_amount":12.5,"expire_at":"2026-09-01T00:00:00Z","product":{"id":1,"name":"Max 5X"}},
			{"id":8,"status":1,"remain_amount":0,"product":{"id":2,"name":"Pro"}},
			{"id":9,"status":2,"remain_amount":0,"product":{"id":3,"name":"过期套餐"}}
		]}`))
	}))
	defer srv.Close()

	packs, err := testClient(srv).UserPacks(context.Background(), "tok")
	if err != nil {
		t.Fatalf("UserPacks: %v", err)
	}
	if gotPath != "/user/pack?status=1" {
		t.Errorf("path = %q, want /user/pack?status=1", gotPath)
	}
	if gotAuth != "Bearer tok" {
		t.Errorf("authorization = %q, want Bearer tok", gotAuth)
	}
	if len(packs) != 2 {
		t.Fatalf("len(packs) = %d, want 2 (expired dropped)", len(packs))
	}
	if packs[0].ID != 7 || packs[0].Product.Name != "Max 5X" || packs[0].RemainAmount != 12.5 {
		t.Errorf("packs[0] = %+v, want id 7 / Max 5X / 12.5", packs[0])
	}
	if packs[1].ID != 8 {
		t.Errorf("packs[1].ID = %d, want 8 (exhausted is still selectable)", packs[1].ID)
	}
}

func TestUserPacksEmptyList(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"packs":[]}`))
	}))
	defer srv.Close()

	packs, err := testClient(srv).UserPacks(context.Background(), "tok")
	if err != nil {
		t.Fatalf("UserPacks: %v", err)
	}
	if len(packs) != 0 {
		t.Errorf("len(packs) = %d, want 0", len(packs))
	}
}
