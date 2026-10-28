# Configuración

Senda guarda los valores del usuario en un único archivo `KEY=VALUE`.

## Ubicación

El archivo es `$XDG_CONFIG_HOME/senda/config`. Si `XDG_CONFIG_HOME` no está definido o no es una ruta absoluta, se usa `~/.config/senda/config`.

Senda lo lee si existe; si no existe, usa valores vacíos. `senda config set` lo crea con permisos `0600`, porque puede contener secretos como `DORLAB_API_KEY`.

## Formato

- Una entrada por línea, con la forma `CLAVE=valor`.
- Las líneas vacías y las que empiezan por `#` se ignoran.
- Se admite el prefijo `export ` antes de la clave.
- El valor puede ir entre comillas simples (se usa tal cual) o dobles (con escapes al estilo de Go).
- En valores sin comillas, un comentario empieza en ` #` (espacio y almohadilla).
- Una línea sin `=` hace que el archivo se considere inválido. Senda registra el error una vez y trata todos los valores del archivo como vacíos.

Ejemplo:

```sh
# Clave de la API de Dorlab (placeholder)
DORLAB_API_KEY=changeme
SENDA_DISCORD_BRIDGE='/ruta/absoluta/a/discord-bridge.py'
```

## Precedencia

Una variable de entorno con el mismo nombre tiene prioridad sobre el archivo. Si la variable no está definida o está vacía, se usa el valor del archivo.

## Claves que se leen hoy desde el archivo

| Clave | Uso |
|---|---|
| `DORLAB_API_KEY` | Se pasa a Quickshell como variable de entorno al ejecutar `senda shell run`. |
| `SENDA_DISCORD_BRIDGE` | Ruta absoluta a `discord-bridge.py`. Tiene prioridad sobre la ubicación automática del script (ver [discord-bridge.md](discord-bridge.md)). |
| `SENDA_GOOGLE_CLIENT_ID` | ID de tu propio cliente OAuth de escritorio. Si está vacío, se usa el cliente incluido en la release. Ver [google-calendar.md](google-calendar.md). |
| `SENDA_GOOGLE_CLIENT_SECRET` | Secreto de ese cliente. Nunca se imprime; `senda config get` solo indica si está definido. |
| `SENDA_GOOGLE_CALENDARS` | IDs de calendarios separados por comas. Vacío significa los calendarios que Google marca como visibles. |
| `SENDA_WEATHER_LOCATION` | Nombre de la localidad elegida, solo para mostrarlo. |
| `SENDA_WEATHER_LAT` y `SENDA_WEATHER_LON` | Coordenadas de la localidad, entre -90 y 90 y entre -180 y 180. |
| `SENDA_STT_MODEL` | ID del modelo de dictado activo. Predeterminado: `nemotron-3.5-streaming-0.6b-int8`. |
| `SENDA_STT_AUDIO_DUCKING` | Atenúa el volumen durante el dictado. `false` lo desactiva; predeterminado: `true`. |
| `SENDA_STT_AUDIO_VOLUME` | Volumen de salida durante el dictado: entero de 0 a 100. Predeterminado: `10`. Se restaura el anterior al terminar. |
| `SENDA_STT_PRELOAD` | Precarga del modelo en la shell: `true` la activa; cualquier otro valor la deja desactivada. Predeterminado: desactivada. |
| `SENDA_STT_LANGUAGE` | Idioma del reconocimiento. Predeterminado `es`; también admite `auto` y códigos de idioma. |
| `SENDA_STT_PASTE_MODE` | Entrega del resultado: `paste` (predeterminado) o `clipboard`. |
| `SENDA_SCREENSHOT_SHORTCUT` | Atajo de captura de pantalla. Predeterminado: `Print`. |
| `SENDA_SCREENSHOT_DIR` | Carpeta para Guardar en el editor; vacía usa Imágenes/Capturas. Ver [capturas](screenshots.md). |
| `SENDA_LOCK_SHORTCUT` | Atajo de bloqueo de Hyprland. Predeterminado: `SUPER + CTRL + l`. |
| `SENDA_IDLE_SECONDS` | Segundos de inactividad antes del bloqueo; `0` lo desactiva. Predeterminado: `600`. |
| `SENDA_LOCK_BLUR` | Activa el desenfoque de la pantalla de bloqueo. Predeterminado: `true`. |
| `SENDA_STT_SHORTCUT` | Atajo de Hyprland para iniciar y detener el dictado. Predeterminado: `ALT + ntilde` (Alt + ñ). |
| `SENDA_STT_TERMINALS` | Clases de ventanas de terminal separadas por comas; determinan dónde se usa Ctrl+Shift+V. |
| `SENDA_THEME` | Nombre del tema activo. Predeterminado: `zenda-ice`. La variable de entorno tiene prioridad; ver [temas](themes.md). |

Si no hay localidad elegida, el clima usa la capital del país de tu zona horaria del sistema (`/etc/localtime`), por ejemplo Madrid para `Europe/Madrid`. Las zonas que no corresponden a un país concreto, como UTC, no tienen valor por defecto. Elegir una localidad en el panel sustituye al valor por defecto.

