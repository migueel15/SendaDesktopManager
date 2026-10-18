# Instalación

Senda se distribuye como binario precompilado para Linux x86_64 desde las releases de GitHub. Hoy el instalador solo comprueba la plataforma; el soporte de Arch y Hyprland previsto para la v1 no se valida en el código.

## Instalar con el instalador

La página de instalación publica este comando:

```sh
curl --proto '=https' --tlsv1.2 -fsSL https://senda.dorlab.net/install.sh | bash
```

La URL se sirve con GitHub Pages en el dominio personalizado `senda.dorlab.net`, configurado mediante `site/CNAME`. El workflow [pages.yml](../.github/workflows/pages.yml) copia `install.sh` dentro de `site/` antes de publicar.

### Qué hace `install.sh`

1. Se niega a ejecutarse como root.
2. Comprueba que el sistema es Linux x86_64 y que existen `curl` y `sha256sum`.
3. Consulta la última release en la API de GitHub y valida que la etiqueta tiene la forma `vX.Y.Z`.
4. Descarga el binario `senda-<tag>-linux-amd64` y `checksums.txt`. Todas las descargas usan HTTPS (`--proto '=https' --tlsv1.2`).
5. Verifica la suma SHA-256 del binario. Si falla, no instala nada.
6. Copia el binario a `${SENDA_BIN_DIR:-$HOME/.local/bin}/senda` con un renombrado atómico y permisos `755`.
7. Si el directorio de instalación no está en `PATH`, muestra la línea de `export` que hay que añadir.

El instalador no usa `sudo` y no modifica la configuración de Hyprland.

El instalador copia solo el binario. Los archivos de Quickshell y del puente de Discord los instala `senda update` (ver más abajo).

## Configuración inicial (`senda setup`)

`senda setup` todavía no existe en este repositorio: no hay ningún comando registrado con ese nombre en `core/cmd/senda/`. El mensaje final de `install.sh` indica ejecutarlo, por lo que hasta que se implemente ese paso fallará. La sección se completará cuando el comando esté en el código.

## Actualizar (`senda update`)

```sh
senda update
```

Según el código de `core/cmd/senda/command_update.go`:

1. Obtiene la última release de GitHub.
2. Si la release es distinta de la versión del binario, descarga y verifica por SHA-256 el nuevo binario.
3. Descarga y verifica por SHA-256 `senda-quickshell-<tag>.tar.gz`.
4. Reemplaza en `$XDG_DATA_HOME/senda` (por defecto `~/.local/share/senda`) las entradas `quickshell/`, `scripts/` y `version`.
5. Si cambió la versión, reemplaza el binario en su sitio.
6. Detiene Quickshell y lo vuelve a arrancar con `senda shell run`, aunque solo se hayan sincronizado los archivos.

Si la versión instalada ya coincide con la última release, no hace nada. Si el binario ya está en la última versión pero el archivo `version` del directorio de datos no coincide (por ejemplo, tras la primera instalación), sincroniza solo los archivos de Quickshell.

`senda update` se niega a ejecutarse en binarios de desarrollo y cuando `SENDA_HOME` está definido (ver [configuration.md](configuration.md)).

## Desinstalación

No hay comando de desinstalación. Para quitar el binario, elimina `~/.local/bin/senda` (o la ruta de `SENDA_BIN_DIR`). Los datos están en `~/.local/share/senda` y la configuración en `~/.config/senda`.
