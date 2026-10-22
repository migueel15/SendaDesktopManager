package googlecalendar

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fakeGoogle serves the token and revoke endpoints and records what it got.
type fakeGoogle struct {
	t               *testing.T
	token           *httptest.Server
	revoke          *httptest.Server
	calendar        *httptest.Server
	tokenForms      []url.Values
	refreshReply    string
	calendarHandler func(http.ResponseWriter, *http.Request)
}

func newFakeGoogle(t *testing.T) *fakeGoogle {
	t.Helper()
	fake := &fakeGoogle{t: t}

	fake.token = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		fake.tokenForms = append(fake.tokenForms, r.PostForm)

		switch r.PostForm.Get("grant_type") {
		case "authorization_code":
			fmt.Fprint(w, `{"access_token":"access-1","expires_in":3600,"refresh_token":"refresh-1"}`)
		case "refresh_token":
			if fake.refreshReply == "invalid_grant" {
				w.WriteHeader(http.StatusBadRequest)
				fmt.Fprint(w, `{"error":"invalid_grant"}`)
				return
			}
			fmt.Fprint(w, `{"access_token":"access-2","expires_in":3600}`)
		default:
			http.Error(w, "unexpected grant", http.StatusBadRequest)
		}
	}))
	t.Cleanup(fake.token.Close)

	fake.revoke = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.ReadAll(r.Body)
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(fake.revoke.Close)

	// Calendar routes are installed by each test through fake.handleCalendar.
	fake.calendar = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fake.calendarHandler(w, r)
	}))
	t.Cleanup(fake.calendar.Close)
	return fake
}

func newTestClient(t *testing.T, fake *fakeGoogle, creds Credentials) (*Client, TokenStore) {
	t.Helper()
	store := testTokenStore(filepath.Join(t.TempDir(), "google-calendar.json"))
	client := NewClient(creds, store)
	client.endpoints = Endpoints{
		Auth:     "https://accounts.example.test/auth",
		Token:    fake.token.URL,
		Revoke:   fake.revoke.URL,
		Calendar: fake.calendar.URL,
	}
	return client, store
}

var testCreds = Credentials{ClientID: "client-id", ClientSecret: "client-secret"}

func TestLoginStoresRefreshTokenAfterPKCEExchange(t *testing.T) {
	fake := newFakeGoogle(t)
	client, store := newTestClient(t, fake, testCreds)

	handleURL := func(authURL string) error {
		parsed, err := url.Parse(authURL)
		if err != nil {
			return err
		}
		query := parsed.Query()
		if got := query.Get("code_challenge_method"); got != "S256" {
			return fmt.Errorf("code_challenge_method = %q, want S256", got)
		}
		if !strings.Contains(query.Get("scope"), EventsReadonlyScope) || !strings.Contains(query.Get("scope"), CalendarListReadonlyScope) {
			return fmt.Errorf("scope = %q, missing read-only calendar scopes", query.Get("scope"))
		}
		if query.Get("access_type") != "offline" {
			return errors.New("access_type must be offline to receive a refresh token")
		}

		// Simulate the browser completing consent.
		go func() {
			callback := fmt.Sprintf("%s?code=auth-code&state=%s", query.Get("redirect_uri"), query.Get("state"))
			response, err := http.Get(callback)
			if err == nil {
				response.Body.Close()
			}
		}()
		return nil
	}

	if err := client.Login(context.Background(), handleURL); err != nil {
		t.Fatalf("Login() error = %v", err)
	}

	if len(fake.tokenForms) != 1 {
		t.Fatalf("token requests = %d, want 1", len(fake.tokenForms))
	}
	form := fake.tokenForms[0]
	if form.Get("code") != "auth-code" {
		t.Fatalf("code = %q, want auth-code", form.Get("code"))
	}
	if form.Get("client_secret") != testCreds.ClientSecret {
		t.Fatal("token request did not send the client secret")
	}

	got, err := store.Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if got != "refresh-1" {
		t.Fatalf("stored refresh token = %q, want refresh-1", got)
	}
}

