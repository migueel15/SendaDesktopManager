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
| `SENDA_STT_LANGUAGE` | Idioma del reconocimiento. Predeterminado `es`; también admite `auto` y códigos de idioma. |
| `SENDA_STT_PASTE_MODE` | Entrega del resultado: `paste` (predeterminado) o `clipboard`. |
| `SENDA_STT_SHORTCUT` | Atajo de Hyprland para iniciar y detener el dictado. Predeterminado: `ALT + ntilde` (Alt + ñ). |
| `SENDA_STT_TERMINALS` | Clases de ventanas de terminal separadas por comas; determinan dónde se usa Ctrl+Shift+V. |

Si no hay localidad elegida, el clima usa la capital del país de tu zona horaria del sistema (`/etc/localtime`), por ejemplo Madrid para `Europe/Madrid`. Las zonas que no corresponden a un país concreto, como UTC, no tienen valor por defecto. Elegir una localidad en el panel sustituye al valor por defecto.

Estas claves las escribe el panel de configuración (`senda settings`) con `senda config set`. También puedes editarlas a mano; el archivo se mantiene con permisos `0600`.

El refresh token de Google no está en este archivo. Se guarda en `$XDG_STATE_HOME/senda/google-calendar.json` (por defecto `~/.local/state/senda/google-calendar.json`), también con permisos `0600`. Se borra con `senda calendar logout`.

El archivo `.env` ya no se lee.

## Variables de entorno solo para desarrollo

`SENDA_HOME` cambia el directorio de datos a una ruta concreta, normalmente un checkout del repositorio. Solo se lee del entorno para elegir ese directorio: si aparece en el archivo de configuración, no cambia la ruta de datos.

Mientras `SENDA_HOME` esté definido, `senda update` se niega a ejecutarse. Esa comprobación usa la función que también lee el archivo de configuración, así que `SENDA_HOME=` en el archivo la deshabilita aunque no cambie la ruta de datos. Es una inconsistencia entre ambas lecturas.

`senda update` tampoco funciona en binarios de desarrollo (versión `dev`).

Otras variables de entorno que usa Senda:

- `SENDA_BIN_DIR`: directorio donde `install.sh` instala el binario. Por defecto `~/.local/bin`. Solo se lee del entorno, porque el instalador es un script de shell que no lee el archivo de configuración.
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_RUNTIME_DIR`: rutas base de XDG. Si son relativas, se ignoran.
