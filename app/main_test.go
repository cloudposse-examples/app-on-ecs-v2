package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setupTestApp(t *testing.T) *app {
	t.Helper()

	// Create temporary public directory with test HTML files
	dir := t.TempDir()
	pubDir := filepath.Join(dir, "public")
	os.MkdirAll(pubDir, 0o755)

	os.WriteFile(filepath.Join(pubDir, "index.html"), []byte(`<body style="background-color: %s"><div class="count">%v</div></body>`), 0o644)
	os.WriteFile(filepath.Join(pubDir, "dashboard.html"), []byte(`<html><body>dashboard</body></html>`), 0o644)
	os.WriteFile(filepath.Join(pubDir, "shutdown.html"), []byte(`<html><body>shutting down</body></html>`), 0o644)

	// chdir so os.ReadFile("public/...") works
	orig, _ := os.Getwd()
	os.Chdir(dir)
	t.Cleanup(func() { os.Chdir(orig) })

	return newApp("blue", ":0")
}

func TestHealthz(t *testing.T) {
	a := setupTestApp(t)

	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()
	a.handleHealthz(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	if w.Body.String() != "OK" {
		t.Errorf("expected body 'OK', got %q", w.Body.String())
	}
}

func TestHealthzDuringShutdown(t *testing.T) {
	a := setupTestApp(t)
	a.healthy.Store(false)

	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()
	a.handleHealthz(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status 503, got %d", w.Code)
	}
	if w.Body.String() != "SHUTTING DOWN" {
		t.Errorf("expected body 'SHUTTING DOWN', got %q", w.Body.String())
	}
}

func TestIndexRendersColorAndCount(t *testing.T) {
	a := setupTestApp(t)

	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()
	a.handleIndex(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	body := w.Body.String()
	if !strings.Contains(body, "blue") {
		t.Errorf("expected body to contain color 'blue', got %q", body)
	}
	if !strings.Contains(body, ">1<") {
		t.Errorf("expected body to contain count '1', got %q", body)
	}

	// Second request increments count
	req = httptest.NewRequest("GET", "/", nil)
	w = httptest.NewRecorder()
	a.handleIndex(w, req)

	body = w.Body.String()
	if !strings.Contains(body, ">2<") {
		t.Errorf("expected body to contain count '2', got %q", body)
	}
}

func TestDashboardEndpoint(t *testing.T) {
	a := setupTestApp(t)

	req := httptest.NewRequest("GET", "/dashboard", nil)
	w := httptest.NewRecorder()
	a.handleDashboard(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "dashboard") {
		t.Errorf("expected dashboard content, got %q", w.Body.String())
	}
}
