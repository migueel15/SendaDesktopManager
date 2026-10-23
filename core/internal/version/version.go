// Package version exposes the senda build version.
package version

import "strings"

// Version is the senda version. It defaults to "dev" and is set at build
// time with -ldflags "-X github.com/migueel15/SendaDesktopManager/core/internal/version.Version=<value>".
// Nightly builds use a value starting with NightlyPrefix.
var Version = "dev"

// NightlyPrefix starts the version of every nightly build.
const NightlyPrefix = "nightly-"

// IsNightly reports whether this build comes from the nightly channel.
func IsNightly() bool {
	return strings.HasPrefix(Version, NightlyPrefix)
}
