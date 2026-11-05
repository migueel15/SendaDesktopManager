# Instalación

Zenda se distribuye como binario precompilado para Linux x86_64 desde las releases de GitHub. Hoy el instalador solo comprueba la plataforma; el soporte de Arch y Hyprland previsto para la v1 no se valida en el código.

## Instalar con el instalador

La página de instalación publica este comando:

```sh
curl --proto '=https' --tlsv1.2 -fsSL https://zenda.dorlab.net/install.sh | bash
```

La URL se sirve con GitHub Pages en el dominio personalizado `zenda.dorlab.net`, configurado mediante `site/CNAME`. El workflow [pages.yml](../.github/workflows/pages.yml) copia `install.sh` dentro de `site/` antes de publicar.

### Qué hace `install.sh`

1. Se niega a ejecutarse como root.
2. Comprueba que el sistema es Linux x86_64 y que existen `curl` y `sha256sum`.
3. Lee la etiqueta de la última release del canal en su `latest.json` (estable: `releases/latest/download/latest.json`; nightly: `releases/download/nightly/latest.json`) y valida su forma. Son URLs de descarga, no de la API de GitHub, así que no cuentan para su límite de 60 peticiones por hora.
4. Descarga el binario `zenda-<tag>-linux-amd64` y `checksums.txt`. Todas las descargas usan HTTPS (`--proto '=https' --tlsv1.2`).
5. Verifica la suma SHA-256 del binario. Si falla, no instala nada.
6. Copia el binario a `${ZENDA_BIN_DIR:-$HOME/.local/bin}/zenda` con un renombrado atómico y permisos `755`.
7. Si el directorio de instalación no está en `PATH`, muestra la línea de `export` que hay que añadir.

El instalador no usa `sudo` y no modifica la configuración de Hyprland.

El instalador copia solo el binario. Los archivos de Quickshell y del puente de Discord los instala `zenda update` (ver más abajo).

## Configuración inicial (`zenda setup`)

```sh
zenda setup
```

Según `core/internal/setup/setup.go`, `zenda setup`:

1. Se niega a ejecutarse como root y comprueba que el sistema es Arch Linux con Hyprland.
2. Lista las dependencias que faltan y, si respondes `s`, las instala con `sudo pacman -S --needed`. Las que no están en los repositorios oficiales (como `blueberry`, de AUR) se indican para instalarlas a mano. La lista está en `core/internal/setup/packages.go`:

   | Uso | Paquetes |
   |---|---|
   | Shell y compositor | `quickshell`, `hyprland`, `hypridle` |
   | Autenticación de administrador | `polkit`; ver [polkit](polkit.md) |
   | Capturas de pantalla | `grim`, `wl-clipboard` |
   | Fondo de pantalla | Integrado en Quickshell; no requiere otro paquete. |
   | Red, audio y batería | `networkmanager`, `wireplumber`, `upower` |
   | Bluetooth | `bluez`, `bluez-utils`, `blueberry` |
   | Brillo de la pantalla y de monitores externos | `brightnessctl`, `ddcutil` |
   | Compartir pantalla y selectores de archivos (portales XDG) | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
   | Montaje automático de USB | `udisks2`; ver [USB](usb.md) |
   | Sonidos del sistema | `ffmpeg`, `sound-theme-freedesktop` |
   | Enlaces, dictado y scripts | `xdg-utils`, `jq`, `python`, `wl-clipboard`, `pipewire` |
   | Acceso al keyring de Google Calendar | `libsecret`; requiere además un proveedor Secret Service configurado y desbloqueado, véase [Google Calendar](google-calendar.md) |
   | Fuentes | `inter-font`, `ttf-nerd-fonts-symbols` |

   Las dependencias con comando se buscan en `PATH`; las fuentes, el tema de sonidos, los portales y `bluez` se comprueban con `pacman -Q`.
3. Crea `~/.config/zenda/config` si no existe.
4. Descarga, verifica e instala los archivos de Quickshell de la última release.
5. Ofrece instalar el motor de dictado si falta. Los modelos se instalan por separado con `zenda stt models install <id>`.
6. Genera `~/.config/hypr/zenda/` (con `init.lua`, un módulo por área, `hypridle.conf` y un `.gitignore` que lo ignora todo) a partir de los ajustes de Zenda. Conserva archivos sin cabecera propia y avisa de conflictos. Importa el atajo antiguo de dictado y migra referencias inequívocas de módulos anteriores cuando es seguro. Consulta [Bloqueo de pantalla](lock-screen.md).
7. Detiene cualquier instancia de Quickshell lanzada a mano y crea la unidad de usuario `~/.config/systemd/user/zenda.service`, la habilita y la arranca.

