package main

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
)

type fakePublisher struct {
	mu       sync.Mutex
	messages []string
	sent     chan struct{}
}

func newFakePublisher() *fakePublisher {
	return &fakePublisher{sent: make(chan struct{}, 1)}
}

func (f *fakePublisher) SendMessage(_ context.Context, in *sqs.SendMessageInput, _ ...func(*sqs.Options)) (*sqs.SendMessageOutput, error) {
	f.mu.Lock()
	f.messages = append(f.messages, *in.MessageBody)
	f.mu.Unlock()
	f.sent <- struct{}{}
	return &sqs.SendMessageOutput{}, nil
}

func newTestApp(t *testing.T, publisher EventPublisher) (*App, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New()
	if err != nil {
		t.Fatalf("sqlmock: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return &App{DB: db, SqsSvc: publisher, SqsQueueURL: "https://sqs.local/fila"}, mock
}

func TestHealth(t *testing.T) {
	app, _ := newTestApp(t, nil)
	rec := httptest.NewRecorder()

	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/health", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, esperado 200", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), `"donation-service"`) {
		t.Fatalf("corpo inesperado: %s", rec.Body.String())
	}
}

func TestCreateDonationPersistsAndPublishesEvent(t *testing.T) {
	publisher := newFakePublisher()
	app, mock := newTestApp(t, publisher)
	criadaEm := time.Date(2026, 11, 19, 10, 0, 0, 0, time.UTC)

	mock.ExpectQuery("INSERT INTO donations").
		WithArgs(1, 50.0, "Maria", "APPROVED").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).AddRow(7, criadaEm))

	body := `{"ngo_id":1,"amount":50.0,"donor_name":"Maria"}`
	rec := httptest.NewRecorder()
	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/donations", strings.NewReader(body)))

	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, esperado 201", rec.Code)
	}
	var d Donation
	if err := json.NewDecoder(rec.Body).Decode(&d); err != nil {
		t.Fatalf("resposta inválida: %v", err)
	}
	if d.ID != 7 || d.Status != "APPROVED" {
		t.Fatalf("doação inesperada: %+v", d)
	}

	select {
	case <-publisher.sent:
	case <-time.After(2 * time.Second):
		t.Fatal("o evento não foi publicado no SQS")
	}
	if !strings.Contains(publisher.messages[0], `"donor_name":"Maria"`) {
		t.Fatalf("evento inesperado: %s", publisher.messages[0])
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestCreateDonationRejectsInvalidPayload(t *testing.T) {
	app, _ := newTestApp(t, nil)
	rec := httptest.NewRecorder()

	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/donations", strings.NewReader("{")))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, esperado 400", rec.Code)
	}
}

func TestCreateDonationReturns500WhenDatabaseFails(t *testing.T) {
	publisher := newFakePublisher()
	app, mock := newTestApp(t, publisher)
	mock.ExpectQuery("INSERT INTO donations").WillReturnError(errors.New("conexão perdida"))

	rec := httptest.NewRecorder()
	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/donations", strings.NewReader(`{"ngo_id":1,"amount":10,"donor_name":"Ana"}`)))

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, esperado 500", rec.Code)
	}
	select {
	case <-publisher.sent:
		t.Fatal("não deveria publicar evento de uma doação que não foi salva")
	case <-time.After(100 * time.Millisecond):
	}
}

func TestListDonations(t *testing.T) {
	app, mock := newTestApp(t, nil)
	criadaEm := time.Date(2026, 11, 19, 10, 0, 0, 0, time.UTC)
	mock.ExpectQuery("SELECT id, ngo_id, amount, donor_name, status, created_at FROM donations").
		WillReturnRows(sqlmock.NewRows([]string{"id", "ngo_id", "amount", "donor_name", "status", "created_at"}).
			AddRow(2, 1, 30.0, "Ana", "APPROVED", criadaEm).
			AddRow(1, 2, 50.0, "Maria", "APPROVED", criadaEm))

	rec := httptest.NewRecorder()
	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/donations", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, esperado 200", rec.Code)
	}
	var donations []Donation
	if err := json.NewDecoder(rec.Body).Decode(&donations); err != nil {
		t.Fatalf("resposta inválida: %v", err)
	}
	if len(donations) != 2 || donations[0].ID != 2 {
		t.Fatalf("lista inesperada: %+v", donations)
	}
}

func TestDonationsRejectsOtherMethods(t *testing.T) {
	app, _ := newTestApp(t, nil)
	rec := httptest.NewRecorder()

	app.Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/donations", nil))

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("status = %d, esperado 405", rec.Code)
	}
}
