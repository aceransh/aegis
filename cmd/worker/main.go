package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/aceransh/aegis/internal/models"
	"github.com/google/uuid"
)

const brokerURL = "http://localhost:8080" // We can make this an env var later

func pollForJob(client *http.Client, workerID string) (*models.Job, error) {
	reqBody := models.PollRequest{WorkerID: workerID}
	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed marshal req: %v", err)
	}

	pollUrl := fmt.Sprintf("%s/poll", brokerURL)
	resp, err := client.Post(pollUrl, "application/json", bytes.NewBuffer(jsonBytes))
	if err != nil {
		return nil, fmt.Errorf("network error during poll: %v", err)
	}
	defer resp.Body.Close() //cleans up the data stream once function is finished

	if resp.StatusCode == http.StatusNoContent {
		return nil, nil //queue is empty
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("broker returned unexpected status: %d", resp.StatusCode)
	}

	//if 200
	var job models.Job
	if err := json.NewDecoder(resp.Body).Decode(&job); err != nil {
		return nil, fmt.Errorf("failed to decode job: %v", err)
	}

	return &job, nil

}

func ackJob(client *http.Client, workerID string, jobID string, leaseID int64) error {
	reqBody := models.AckRequest{WorkerID: workerID, JobID: jobID, LeaseID: leaseID}
	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed marshall req: %v", err)
	}

	ackUrl := fmt.Sprintf("%s/ack", brokerURL)
	resp, err := client.Post(ackUrl, "application/json", bytes.NewBuffer(jsonBytes))
	if err != nil {
		return fmt.Errorf("network error during ack: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("broker returned unexpected status: %d", resp.StatusCode)
	}

	return nil
}

func failJob(client *http.Client, workerID string, jobID string, leaseID int64) error {
	reqBody := models.FailRequest{WorkerID: workerID, JobID: jobID, LeaseID: leaseID}
	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("failed marshall req: %v", err)
	}

	failUrl := fmt.Sprintf("%s/fail", brokerURL)
	resp, err := client.Post(failUrl, "application/json", bytes.NewBuffer(jsonBytes))
	if err != nil {
		return fmt.Errorf("network error during fail: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("broker returned unexpected status: %d", resp.StatusCode)
	}

	return nil
}

func main() {
	workerID := uuid.NewString()
	log.Printf("Starting Aegis MQ Worker | ID: %s", workerID)

	// Custom HTTP client to handle Long Polling safely
	client := &http.Client{
		Timeout: 35 * time.Second, //this destroys the network pipeline so it doesn't stay open forever if the broker dies
	}

	// This is where your infinite worker loop will go
	for {
		// 1. Poll for a job
		job, err := pollForJob(client, workerID)
		if err != nil {
			log.Printf("Worker ID: %s had an error polling for a job: %v", workerID, err)
			time.Sleep(2 * time.Second)
			continue
		}
		// 2. If no job, continue loop
		if job == nil {
			continue
		}
		// 3. If job, execute it
		log.Printf("Acquired Job ID: %s | Executing payload: %s", job.ID, job.Payload)
		time.Sleep(3 * time.Second) //sim worker doing task
		// 4. Ack or Fail based on execution result
		err = ackJob(client, workerID, job.ID, job.LeaseID)
		if err != nil {
			log.Printf("Critical: Failed to ack Job ID: %s | Error: %v", job.ID, err)
			// If it fails to ack, the broker will eventually time out the lease
			// and give the job to another worker.
		} else {
			log.Printf("Successfully finished and acked Job ID: %s", job.ID)
		}

	}
}
