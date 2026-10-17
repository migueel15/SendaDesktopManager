# Configuración

Senda guarda los valores del usuario en un único archivo `KEY=VALUE`.

## Ubicación

El archivo es `$XDG_CONFIG_HOME/senda/config`. Si `XDG_CONFIG_HOME` no está definido o no es una ruta absoluta, se usa `~/.config/senda/config`.

Senda no crea este archivo todavía. El código lo lee si existe y, si no existe, usa valores vacíos. Cuando exista, debe tener permisos `0600`, porque puede contener secretos como `DORLAB_API_KEY`.

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

El archivo `.env` ya no se lee.

## Variables de entorno solo para desarrollo

`SENDA_HOME` cambia el directorio de datos a una ruta concreta, normalmente un checkout del repositorio. Solo se lee del entorno para elegir ese directorio: si aparece en el archivo de configuración, no cambia la ruta de datos.

Mientras `SENDA_HOME` esté definido, `senda update` se niega a ejecutarse. Esa comprobación usa la función que también lee el archivo de configuración, así que `SENDA_HOME=` en el archivo la deshabilita aunque no cambie la ruta de datos. Es una inconsistencia entre ambas lecturas.

`senda update` tampoco funciona en binarios de desarrollo (versión `dev`).

Otras variables de entorno que usa Senda:

- `SENDA_BIN_DIR`: directorio donde `install.sh` instala el binario. Por defecto `~/.local/bin`. Solo se lee del entorno, porque el instalador es un script de shell que no lee el archivo de configuración.
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_RUNTIME_DIR`: rutas base de XDG. Si son relativas, se ignoran.
