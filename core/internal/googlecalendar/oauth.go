package googlecalendar

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	// EventsReadonlyScope lets Senda read events, and nothing else.
	EventsReadonlyScope = "https://www.googleapis.com/auth/calendar.events.readonly"
	// CalendarListReadonlyScope lets Senda list the calendars the user chose.
	CalendarListReadonlyScope = "https://www.googleapis.com/auth/calendar.calendarlist.readonly"

	loginTimeout = 5 * time.Minute
	maxResponse  = 1 << 20
	// refreshMargin renews the access token before it expires, so a request
	// never starts with a token that is about to fail.
	refreshMargin = time.Minute
)

// ErrMissingCredentials means the OAuth client ID or secret is not configured.
var ErrMissingCredentials = errors.New("set SENDA_GOOGLE_CLIENT_ID and SENDA_GOOGLE_CLIENT_SECRET in the config file")

// ErrSessionExpired means Google rejected the refresh token. The user must log
// in again.
var ErrSessionExpired = errors.New("google session expired; run `senda calendar login` again")

// Endpoints are Google's OAuth URLs. Tests replace them with a local server.
type Endpoints struct {
	Auth     string
	Token    string
	Revoke   string
	Calendar string
}

// DefaultEndpoints are the production URLs.
var DefaultEndpoints = Endpoints{
	Auth:     "https://accounts.google.com/o/oauth2/v2/auth",
	Token:    "https://oauth2.googleapis.com/token",
	Revoke:   "https://oauth2.googleapis.com/revoke",
	Calendar: "https://www.googleapis.com/calendar/v3",
}

// Credentials identify Senda's OAuth client, created as a desktop application.
type Credentials struct {
	ClientID     string
	ClientSecret string
}

// Client runs the login flow and hands out access tokens for API calls.
type Client struct {
	creds     Credentials
	store     TokenStore
	endpoints Endpoints
	http      *http.Client
	now       func() time.Time

	accessToken string
	expiresAt   time.Time
}

// NewClient returns a client that stores its token in store.
func NewClient(creds Credentials, store TokenStore) *Client {
	return &Client{
		creds:     creds,
		store:     store,
		endpoints: DefaultEndpoints,
		http:      &http.Client{Timeout: 30 * time.Second},
		now:       time.Now,
	}
}

// Connected reports whether a refresh token is stored.
func (c *Client) Connected() (bool, error) {
	_, err := c.store.Load()
	if errors.Is(err, ErrNotConnected) {
		return false, nil
	}
	return err == nil, err
}

// Login runs the authorization code flow with PKCE. handleURL receives the
// consent URL; the user opens it, and Google redirects to a loopback address
// that this process listens on.
func (c *Client) Login(ctx context.Context, handleURL func(authURL string) error) error {
	if c.creds.ClientID == "" || c.creds.ClientSecret == "" {
		return ErrMissingCredentials
	}

	verifier, err := randomToken(64)
	if err != nil {
		return err
	}
	state, err := randomToken(16)
	if err != nil {
		return err
	}

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("listen for the Google redirect: %w", err)
	}
	redirectURI := fmt.Sprintf("http://%s/callback", listener.Addr().String())

	callbacks := make(chan callbackResult, 1)
	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		result := readCallback(r.URL.Query(), state)
		if result.err != nil {
			http.Error(w, "Senda could not complete the Google login. You can close this tab.", http.StatusBadRequest)
		} else {
			fmt.Fprint(w, "Senda is connected to Google Calendar. You can close this tab.")
		}
		select {
		case callbacks <- result:
		default:
		}
	})
	server := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	go server.Serve(listener)
	defer server.Close()

	authURL := c.authorizationURL(redirectURI, state, codeChallenge(verifier))
	if err := handleURL(authURL); err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(ctx, loginTimeout)
	defer cancel()
	var code string
	select {
	case result := <-callbacks:
		if result.err != nil {
			return result.err
		}
		code = result.code
	case <-ctx.Done():
		return fmt.Errorf("login was not completed: %w", ctx.Err())
	}

	tokens, err := c.requestToken(ctx, url.Values{
		"grant_type":    {"authorization_code"},
		"code":          {code},
		"code_verifier": {verifier},
		"redirect_uri":  {redirectURI},
		"client_id":     {c.creds.ClientID},
		"client_secret": {c.creds.ClientSecret},
	})
	if err != nil {
		return err
	}
	if tokens.RefreshToken == "" {
		return errors.New("google did not return a refresh token; remove Senda's access in your Google account and log in again")
	}
	if err := c.store.Save(tokens.RefreshToken); err != nil {
		return err
	}
	c.setAccessToken(tokens)
	return nil
}

