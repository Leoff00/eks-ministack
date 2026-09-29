package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "método não permitido", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		if err := json.NewEncoder(w).Encode(map[string]string{"status": "ok"}); err != nil {
			log.Printf("falha ao responder healthz: %v", err)
		}
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		if r.Method != http.MethodGet {
			http.Error(w, "método não permitido", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		log.Println("request reached the pod")
		if err := json.NewEncoder(w).Encode(map[string]string{
			"message": "Olá do EKS local (k3s / Ministack)!",
			"pod":     getenv("POD_NAME", getenv("HOSTNAME", "desconhecido")),
			"node":    getenv("NODE_NAME", "desconhecido"),
			"log_level": getenv("LOG_LEVEL", "desconhecido"),
		}); err != nil {
			log.Printf("falha ao responder: %v", err)
		}
	})

	log.Println("escutando na porta 5001")
	log.Fatal(http.ListenAndServe(":5001", mux))
}
