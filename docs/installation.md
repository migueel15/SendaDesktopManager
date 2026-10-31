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
3. Lee la etiqueta de la última release del canal en su `latest.json` (estable: `releases/latest/download/latest.json`; nightly: `releases/download/nightly/latest.json`) y valida su forma. Son URLs de descarga, no de la API de GitHub, así que no cuentan para su límite de 60 peticiones por hora.
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
   | Shell y compositor | `quickshell`, `hyprland`, `hypridle` |
   | Autenticación de administrador | `polkit`; ver [polkit](polkit.md) |
   | Capturas de pantalla | `grim`, `wl-clipboard` |
   | Fondo de pantalla | Integrado en Quickshell; no requiere otro paquete. |
   | Red, audio y batería | `networkmanager`, `wireplumber`, `upower` |
   | Bluetooth | `bluez`, `bluez-utils`, `blueberry` |
   | Brillo de la pantalla y de monitores externos | `brightnessctl`, `ddcutil` |
   | Sonidos del sistema | `ffmpeg`, `sound-theme-freedesktop` |
   | Enlaces, dictado y scripts | `xdg-utils`, `jq`, `python`, `wl-clipboard`, `pipewire` |
   | Acceso al keyring de Google Calendar | `libsecret`; requiere además un proveedor Secret Service configurado y desbloqueado, véase [Google Calendar](google-calendar.md) |
   | Fuentes | `inter-font`, `ttf-nerd-fonts-symbols` |

   Las dependencias con comando se buscan en `PATH`; las fuentes, el tema de sonidos y `bluez` se comprueban con `pacman -Q`.
3. Crea `~/.config/senda/config` si no existe.
4. Descarga, verifica e instala los archivos de Quickshell de la última release.
5. Ofrece instalar el motor de dictado si falta. Los modelos se instalan por separado con `senda stt models install <id>`.
6. Genera `~/.config/hypr/senda/` (con `init.lua`, un módulo por área, `hypridle.conf` y un `.gitignore` que lo ignora todo) a partir de los ajustes de Senda. Conserva archivos sin cabecera propia y avisa de conflictos. Importa el atajo antiguo de dictado y migra referencias inequívocas de módulos anteriores cuando es seguro. Consulta [Bloqueo de pantalla](lock-screen.md).
7. Detiene cualquier instancia de Quickshell lanzada a mano y crea la unidad de usuario `~/.config/systemd/user/senda.service`, la habilita y la arranca.

7. Comprueba si Senda ya está vinculado a Hyprland preguntando a la sesión con `hyprctl` por la función `senda_module_version`, que solo define el módulo de Senda. Da igual dónde esté el módulo o cómo esté organizada la configuración: si la función existe, Senda ya está vinculado y regenera el módulo en el archivo desde el que se cargó. Si no existe, añade `require("modules.senda")` al final de `~/.config/hypr/hyprland.lua` (salvo que ya esté), recarga Hyprland y vuelve a comprobarlo. Fuera de una sesión de Hyprland la comprobación es la línea `require` de `hyprland.lua`. Después puedes mover esa línea donde prefieras.
8. Configura hypridle una sola vez:
   - Si no tienes `~/.config/hypr/hypridle.conf` ni un hypridle en ejecución, usa la configuración de Senda: el módulo inicia `hypridle -c ~/.config/hypr/senda/hypridle.conf` al arrancar Hyprland y, en sesión, se inicia en el momento.
   - Si ya tienes configuración o un hypridle en ejecución, pregunta si quieres conservar la tuya o usar la de Senda (por defecto, la tuya). Si eliges la de Senda, detiene tu hypridle e inicia el de Senda; quita después su arranque de tu configuración para no ejecutar dos instancias al iniciar sesión. Tu archivo no se modifica.
   - La elección se guarda en `SENDA_IDLE_MODE` y no se vuelve a preguntar. Para cambiarla: `senda hyprland set --idle-mode senda` o `--idle-mode user`. Con `user`, el tiempo de inactividad de Senda no se aplica.

Si tu configuración lanza `senda shell run`, quita esa línea.

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

1. Obtiene la última release del canal desde su `latest.json`, sin usar la API de GitHub.
2. Si la release es distinta de la versión del binario, descarga y verifica por SHA-256 el nuevo binario.
3. Descarga y verifica por SHA-256 `senda-quickshell-<tag>.tar.gz`.
4. Reemplaza en `$XDG_DATA_HOME/senda` (por defecto `~/.local/share/senda`) las entradas `quickshell/`, `scripts/` y `version`.
5. Si cambió la versión, reemplaza el binario en su sitio.
6. Detiene el puente de Discord y reinicia `senda.service`, aunque solo se hayan sincronizado los archivos. Si la unidad no está instalada, detiene Quickshell y lo arranca con `senda shell run`.

Si la versión instalada ya coincide con la última release, no hace nada. Si el binario ya está en la última versión pero el archivo `version` del directorio de datos no coincide (por ejemplo, tras la primera instalación), sincroniza solo los archivos de Quickshell.

### Comprobar sin actualizar

`senda update --check` imprime un JSON con `current`, `latest`, `available` y `changes`. Cuando hay una versión nueva, `changes` lista los commits `feat`, `fix` y `perf` entre la versión instalada y la nueva, del más antiguo al más reciente, cada uno con `type`, `scope` y `summary`. Se obtiene del mismo `latest.json`, que guarda los commits de las últimas 50 releases del canal; si la versión instalada ya no figura en él, se listan todas las que contiene. Quickshell ejecuta esta comprobación al arrancar y cada 10 minutos.

Cada release estable publica su `latest.json` como un archivo más. El workflow nightly lo sube a una pre-release fija con la etiqueta `nightly`, que se actualiza en cada compilación y no se borra al limpiar las nightlies antiguas. Lo genera `core/scripts/release-manifest.sh`. La página **Actualización** de los ajustes muestra esta lista agrupada en «Nuevo», «Correcciones» y «Rendimiento».

`senda update` se niega a ejecutarse en binarios de desarrollo y cuando `SENDA_HOME` está definido (ver [configuration.md](configuration.md)).

## Desinstalar (`senda uninstall`)

```sh
senda uninstall
```

Pide confirmación (`-y` la omite) y después cancela el dictado, detiene la instancia de hypridle identificada como gestionada por Senda, retira los archivos generados y la referencia marcada que haya añadido Senda, y elimina el servicio, los datos, estado, configuración y binario. Si encuentra archivos no identificados como propios o referencias manuales, avisa y conserva la configuración cuando corresponda. Las referencias añadidas por el usuario deben retirarse manualmente. No detiene instancias independientes de hypridle.

No elimina los paquetes instalados con pacman. Se niega a ejecutarse cuando `SENDA_HOME` está definido, para no borrar un checkout de desarrollo.
