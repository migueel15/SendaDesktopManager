package paths

import (
	"os"
	"path/filepath"
)

const appName = "senda"

// ConfigDir holds user settings and secrets, such as the .env file.
func ConfigDir() string {
	return filepath.Join(xdgDir("XDG_CONFIG_HOME", ".config"), appName)
}

// DataDir holds the files Senda needs to run but that are not user settings.
// SENDA_HOME overrides it, which is how a development checkout is used.
func DataDir() string {
	if home := os.Getenv("SENDA_HOME"); home != "" {
		return home
	}
	return filepath.Join(xdgDir("XDG_DATA_HOME", ".local/share"), appName)
}

// QuickshellDir is the Quickshell project that `senda shell run` starts.
func QuickshellDir() string {
	return filepath.Join(DataDir(), "quickshell")
}

// DiscordBridgeScript is the installed Discord bridge, relative to DataDir.
func DiscordBridgeScript() string {
	return filepath.Join(DataDir(), "scripts", "discord-bridge.py")
}

// EnvFile holds DORLAB_API_KEY and other private values.
func EnvFile() string {
	return filepath.Join(ConfigDir(), ".env")
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
