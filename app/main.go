package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync/atomic"
	"time"
)

type app struct {
	color   string
	count   atomic.Int64
	healthy atomic.Bool
	server  *http.Server
}

func newApp(color, addr string) *app {
	a := &app{color: color}
	a.healthy.Store(true)

	mux := http.NewServeMux()
	a.setupRoutes(mux)

	a.server = &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	return a
}

func (a *app) setupRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/healthz", a.handleHealthz)
	mux.HandleFunc("/shutdown", a.handleShutdown)
	mux.HandleFunc("/dashboard", a.handleDashboard)
	mux.HandleFunc("/", a.handleIndex)
}

func (a *app) handleHealthz(w http.ResponseWriter, r *http.Request) {
	if !a.healthy.Load() {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "SHUTTING DOWN")
		return
	}
	fmt.Fprintf(w, "OK")
}

func (a *app) handleShutdown(w http.ResponseWriter, r *http.Request) {
	a.healthy.Store(false)
	boom, err := os.ReadFile("public/shutdown.html")
	if err != nil {
		http.Error(w, "failed to read shutdown page", http.StatusInternalServerError)
		return
	}
	w.Write(boom)
	log.Printf("Received shutdown request, failing health checks and waiting for drain\n")
	go func() {
		time.Sleep(12 * time.Second)
		log.Printf("Drain period complete, shutting down server\n")
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := a.server.Shutdown(ctx); err != nil {
			log.Fatal(err)
		}
	}()
}

func (a *app) handleDashboard(w http.ResponseWriter, r *http.Request) {
	dashboard, err := os.ReadFile("public/dashboard.html")
	if err != nil {
		http.Error(w, "failed to read dashboard page", http.StatusInternalServerError)
		return
	}
	w.Write(dashboard)
	log.Printf("GET %s\n", r.URL.Path)
}

func (a *app) handleIndex(w http.ResponseWriter, r *http.Request) {
	index, err := os.ReadFile("public/index.html")
	if err != nil {
		http.Error(w, "failed to read index page", http.StatusInternalServerError)
		return
	}
	n := a.count.Add(1)
	rendered := fmt.Sprintf(string(index), a.color, n)
	w.Write([]byte(rendered))
}

func main() {
	color := os.Getenv("COLOR")
	if len(color) == 0 {
		color = "green"
	}

	addr := os.Getenv("LISTEN")
	if len(addr) == 0 {
		addr = ":8080"
	}

	a := newApp(color, addr)

	log.Printf("Server started\n")

	if err := a.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
	log.Printf("Exiting")
}
