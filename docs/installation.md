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

```sh
senda setup
```

Según `core/internal/setup/setup.go`, `senda setup`:

1. Se niega a ejecutarse como root y comprueba que el sistema es Arch Linux con Hyprland.
2. Lista las dependencias que faltan y, si respondes `s`, las instala con `sudo pacman -S --needed`. Las que no están en los repositorios oficiales (como `blueberry`, de AUR) se indican para instalarlas a mano. La lista está en `core/internal/setup/packages.go`:

   | Uso | Paquetes |
   |---|---|
   | Shell y compositor | `quickshell`, `hyprland`, `hyprlock` |
   | Fondo de pantalla | `awww` |
   | Red, audio y batería | `networkmanager`, `wireplumber`, `upower` |
   | Bluetooth | `bluez`, `bluez-utils`, `blueberry` |
   | Brillo de monitores externos | `ddcutil` |
   | Sonidos del sistema | `ffmpeg`, `sound-theme-freedesktop` |
   | Enlaces, dictado y scripts | `xdg-utils`, `jq`, `python`, `wl-clipboard`, `wtype`, `pipewire` |
   | Fuentes | `inter-font`, `ttf-nerd-fonts-symbols` |

   Las dependencias con comando se buscan en `PATH`; las fuentes, el tema de sonidos y `bluez` se comprueban con `pacman -Q`.
3. Crea `~/.config/senda/config` si no existe.
4. Descarga, verifica e instala los archivos de Quickshell de la última release.
5. Detiene cualquier instancia de Quickshell lanzada a mano y crea la unidad de usuario `~/.config/systemd/user/senda.service`, la habilita y la arranca.
6. Crea `~/.config/hypr/modules/senda_binds.lua` si no existe. Si Hyprland aún no carga el módulo, indica que añadas `require("modules.senda_binds")` a `hyprland.lua`; no modifica la configuración de Hyprland. El motor y los modelos de dictado se instalan por separado desde Ajustes → Dictado o con `senda stt runtime install` y `senda stt models install <id>`.

Desde ese momento Senda arranca sola en cada inicio de sesión; no hace falta modificar `hyprland.lua` para que arranque el servicio. Para activar el atajo, sí debes añadir manualmente `require("modules.senda_binds")` a `hyprland.lua` si todavía no carga ese módulo. Si tu configuración lanza `senda shell run`, quita esa línea.

### El servicio `senda.service`

- Ejecuta `<ruta del binario> shell run`. En el futuro ejecutará todo lo que Senda corra en segundo plano.
- Está enlazado a `default.target`, porque Hyprland sin UWSM no arranca `graphical-session.target`. Mientras Hyprland no haya exportado `WAYLAND_DISPLAY` y `HYPRLAND_INSTANCE_SIGNATURE` a systemd, `ExecStartPre` falla y systemd reintenta cada 2 segundos.
- Si Quickshell termina con error, systemd lo reinicia.
- `senda shell run`, `senda shell kill` y `senda shell restart` usan `systemctl --user start|stop|restart senda` cuando la unidad está instalada.

Para ver su estado y registros:

```sh
systemctl --user status senda
journalctl --user -u senda -f
```

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
6. Detiene el puente de Discord y reinicia `senda.service`, aunque solo se hayan sincronizado los archivos. Si la unidad no está instalada, detiene Quickshell y lo arranca con `senda shell run`.

Si la versión instalada ya coincide con la última release, no hace nada. Si el binario ya está en la última versión pero el archivo `version` del directorio de datos no coincide (por ejemplo, tras la primera instalación), sincroniza solo los archivos de Quickshell.

`senda update` se niega a ejecutarse en binarios de desarrollo y cuando `SENDA_HOME` está definido (ver [configuration.md](configuration.md)).

## Desinstalar (`senda uninstall`)

```sh
senda uninstall
```

Pide confirmación (`-y` la omite) y después:

1. Detiene, deshabilita y elimina `senda.service`.
2. Detiene Quickshell y el puente de Discord si siguen en marcha.
3. Intenta cancelar el dictado. Si existe el módulo `~/.config/hypr/modules/senda_binds.lua`, lo sustituye por una versión desactivada y trata de recargar Hyprland; si falla, muestra un aviso. Indica que puedes quitar el `require` de `hyprland.lua`.
4. Elimina `~/.local/share/senda` (incluidos los modelos y el entorno del motor), `~/.config/senda`, `~/.local/state/senda` (incluido el token de Google Calendar) y el propio binario.

No elimina los paquetes instalados con pacman. Se niega a ejecutarse cuando `SENDA_HOME` está definido, para no borrar un checkout de desarrollo.
