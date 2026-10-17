// Package version exposes the senda build version.
package version

// Version is the senda version. It defaults to "dev" and is set at build
// time with -ldflags "-X github.com/migueel15/SendaDesktopManager/core/internal/version.Version=<value>".
var Version = "dev"
