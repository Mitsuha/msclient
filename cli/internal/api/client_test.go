package api

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func testClient(srv *httptest.Server) *Client {
	return &Client{baseURL: srv.URL, http: &http.Client{Timeout: 5 * time.Second}}
}

func TestLoginEmailVsPhone(t *testing.T) {
	var gotBody map[string]string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/auth/login" {
			t.Errorf("path = %s", r.URL.Path)
		}
		raw, _ := io.ReadAll(r.Body)
		gotBody = map[string]string{}
		_ = json.Unmarshal(raw, &gotBody)
		w.Header().Set("Content-Type", "application/json")
		io.WriteString(w, `{"token":"tok-123","user":{"id":7,"email":"a@b.com"}}`)
	}))
	defer srv.Close()
	c := testClient(srv)

	res, err := c.Login(context.Background(), "a@b.com", "secret")
	if err != nil {
		t.Fatalf("Login: %v", err)
	}
	if res.Token != "tok-123" || res.User.ID != 7 {
		t.Errorf("unexpected result: %+v", res)
	}
	if gotBody["email"] != "a@b.com" || gotBody["phone"] != "" {
		t.Errorf("email login should send email only: %v", gotBody)
	}

	if _, err := c.Login(context.Background(), "13800000000", "secret"); err != nil {
		t.Fatalf("phone login: %v", err)
	}
	if gotBody["phone"] != "13800000000" || gotBody["email"] != "" {
		t.Errorf("phone login should send phone only: %v", gotBody)
	}
}

func TestLoginUnauthorized(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		io.WriteString(w, `{"message":"bad creds"}`)
	}))
	defer srv.Close()

	_, err := testClient(srv).Login(context.Background(), "a@b.com", "wrong")
	apiErr, ok := err.(*Error)
	if !ok {
		t.Fatalf("want *Error, got %T", err)
	}
	if !apiErr.Unauthorized() {
		t.Errorf("expected 401, got %d", apiErr.StatusCode)
	}
}

func TestClientProxyOptionsDropsEmptyAndFallsBack(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, `[{"name":"a","url":"https://a.com"},{"name":"b","url":""}]`)
	}))
	defer srv.Close()

	opts, err := testClient(srv).ClientProxyOptions(context.Background())
	if err != nil {
		t.Fatalf("ClientProxyOptions: %v", err)
	}
	if len(opts) != 1 || opts[0].Name != "a" {
		t.Errorf("empty-url entry should be dropped: %v", opts)
	}
}

func TestClientProxyOptionsEmptyListFallback(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, `[]`)
	}))
	defer srv.Close()

	opts, err := testClient(srv).ClientProxyOptions(context.Background())
	if err != nil {
		t.Fatalf("ClientProxyOptions: %v", err)
	}
	if len(opts) != 1 || opts[0].Name != "default" {
		t.Errorf("empty list should yield fallback node: %v", opts)
	}
}

func TestToolAuthSendsBearerAndPackID(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer session-tok" {
			t.Errorf("Authorization = %q", got)
		}
		var body map[string]int
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &body)
		if body["user_pack_id"] != 0 {
			t.Errorf("user_pack_id = %d", body["user_pack_id"])
		}
		io.WriteString(w, `{"tokens":{"access_token":"x"}}`)
	}))
	defer srv.Close()

	raw, err := testClient(srv).CodexAuth(context.Background(), "session-tok", 0)
	if err != nil {
		t.Fatalf("CodexAuth: %v", err)
	}
	if len(raw) == 0 {
		t.Errorf("expected raw JSON body")
	}
}