Estas claves las escribe el panel de configuración (`senda settings`) con `senda config set`. En Ajustes, los interruptores y selectores guardan al cambiar; el deslizador de texto guarda al soltar y los campos editados con Enter o al perder el foco. Las credenciales de Google se confirman juntas desde el segundo campo o con «Guardar credenciales». El resultado aparece en el pie del panel sin desplazar las opciones. También puedes editarlas a mano; el archivo se mantiene con permisos `0600`.

En Ajustes → Widgets se pueden habilitar o deshabilitar los controles de Spotify y Discord de la barra. Ambos están habilitados por defecto. Sus preferencias se guardan como `SENDA_WIDGET_SPOTIFY` y `SENDA_WIDGET_DISCORD`, con valores `true` o `false`; un valor vacío restaura el comportamiento predeterminado. Al deshabilitar Discord se detiene su puente; si hay un dictado en curso, se espera a que termine para permitir la restauración del micrófono. Sin el puente, el dictado no silencia Discord automáticamente. El widget de Spotify utiliza MPRIS y no inicia un proceso propio.

El refresh token de Google no está en este archivo. Se guarda en `$XDG_STATE_HOME/senda/google-calendar.json` (por defecto `~/.local/state/senda/google-calendar.json`), también con permisos `0600`. Se borra con `senda calendar logout`.

El archivo `.env` ya no se lee.

## Bloqueo de teclado desde la barra

El widget de teclado comparte su estado entre todas las barras. Al pulsarlo,
ejecuta `hyprctl eval Senda.keyboard.toggle()` y actualiza los iconos de todos los
monitores solo si el comando termina con código 0. Mientras está en ejecución,
las nuevas pulsaciones se ignoran en todas las barras.

El estado del icono empieza como activado al iniciar o recargar Quickshell; no
consulta el estado real de Hyprland ni detecta cambios hechos fuera de la barra.

## Lanzador de aplicaciones

El icono de Senda de la esquina superior izquierda despliega el lanzador desde
la barra en ese monitor. Al abrirlo, el campo de búsqueda recibe el foco. Escribe para filtrar aplicaciones; usa las
flechas y Enter para abrir una, o selecciónala con el ratón. Escape o un clic
fuera lo cierra. Las aplicaciones ocultas en su entrada de escritorio no se muestran.
Con la búsqueda vacía aparecen primero las aplicaciones abiertas desde el lanzador,
de la más reciente a la más antigua; las demás se ordenan por nombre. Al escribir,
se priorizan las coincidencias del nombre: exactas, al principio, en cualquier
parte y, después, las letras en el mismo orden aunque no sean consecutivas (por
ejemplo, `t3c` encuentra «T3 Code»). También se buscan el nombre genérico, la
descripción, el identificador y las palabras clave. Entre coincidencias del mismo
tipo, las aplicaciones recientes van primero y el resto se ordena por nombre.
Se recuerdan hasta 100 aplicaciones en `$XDG_STATE_HOME/senda/launcher-recent.json`
(por defecto `~/.local/state/senda/launcher-recent.json`). Solo se registran las
aperturas realizadas desde este lanzador.

También puedes abrirlo o cerrarlo desde una terminal o un atajo del compositor:

```sh
senda launcher toggle
```

El comando usa el monitor enfocado por Hyprland. Para elegir uno explícitamente,
añade `--screen <nombre>`; el icono de la barra usa esta opción para abrirlo en
su propio monitor. La shell de Senda debe estar en ejecución.

## Variables de entorno solo para desarrollo

`SENDA_HOME` cambia el directorio de datos a una ruta concreta, normalmente un checkout del repositorio. Solo se lee del entorno para elegir ese directorio: si aparece en el archivo de configuración, no cambia la ruta de datos.

Mientras `SENDA_HOME` esté definido, `senda update` se niega a ejecutarse. Esa comprobación usa la función que también lee el archivo de configuración, así que `SENDA_HOME=` en el archivo la deshabilita aunque no cambie la ruta de datos. Es una inconsistencia entre ambas lecturas.

`senda update` tampoco funciona en binarios de desarrollo (versión `dev`).

Otras variables de entorno que usa Senda:

- `SENDA_BIN_DIR`: directorio donde `install.sh` instala el binario. Por defecto `~/.local/bin`. Solo se lee del entorno, porque el instalador es un script de shell que no lee el archivo de configuración.
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_RUNTIME_DIR`: rutas base de XDG. Si son relativas, se ignoran.

## Integración de Hyprland

Los ajustes de bloqueo, dictado y capturas se leen del archivo de Senda y se cambian juntos con `senda hyprland set`; usa `senda hyprland show --json` para consultar rutas, estado y avisos. Los modificadores y teclas se validan antes de escribir. Un ejecutable temporal generado por `go run` no se acepta: utiliza un binario persistente, tanto en desarrollo como en una release. Consulta [Bloqueo de pantalla](lock-screen.md).