func TestLoginRejectsStateMismatch(t *testing.T) {
	fake := newFakeGoogle(t)
	client, store := newTestClient(t, fake, testCreds)

	handleURL := func(authURL string) error {
		parsed, _ := url.Parse(authURL)
		go func() {
			response, err := http.Get(parsed.Query().Get("redirect_uri") + "?code=auth-code&state=forged")
			if err == nil {
				response.Body.Close()
			}
		}()
		return nil
	}

	if err := client.Login(context.Background(), handleURL); err == nil {
		t.Fatal("Login() accepted a callback with a forged state")
	}
	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("a rejected login stored a token: %v", err)
	}
}

func TestLoginRequiresCredentials(t *testing.T) {
	fake := newFakeGoogle(t)
	client, _ := newTestClient(t, fake, Credentials{})

	err := client.Login(context.Background(), func(string) error { return nil })
	if !errors.Is(err, ErrMissingCredentials) {
		t.Fatalf("Login() error = %v, want ErrMissingCredentials", err)
	}
}

func TestAccessTokenIsCachedUntilItNearsExpiry(t *testing.T) {
	fake := newFakeGoogle(t)
	client, store := newTestClient(t, fake, testCreds)
	if err := store.Save("refresh-1"); err != nil {
		t.Fatal(err)
	}

	now := time.Date(2026, 10, 18, 10, 0, 0, 0, time.UTC)
	client.now = func() time.Time { return now }

	first, err := client.AccessToken(context.Background())
	if err != nil {
		t.Fatalf("AccessToken() error = %v", err)
	}
	second, err := client.AccessToken(context.Background())
	if err != nil {
		t.Fatalf("AccessToken() error = %v", err)
	}
	if first != "access-2" || second != "access-2" {
		t.Fatalf("tokens = %q, %q; want access-2 twice", first, second)
	}
	if len(fake.tokenForms) != 1 {
		t.Fatalf("token requests = %d, want 1 while the cache is valid", len(fake.tokenForms))
	}

	client.now = func() time.Time { return now.Add(time.Hour) }
	if _, err := client.AccessToken(context.Background()); err != nil {
		t.Fatalf("AccessToken() after expiry error = %v", err)
	}
	if len(fake.tokenForms) != 2 {
		t.Fatalf("token requests = %d, want 2 after expiry", len(fake.tokenForms))
	}
}

func TestAccessTokenReportsExpiredSession(t *testing.T) {
	fake := newFakeGoogle(t)
	fake.refreshReply = "invalid_grant"
	client, store := newTestClient(t, fake, testCreds)
	if err := store.Save("revoked"); err != nil {
		t.Fatal(err)
	}

	if _, err := client.AccessToken(context.Background()); !errors.Is(err, ErrSessionExpired) {
		t.Fatalf("AccessToken() error = %v, want ErrSessionExpired", err)
	}
}

func TestLogoutDeletesTokenAndRevokes(t *testing.T) {
	fake := newFakeGoogle(t)
	client, store := newTestClient(t, fake, testCreds)
	if err := store.Save("refresh-1"); err != nil {
		t.Fatal(err)
	}

	if err := client.Logout(context.Background()); err != nil {
		t.Fatalf("Logout() error = %v", err)
	}
	if _, err := store.Load(); !errors.Is(err, ErrNotConnected) {
		t.Fatalf("token still stored after logout: %v", err)
	}
	connected, err := client.Connected()
	if err != nil || connected {
		t.Fatalf("Connected() = %v, %v; want false, nil", connected, err)
	}
}

func TestLogoutWithoutTokenIsNoOp(t *testing.T) {
	fake := newFakeGoogle(t)
	client, _ := newTestClient(t, fake, testCreds)

	if err := client.Logout(context.Background()); err != nil {
		t.Fatalf("Logout() error = %v", err)
	}
}
