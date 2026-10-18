package googlecalendar

// The OAuth client Senda ships with. Release builds set both values at link
// time with -ldflags -X from GitHub Actions secrets, so they never live in the
// repository. Source builds leave them empty and need the user's own client.
var (
	embeddedClientID     string
	embeddedClientSecret string
)

// ResolveCredentials picks the OAuth client. A client ID in the settings file
// means the user brings their own client, so both values come from the file.
// Otherwise the client embedded at build time is used. The two values are
// never mixed, because a secret only works with the client it was issued for.
func ResolveCredentials(configuredID, configuredSecret string) Credentials {
	if configuredID != "" {
		return Credentials{ClientID: configuredID, ClientSecret: configuredSecret}
	}
	return Credentials{ClientID: embeddedClientID, ClientSecret: embeddedClientSecret}
}

// HasEmbeddedCredentials reports whether this build includes Senda's client.
func HasEmbeddedCredentials() bool {
	return embeddedClientID != "" && embeddedClientSecret != ""
}
