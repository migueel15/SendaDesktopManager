package googlecalendar

import "testing"

func withEmbedded(t *testing.T, id, secret string) {
	t.Helper()
	previousID, previousSecret := embeddedClientID, embeddedClientSecret
	embeddedClientID, embeddedClientSecret = id, secret
	t.Cleanup(func() {
		embeddedClientID, embeddedClientSecret = previousID, previousSecret
	})
}

func TestResolveCredentialsUsesEmbeddedClientWhenNothingConfigured(t *testing.T) {
	withEmbedded(t, "embedded-id", "embedded-secret")

	got := ResolveCredentials("", "")
	if got.ClientID != "embedded-id" || got.ClientSecret != "embedded-secret" {
		t.Fatalf("ResolveCredentials() = %+v, want the embedded client", got)
	}
}

func TestResolveCredentialsPrefersOwnClientAsAPair(t *testing.T) {
	withEmbedded(t, "embedded-id", "embedded-secret")

	got := ResolveCredentials("own-id", "")
	if got.ClientID != "own-id" || got.ClientSecret != "" {
		t.Fatalf("ResolveCredentials() = %+v; a configured ID must not borrow the embedded secret", got)
	}
}

func TestHasEmbeddedCredentialsNeedsBothValues(t *testing.T) {
	withEmbedded(t, "embedded-id", "")
	if HasEmbeddedCredentials() {
		t.Fatal("HasEmbeddedCredentials() = true without a secret")
	}

	withEmbedded(t, "embedded-id", "embedded-secret")
	if !HasEmbeddedCredentials() {
		t.Fatal("HasEmbeddedCredentials() = false with both values")
	}
}
