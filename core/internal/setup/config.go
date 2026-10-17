package setup

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// configTemplate is written to a new config file. It holds no secret values;
// the user fills in DORLAB_API_KEY.
const configTemplate = `# Configuración de Senda.
# Este archivo guarda valores privados, como claves de API.
# No lo compartas ni lo subas a ningún repositorio.
DORLAB_API_KEY=
`

// ensureConfig creates configDir with mode 0700 when missing, and creates
// configFile with mode 0600 from the template. An existing file is never
// overwritten, and its contents are never printed.
func ensureConfig(configDir string, configFile string, out io.Writer) error {
	if _, err := os.Stat(configDir); errors.Is(err, os.ErrNotExist) {
		if err := os.MkdirAll(filepath.Dir(configDir), 0o755); err != nil {
			return fmt.Errorf("crear %s: %w", filepath.Dir(configDir), err)
		}
		if err := os.Mkdir(configDir, 0o700); err != nil {
			return fmt.Errorf("crear %s: %w", configDir, err)
		}
	} else if err != nil {
		return fmt.Errorf("revisar %s: %w", configDir, err)
	}

	// O_EXCL guarantees an existing file is never overwritten.
	f, err := os.OpenFile(configFile, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if errors.Is(err, os.ErrExist) {
		fmt.Fprintf(out, "Configuración existente conservada: %s\n", configFile)
		return nil
	}
	if err != nil {
		return fmt.Errorf("crear %s: %w", configFile, err)
	}
	if _, err := f.WriteString(configTemplate); err != nil {
		f.Close()
		return fmt.Errorf("escribir %s: %w", configFile, err)
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("cerrar %s: %w", configFile, err)
	}
	fmt.Fprintf(out, "Configuración creada: %s\n", configFile)
	return nil
}
