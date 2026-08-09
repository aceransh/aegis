package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/aceransh/aegis/internal/models"
	"github.com/aceransh/aegis/internal/testutil"
	"github.com/google/uuid"
)

func TestMain(m *testing.M) {
	resultCode := m.Run()

	os.Exit(resultCode)
}

func TestEnqueue(t *testing.T) {
	conn := testutil.NewTestDB(t)
	srv := NewServer(conn)

	ts := httptest.NewServer(http.HandlerFunc(srv.handleEnqueue))
	defer ts.Close()

	reqBody := models.EnqueueRequest{Payload: "test_job"}
	body, err := json.Marshal(reqBody)
	if err != nil {
		t.Fatalf("failed marshal req: %v", err)
	}

	resp, err := http.Post(ts.URL, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatal("Post failed: ", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 but got %d", resp.StatusCode)
	}

	var state string
	err = conn.QueryRow("SELECT state FROM Jobs LIMIT 1").Scan(&state)
	if err != nil {
		t.Fatalf("query failed: %v", err)
	}

	if state != "QUEUED" {
		t.Errorf("expected QUEUED, got %s", state)
	}

}

func TestPoll(t *testing.T) {
	conn := testutil.NewTestDB(t)
	srv := NewServer(conn)

	ts := httptest.NewServer(http.HandlerFunc(srv.handlePoll))
	defer ts.Close()

	var id string = uuid.NewString()

	_, err := conn.Exec("INSERT INTO Jobs (id, payload, state) VALUES ($1, $2, $3)", id, "test_job", models.StateQueued)
	if err != nil {
		t.Fatal("Failed to insert job: ", err)
	}

	reqBody := models.PollRequest{WorkerID: "test-worker"}
	body, err := json.Marshal(reqBody)
	if err != nil {
		t.Fatalf("failed marshal req: %v", err)
	}

	resp, err := http.Post(ts.URL, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatal("Post failed: ", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 but got %d", resp.StatusCode)
	}

	var state string
	err = conn.QueryRow("SELECT state FROM Jobs LIMIT 1").Scan(&state)
	if err != nil {
		t.Fatalf("query failed: %v", err)
	}

	if state != "LEASED" {
		t.Errorf("expected LEASED, got %s", state)
	}
}
