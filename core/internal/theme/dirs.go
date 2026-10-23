package theme

import (
	"path/filepath"

	"github.com/migueel15/SendaDesktopManager/core/internal/paths"
)

// DefaultDirs devuelve las carpetas de temas integrados y de usuario.
func DefaultDirs() Dirs {
	return Dirs{
		Builtin: filepath.Join(paths.QuickshellDir(), "themes"),
		User:    filepath.Join(paths.ConfigDir(), "themes"),
	}
}
