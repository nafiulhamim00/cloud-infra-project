package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"strings"
	"sync/atomic"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/redis/go-redis/v9"
)

// version is injected at build time via -ldflags "-X main.version=$APP_VERSION".
var version = "dev"

type server struct {
	db        *sql.DB
	rdb       *redis.Client
	dbHost    string
	redisHost string
	fallback  atomic.Int64 // in-process /counter used when Redis is not configured
}

type indexResponse struct {
	Message  string `json:"message"`
	Hostname string `json:"hostname"`
	Version  string `json:"version"`
	Arch     string `json:"arch"`
}

func (s *server) indexHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	writeJSON(w, http.StatusOK, indexResponse{
		Message:  fmt.Sprintf("Hello from %s", runtime.GOARCH),
		Hostname: hostname,
		Version:  version,
		Arch:     runtime.GOARCH,
	})
}

func (s *server) healthHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	// Only backends that are actually configured for this deployment are checked.
	if s.dbHost != "" {
		if err := s.db.PingContext(ctx); err != nil {
			http.Error(w, "database unavailable", http.StatusServiceUnavailable)
			return
		}
	}
	if s.redisHost != "" {
		if err := s.rdb.Ping(ctx).Err(); err != nil {
			http.Error(w, "cache unavailable", http.StatusServiceUnavailable)
			return
		}
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func (s *server) counterHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	var count int64
	if s.redisHost != "" {
		n, err := s.rdb.Incr(ctx, "page_views").Result()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		count = n
	} else {
		// No Redis configured: fall back to an in-process counter that
		// resets whenever the container restarts.
		count = s.fallback.Add(1)
	}
	writeJSON(w, http.StatusOK, map[string]int64{"page_views": count})
}

type chatMessage struct {
	ID        int64  `json:"id"`
	Content   string `json:"content"`
	CreatedAt string `json:"created_at"`
}

func (s *server) messagesHandler(w http.ResponseWriter, r *http.Request) {
	if s.dbHost == "" {
		http.Error(w, "database not configured", http.StatusServiceUnavailable)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	switch r.Method {
	case http.MethodPost:
		var body struct {
			Content string `json:"content"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Content == "" {
			http.Error(w, "invalid request body", http.StatusBadRequest)
			return
		}
		if _, err := s.db.ExecContext(ctx, "INSERT INTO messages (content) VALUES (?)", body.Content); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusCreated)

	case http.MethodGet:
		rows, err := s.db.QueryContext(ctx, "SELECT id, content, created_at FROM messages ORDER BY created_at DESC LIMIT 10")
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer rows.Close()

		messages := []chatMessage{}
		for rows.Next() {
			var m chatMessage
			var createdAt time.Time
			if err := rows.Scan(&m.ID, &m.Content, &createdAt); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			m.CreatedAt = createdAt.Format(time.RFC3339)
			messages = append(messages, m)
		}
		writeJSON(w, http.StatusOK, map[string]any{"messages": messages})

	default:
		w.Header().Set("Allow", "GET, POST")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// dbPassword reads the database password from DB_PASSWORD, or from the file
// named by DB_PASSWORD_FILE (the Docker secrets convention).
func dbPassword() string {
	if pw := os.Getenv("DB_PASSWORD"); pw != "" {
		return pw
	}
	if path := os.Getenv("DB_PASSWORD_FILE"); path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			log.Fatalf("reading DB_PASSWORD_FILE: %v", err)
		}
		return strings.TrimSpace(string(data))
	}
	return ""
}

func newServer() *server {
	s := &server{
		dbHost:    os.Getenv("DB_HOST"),
		redisHost: os.Getenv("REDIS_HOST"),
	}

	if s.dbHost != "" {
		dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s?parseTime=true",
			os.Getenv("DB_USER"), dbPassword(), s.dbHost, os.Getenv("DB_NAME"))
		db, err := sql.Open("mysql", dsn)
		if err != nil {
			log.Fatalf("opening database: %v", err)
		}
		s.db = db
	}

	if s.redisHost != "" {
		s.rdb = redis.NewClient(&redis.Options{Addr: s.redisHost + ":6379"})
	}

	return s
}

func main() {
	s := newServer()

	mux := http.NewServeMux()
	mux.HandleFunc("/", s.indexHandler)
	mux.HandleFunc("/health", s.healthHandler)
	mux.HandleFunc("/counter", s.counterHandler)
	mux.HandleFunc("/messages", s.messagesHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("dat515-app %s starting on port %s", version, port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