// AccessToken returns a valid access token, renewing it with the stored
// refresh token when needed.
func (c *Client) AccessToken(ctx context.Context) (string, error) {
	if c.accessToken != "" && c.now().Before(c.expiresAt.Add(-refreshMargin)) {
		return c.accessToken, nil
	}

	refreshToken, err := c.store.Load()
	if err != nil {
		return "", err
	}
	tokens, err := c.requestToken(ctx, url.Values{
		"grant_type":    {"refresh_token"},
		"refresh_token": {refreshToken},
		"client_id":     {c.creds.ClientID},
		"client_secret": {c.creds.ClientSecret},
	})
	if err != nil {
		return "", err
	}
	// Google may issue a new refresh token; keep the newest one.
	if tokens.RefreshToken != "" {
		if err := c.store.Save(tokens.RefreshToken); err != nil {
			return "", err
		}
	}
	c.setAccessToken(tokens)
	return c.accessToken, nil
}

// Logout revokes the refresh token at Google and deletes the local copy. The
// local file is removed first, so a failed revocation never leaves a usable
// token on disk.
func (c *Client) Logout(ctx context.Context) error {
	refreshToken, err := c.store.Load()
	if errors.Is(err, ErrNotConnected) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := c.store.Delete(); err != nil {
		return err
	}
	c.accessToken = ""

	if err := c.revoke(ctx, refreshToken); err != nil {
		return fmt.Errorf("local token removed, but Google did not confirm the revocation: %w", err)
	}
	return nil
}

func (c *Client) authorizationURL(redirectURI, state, challenge string) string {
	query := url.Values{
		"client_id":             {c.creds.ClientID},
		"redirect_uri":          {redirectURI},
		"response_type":         {"code"},
		"scope":                 {EventsReadonlyScope + " " + CalendarListReadonlyScope},
		"state":                 {state},
		"code_challenge":        {challenge},
		"code_challenge_method": {"S256"},
		"access_type":           {"offline"},
		"prompt":                {"consent"},
	}
	return c.endpoints.Auth + "?" + query.Encode()
}

func (c *Client) setAccessToken(tokens tokenResponse) {
	c.accessToken = tokens.AccessToken
	c.expiresAt = c.now().Add(time.Duration(tokens.ExpiresIn) * time.Second)
}

type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
}

func (c *Client) requestToken(ctx context.Context, form url.Values) (tokenResponse, error) {
	var tokens tokenResponse
	body, status, err := c.post(ctx, c.endpoints.Token, form)
	if err != nil {
		return tokens, err
	}
	if status == http.StatusBadRequest && strings.Contains(string(body), "invalid_grant") {
		return tokens, ErrSessionExpired
	}
	if status != http.StatusOK {
		return tokens, fmt.Errorf("google token request failed with status %d", status)
	}
	if err := json.Unmarshal(body, &tokens); err != nil {
		return tokens, fmt.Errorf("decode google token response: %w", err)
	}
	if tokens.AccessToken == "" {
		return tokens, errors.New("google token response has no access token")
	}
	return tokens, nil
}

func (c *Client) revoke(ctx context.Context, token string) error {
	body, status, err := c.post(ctx, c.endpoints.Revoke, url.Values{"token": {token}})
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return fmt.Errorf("status %d: %s", status, strings.TrimSpace(string(body)))
	}
	return nil
}

func (c *Client) post(ctx context.Context, endpoint string, form url.Values) ([]byte, int, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, 0, err
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	response, err := c.http.Do(request)
	if err != nil {
		return nil, 0, fmt.Errorf("reach google: %w", err)
	}
	defer response.Body.Close()

	body, err := io.ReadAll(io.LimitReader(response.Body, maxResponse))
	if err != nil {
		return nil, 0, err
	}
	return body, response.StatusCode, nil
}

type callbackResult struct {
	code string
	err  error
}

func readCallback(query url.Values, expectedState string) callbackResult {
	if denied := query.Get("error"); denied != "" {
		return callbackResult{err: fmt.Errorf("google did not grant access: %s", denied)}
	}
	if query.Get("state") != expectedState {
		return callbackResult{err: errors.New("state does not match; the login attempt was rejected")}
	}
	code := query.Get("code")
	if code == "" {
		return callbackResult{err: errors.New("google redirect has no authorization code")}
	}
	return callbackResult{code: code}
}

// codeChallenge is the S256 transform of the PKCE verifier.
func codeChallenge(verifier string) string {
	sum := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}

func randomToken(bytes int) (string, error) {
	buffer := make([]byte, bytes)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buffer), nil
}