7. Comprueba si Zenda ya está vinculado a Hyprland preguntando a la sesión con `hyprctl` por la función `zenda_module_version`, que solo define el módulo de Zenda. Da igual dónde esté el módulo o cómo esté organizada la configuración: si la función existe, Zenda ya está vinculado y regenera el módulo en el archivo desde el que se cargó. Si no existe, añade `require("modules.zenda")` al final de `~/.config/hypr/hyprland.lua` (salvo que ya esté), recarga Hyprland y vuelve a comprobarlo. Fuera de una sesión de Hyprland la comprobación es la línea `require` de `hyprland.lua`. Después puedes mover esa línea donde prefieras.
8. Configura hypridle una sola vez:
   - Si no tienes `~/.config/hypr/hypridle.conf` ni un hypridle en ejecución, usa la configuración de Zenda: el módulo inicia `hypridle -c ~/.config/hypr/zenda/hypridle.conf` al arrancar Hyprland y, en sesión, se inicia en el momento.
   - Si ya tienes configuración o un hypridle en ejecución, pregunta si quieres conservar la tuya o usar la de Zenda (por defecto, la tuya). Tu archivo no se modifica.
   - Con la configuración de Zenda, cada `zenda setup` ofrece resolver los conflictos (por defecto, no cambia nada y avisa): parar y deshabilitar `hypridle.service` de systemd, comentar las líneas `exec…hypridle` de tu configuración de Hyprland (con `--` en `.lua` y `#` en `.conf`), cerrar los hypridle con otra configuración y reiniciar un hypridle con la configuración de Zenda que Zenda no gestiona. Si acabas de elegir la configuración de Zenda, cierra los hypridle externos sin volver a preguntar.
   - La elección se guarda en `ZENDA_IDLE_MODE` y no se vuelve a preguntar. Para cambiarla: `zenda hyprland set --idle-mode zenda` o `--idle-mode user`. Con `user`, el tiempo de inactividad de Zenda no se aplica.

Si tu configuración lanza `zenda shell run`, quita esa línea.

### El servicio `zenda.service`

- Ejecuta `<ruta del binario> shell run`. En el futuro ejecutará todo lo que Zenda corra en segundo plano.
- Está enlazado a `default.target`, porque Hyprland sin UWSM no arranca `graphical-session.target`. Mientras Hyprland no haya exportado `WAYLAND_DISPLAY` y `HYPRLAND_INSTANCE_SIGNATURE` a systemd, `ExecStartPre` falla y systemd reintenta cada 2 segundos.
- Si Quickshell termina con error, systemd lo reinicia.
- `zenda shell run`, `zenda shell kill` y `zenda shell restart` usan `systemctl --user start|stop|restart zenda` cuando la unidad está instalada.

Para ver su estado y registros:

```sh
systemctl --user status zenda
journalctl --user -u zenda -f
```

## Actualizar (`zenda update`)

```sh
zenda update
```

Según el código de `core/cmd/zenda/command_update.go`:

1. Obtiene la última release del canal desde su `latest.json`, sin usar la API de GitHub.
2. Si la release es distinta de la versión del binario, descarga y verifica por SHA-256 el nuevo binario.
3. Descarga y verifica por SHA-256 `zenda-quickshell-<tag>.tar.gz`.
4. Reemplaza en `$XDG_DATA_HOME/zenda` (por defecto `~/.local/share/zenda`) las entradas `quickshell/`, `scripts/` y `version`.
5. Si cambió la versión, reemplaza el binario en su sitio.
6. Detiene el puente de Discord y reinicia `zenda.service`, aunque solo se hayan sincronizado los archivos. Si la unidad no está instalada, detiene Quickshell y lo arranca con `zenda shell run`.

Si la versión instalada ya coincide con la última release, no hace nada. Si el binario ya está en la última versión pero el archivo `version` del directorio de datos no coincide (por ejemplo, tras la primera instalación), sincroniza solo los archivos de Quickshell.

### Comprobar sin actualizar

`zenda update --check` imprime un JSON con `current`, `latest`, `available` y `changes`. Cuando hay una versión nueva, `changes` lista los commits `feat`, `fix` y `perf` entre la versión instalada y la nueva, del más antiguo al más reciente, cada uno con `type`, `scope` y `summary`. Se obtiene del mismo `latest.json`, que guarda los commits de las últimas 50 releases del canal; si la versión instalada ya no figura en él, se listan todas las que contiene. Quickshell ejecuta esta comprobación al arrancar y cada 10 minutos.

Cada release estable publica su `latest.json` como un archivo más. El workflow nightly lo sube a una pre-release fija con la etiqueta `nightly`, que se actualiza en cada compilación y no se borra al limpiar las nightlies antiguas. Lo genera `core/scripts/release-manifest.sh`. La página **Actualización** de los ajustes muestra esta lista agrupada en «Nuevo», «Correcciones» y «Rendimiento».

`zenda update` se niega a ejecutarse en binarios de desarrollo y cuando `ZENDA_HOME` está definido (ver [configuration.md](configuration.md)).

## Desinstalar (`zenda uninstall`)

```sh
zenda uninstall
```

Pide confirmación (`-y` la omite) y después cancela el dictado, detiene la instancia de hypridle identificada como gestionada por Zenda, retira los archivos generados y la referencia marcada que haya añadido Zenda, y elimina el servicio, los datos, estado, configuración y binario. Si encuentra archivos no identificados como propios o referencias manuales, avisa y conserva la configuración cuando corresponda. Las referencias añadidas por el usuario deben retirarse manualmente. No detiene instancias independientes de hypridle.

No elimina los paquetes instalados con pacman. Se niega a ejecutarse cuando `ZENDA_HOME` está definido, para no borrar un checkout de desarrollo.

## Migración desde Senda

El proyecto se llamaba Senda. Al ejecutar cualquier comando de `zenda`, la configuración antigua (`~/.config/senda`, `~/.local/share/senda`, `~/.local/state/senda`, `~/.cache/senda`) se mueve a `zenda`, las claves `SENDA_*` pasan a `ZENDA_*` y las variables de entorno `SENDA_*` se aceptan como alias temporal. `zenda setup` sustituye `senda.service` por `zenda.service`. Consulta el [ADR 017](adr/adr-017-renombrado-a-zenda.md).
