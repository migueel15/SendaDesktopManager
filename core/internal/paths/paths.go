package paths

import (
	"log"
	"os"
	"path/filepath"
	"sync"

	"github.com/migueel15/SendaDesktopManager/core/internal/config"
	"github.com/migueel15/SendaDesktopManager/core/internal/secrets"
)

const appName = "senda"

// configErrorOnce ensures a broken config file is reported once per process,
// because Setting is called from several places.
var configErrorOnce sync.Once

// ConfigDir holds the user's portable settings. It never holds secrets.
func ConfigDir() string {
	return filepath.Join(xdgDir("XDG_CONFIG_HOME", ".config"), appName)
}

// DataDir holds the files Senda needs to run but that are not user settings.
// SENDA_HOME overrides it, which is how a development checkout is used. It is
// read only from the environment, never from the config file.
func DataDir() string {
	if home := os.Getenv("SENDA_HOME"); home != "" {
		return home
	}
	return filepath.Join(xdgDir("XDG_DATA_HOME", ".local/share"), appName)
}

// StateDir holds state that must survive restarts but is not a user setting,
// such as the Google Calendar refresh token.
func StateDir() string {
	return filepath.Join(xdgDir("XDG_STATE_HOME", ".local/state"), appName)
}

// GoogleCalendarTokenFile identifies the legacy token file for migration and
// namespaces the Secret Service entry. New tokens are stored in the keyring.
func GoogleCalendarTokenFile() string {
	return filepath.Join(StateDir(), "google-calendar.json")
}

// QuickshellDir is the Quickshell project that `senda shell run` starts.
func QuickshellDir() string {
	return filepath.Join(DataDir(), "quickshell")
}

// DiscordBridgeScript is the installed Discord bridge, relative to DataDir.
func DiscordBridgeScript() string {
	return filepath.Join(DataDir(), "scripts", "discord-bridge.py")
}

// ConfigFile holds KEY=VALUE preferences. It can be shared between computers.
func ConfigFile() string {
	return filepath.Join(ConfigDir(), "config")
}

// WallpapersDir holds the wallpapers offered by the picker. It lives in the
// config directory so copying that directory keeps them.
func WallpapersDir() string {
	return filepath.Join(ConfigDir(), "wallpapers")
}

// Setting returns the value of name. An environment variable takes precedence
// over the config file, and both are empty when the setting is not defined.
func Setting(name string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}

	values, err := config.Load(ConfigFile())
	if err != nil {
		configErrorOnce.Do(func() {
			log.Println("error reading config:", err)
		})
		return ""
	}
	return values[name]
}

// SecretsFile holds the secrets that the keyring could not keep. It lives in
// StateDir so that sharing the config folder never includes it.
func SecretsFile() string {
	return filepath.Join(StateDir(), "secrets")
}

// Secrets returns the store of sensitive settings.
func Secrets() secrets.Store {
	return secrets.Store{FallbackFile: SecretsFile()}
}

// Secret returns a sensitive setting. An environment variable takes
// precedence. Values still in the config file are moved out first. Failures
// are logged without the value and the secret reads as empty.
func Secret(name string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	store := Secrets()
	if err := store.Migrate(ConfigFile()); err != nil {
		log.Println("error moving secrets out of the config file:", err)
	}
	value, err := store.Get(name)
	if err != nil {
		log.Println("error reading", name+":", err)
	}
	return value
}

// VersionFile records the release whose files are installed in DataDir.
func VersionFile() string {
	return filepath.Join(DataDir(), "version")
}

func xdgDir(envKey string, fallback string) string {
	if dir := os.Getenv(envKey); filepath.IsAbs(dir) {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return fallback
	}
	return filepath.Join(home, fallback)
}
