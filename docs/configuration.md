# Configuración

Zenda guarda las preferencias del usuario en un único archivo `KEY=VALUE`. El archivo no contiene secretos y se puede compartir entre equipos ([ADR 0010](adr/0011-secretos-fuera-de-la-configuracion.md)).

## Ubicación

El archivo es `$XDG_CONFIG_HOME/zenda/config`. Si `XDG_CONFIG_HOME` no está definido o no es una ruta absoluta, se usa `~/.config/zenda/config`.

Zenda lo lee si existe; si no existe, usa valores vacíos. `zenda config set` lo crea con permisos `0600`.

## Formato

- Una entrada por línea, con la forma `CLAVE=valor`.
- Las líneas vacías y las que empiezan por `#` se ignoran.
- Se admite el prefijo `export ` antes de la clave.
- El valor puede ir entre comillas simples (se usa tal cual) o dobles (con escapes al estilo de Go).
- En valores sin comillas, un comentario empieza en ` #` (espacio y almohadilla).
- Una línea sin `=` hace que el archivo se considere inválido. Zenda registra el error una vez y trata todos los valores del archivo como vacíos.

Ejemplo:

```sh
ZENDA_THEME=zenda-ice
ZENDA_DISCORD_BRIDGE='/ruta/absoluta/a/discord-bridge.py'
```

## Precedencia

Una variable de entorno con el mismo nombre tiene prioridad sobre el archivo. Si la variable no está definida o está vacía, se usa el valor del archivo.

## Claves que se leen hoy desde el archivo

| Clave | Uso |
|---|---|
| `ZENDA_DISCORD_BRIDGE` | Ruta absoluta a `discord-bridge.py`. Tiene prioridad sobre la ubicación automática del script (ver [discord-bridge.md](discord-bridge.md)). |
| `ZENDA_GOOGLE_CLIENT_ID` | ID de tu propio cliente OAuth de escritorio. Si está vacío, se usa el cliente incluido en la release. Ver [google-calendar.md](google-calendar.md). |
| `ZENDA_GOOGLE_CALENDARS` | IDs de calendarios separados por comas. Vacío significa los calendarios que Google marca como visibles. |
| `ZENDA_WEATHER_LOCATION` | Nombre de la localidad elegida, solo para mostrarlo. |
| `ZENDA_WEATHER_LAT` y `ZENDA_WEATHER_LON` | Coordenadas de la localidad, entre -90 y 90 y entre -180 y 180. |
| `ZENDA_STT_MODEL` | ID del modelo de dictado activo. Predeterminado: `nemotron-3.5-streaming-0.6b-int8`. |
| `ZENDA_STT_AUDIO_DUCKING` | Atenúa el volumen durante el dictado. `false` lo desactiva; predeterminado: `true`. |
| `ZENDA_STT_AUDIO_VOLUME` | Volumen de salida durante el dictado: entero de 0 a 100. Predeterminado: `10`. Solo se baja si la salida no está silenciada y su volumen es mayor; se restaura el anterior al terminar. |
| `ZENDA_STT_LIVE_TEXT` | Muestra en el dock el texto que se va reconociendo. `false` lo oculta y deja solo las barras; predeterminado: `true`. |
| `ZENDA_STT_PRELOAD` | Precarga del modelo en la shell: `true` la activa; cualquier otro valor la deja desactivada. Predeterminado: desactivada. |
| `ZENDA_STT_LANGUAGE` | Idioma del reconocimiento. Predeterminado `es`; también admite `auto` y códigos de idioma. |
| `ZENDA_STT_PASTE_MODE` | Entrega del resultado: `paste` (predeterminado) o `clipboard`. |
| `ZENDA_SCREENSHOT_SHORTCUT` | Atajo de captura de pantalla. Predeterminado: `Print`. |
| `ZENDA_SCREENSHOT_DIR` | Carpeta para Guardar en el editor; vacía usa Imágenes/Capturas. Ver [capturas](screenshots.md). |
| `ZENDA_LOCK_SHORTCUT` | Atajo de bloqueo de Hyprland. Predeterminado: `SUPER + CTRL + l`. |
| `ZENDA_LAUNCHER_SHORTCUT` | Atajo que abre el launcher. Predeterminado: `SUPER + d`. |
| `ZENDA_EMOJI_SHORTCUT` | Atajo que abre el launcher en modo emoji. Predeterminado: `SUPER + period`. |
| `ZENDA_IDLE_SECONDS` | Segundos de inactividad antes del bloqueo; `0` lo desactiva. Predeterminado: `600`. |
| `ZENDA_BATTERY_WARNING` | Porcentaje de batería que dispara el aviso: entero de 5 a 95. Predeterminado: `20`. Ver [energía](power.md). |
| `ZENDA_LOCK_BLUR` | Activa el desenfoque de la pantalla de bloqueo. Predeterminado: `true`. |
| `ZENDA_DISPLAYS` y `ZENDA_DISPLAYS_PREVIOUS` | Reglas de pantalla en JSON y las anteriores, para deshacer. Las escribe `zenda display`; ver [pantallas](displays.md). |
| `ZENDA_STARTUP_APPS` | Lo que se abre al iniciar Hyprland, en JSON. Lo escribe `zenda startup`; ver [aplicaciones de inicio](startup-apps.md). |
| `ZENDA_STT_SHORTCUT` | Atajo de Hyprland para iniciar y detener el dictado. Predeterminado: `ALT + ntilde` (Alt + ñ). |
| `ZENDA_STT_TERMINALS` | Clases de ventanas de terminal separadas por comas; determinan dónde se usa Ctrl+Shift+V. |
| `ZENDA_THEME` | Nombre del tema activo. Predeterminado: `zenda-ice`. La variable de entorno tiene prioridad; ver [temas](themes.md). |

Si no hay localidad elegida, el clima usa la capital del país de tu zona horaria del sistema (`/etc/localtime`), por ejemplo Madrid para `Europe/Madrid`. Las zonas que no corresponden a un país concreto, como UTC, no tienen valor por defecto. Elegir una localidad en el panel sustituye al valor por defecto.

Estas claves las escribe la ventana de ajustes con `zenda config set`. La ventana se abre con `zenda settings`, desde el dashboard o desde el aviso de actualización, y aparece flotante y centrada en el monitor con el foco: `zenda settings` registra antes la regla de ventana en Hyprland, y el módulo de Zenda también la incluye. En Apariencia se elige también el tema. En Ajustes, los interruptores y selectores guardan al cambiar; el deslizador de texto guarda al soltar y los campos editados con Enter o al perder el foco. Las credenciales de Google se confirman juntas desde el segundo campo o con «Guardar credenciales». El resultado aparece en el pie de la ventana sin desplazar las opciones. También puedes editarlas a mano; el archivo se mantiene con permisos `0600`.

En Ajustes → Widgets están el calendario, el tiempo y los controles de la barra; ahí se pueden habilitar o deshabilitar los controles de Spotify y Discord de la barra. Ambos están habilitados por defecto. Sus preferencias se guardan como `ZENDA_WIDGET_SPOTIFY` y `ZENDA_WIDGET_DISCORD`, con valores `true` o `false`; un valor vacío restaura el comportamiento predeterminado. Al deshabilitar Discord se detiene su puente; si hay un dictado en curso, se espera a que termine para permitir la restauración del micrófono. Sin el puente, el dictado no silencia Discord automáticamente. El widget de Spotify utiliza MPRIS y no inicia un proceso propio.

## Secretos

Estos valores no están en el archivo de configuración. Una variable de entorno con el mismo nombre sigue teniendo prioridad.

| Secreto | Uso | Dónde |
|---|---|---|
| `DORLAB_API_KEY` | Se pasa a Quickshell como variable de entorno al ejecutar `zenda shell run`. | Keyring; sin keyring, archivo de respaldo |
| `ZENDA_GOOGLE_CLIENT_SECRET` | Secreto de tu cliente OAuth. Nunca se imprime; `zenda config get` solo indica si está definido. | Keyring; sin keyring, archivo de respaldo |
| Refresh token de Google | Conexión con Calendar. Se borra con `zenda calendar logout`. | Solo keyring ([ADR 0005](adr/0005-tokens-en-secret-service.md)) |

El keyring es Secret Service, mediante `secret-tool`. El archivo de respaldo, sin cifrar y con permisos `0600`, es `$XDG_STATE_HOME/zenda/secrets` (por defecto `~/.local/state/zenda/secrets`); queda fuera de la carpeta de configuración, así que no se comparte con ella. Si el keyring vuelve a estar disponible, los valores pasan a él y salen del archivo.

Para guardar un secreto, envíalo por la entrada estándar. Una entrada vacía lo elimina:

```sh
read -rs key; printf %s "$key" | zenda config secret DORLAB_API_KEY
```

Los secretos que queden en el archivo de configuración se mueven al leerlos: se eliminan de él solo después de confirmar el guardado. En un equipo nuevo no hay secretos: Calendar pide reconectar y, con un cliente OAuth propio, pide de nuevo su secreto en Ajustes.

El archivo `.env` ya no se lee.

## Bluetooth

El desplegable del centro de control busca dispositivos al abrirse y ofrece el emparejamiento con confirmación de PIN dentro de Zenda. El flujo y la validación en sesión están descritos en [Bluetooth](bluetooth.md).

## Bloqueo de teclado desde la barra

El widget de teclado comparte su estado entre todas las barras. Al pulsarlo,
ejecuta `hyprctl eval Zenda.keyboard.toggle()` y actualiza los iconos de todos los
monitores solo si el comando termina con código 0. Mientras está en ejecución,
las nuevas pulsaciones se ignoran en todas las barras.

El estado del icono empieza como activado al iniciar o recargar Quickshell; no
consulta el estado real de Hyprland ni detecta cambios hechos fuera de la barra.

## Lanzador de aplicaciones

El icono de Zenda de la esquina superior izquierda despliega el lanzador desde
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
Se recuerdan hasta 100 aplicaciones en `$XDG_STATE_HOME/zenda/launcher-recent.json`
(por defecto `~/.local/state/zenda/launcher-recent.json`). Solo se registran las
aperturas realizadas desde este lanzador.

Además de aplicaciones, el lanzador sirve para tareas rápidas:

- **Acciones de Zenda.** Al escribir aparecen, mezcladas con las aplicaciones por
  coincidencia, «Ajustes» y sus secciones («Ajustes: Apariencia», «Ajustes:
  Widgets»…), que abren la ventana de ajustes en esa sección; «Selector de temas»;
  «Selector de fondos»;
  «Emojis»; «Captura de pantalla» y «Bloquear pantalla». Todas se declaran en un
  único registro, `quickshell/services/LauncherActions.qml`, y las secciones de
  ajustes salen de la lista de `ZendaSettings`, de modo que cada sección nueva
  aparece sola.
- **Calculadora.** Una expresión con `+ - * / % ^` y paréntesis (por ejemplo,
  `2*(3+4)` o `3,5/2`) muestra el resultado como primera fila; empieza por `=` para
  calcular un número suelto. Enter copia el resultado con `wl-copy`.
- **Comandos.** `>` seguido de un comando lo ejecuta con `sh -c` en segundo plano,
  sin terminal.
- **Emojis.** `:` seguido de palabras en español o inglés (`:corazon`, `:fire`)
  busca emojis; Enter copia el elegido al portapapeles y lo pega en la ventana
  enfocada (con `Ctrl+Shift+V` en las terminales configuradas para el dictado).

También puedes abrirlo o cerrarlo desde una terminal o un atajo del compositor:

```sh
zenda launcher toggle
```

El comando usa el monitor enfocado por Hyprland. Para elegir uno explícitamente,
añade `--screen <nombre>`; el icono de la barra usa esta opción para abrirlo en
su propio monitor. `--query <texto>` abre el launcher con esa búsqueda ya
escrita; por ejemplo, `zenda launcher toggle --query :` lo abre en modo emoji.

Zenda genera en `binds.lua` los atajos del launcher (`SUPER + d`) y del modo
emoji (`SUPER + period`). Se cambian en Ajustes → Atajos o con
`zenda hyprland set --launcher-shortcut` y `--emoji-shortcut`. Si al actualizar
la tecla por defecto ya la usa otro atajo de Zenda, ese atajo queda sin asignar
hasta que elijas uno. Si tu configuración de Hyprland ya tiene un atajo propio
con la misma tecla, Ajustes lo muestra como conflicto: quita el tuyo.
La shell de Zenda debe estar en ejecución.

## Variables de entorno solo para desarrollo

`ZENDA_HOME` cambia el directorio de datos a una ruta concreta, normalmente un checkout del repositorio. Solo se lee del entorno para elegir ese directorio: si aparece en el archivo de configuración, no cambia la ruta de datos.

Mientras `ZENDA_HOME` esté definido, `zenda update` se niega a ejecutarse. Esa comprobación usa la función que también lee el archivo de configuración, así que `ZENDA_HOME=` en el archivo la deshabilita aunque no cambie la ruta de datos. Es una inconsistencia entre ambas lecturas.

`zenda update` tampoco funciona en binarios de desarrollo (versión `dev`).

Otras variables de entorno que usa Zenda:

- `ZENDA_BIN_DIR`: directorio donde `install.sh` instala el binario. Por defecto `~/.local/bin`. Solo se lee del entorno, porque el instalador es un script de shell que no lee el archivo de configuración.
- `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_RUNTIME_DIR`: rutas base de XDG. Si son relativas, se ignoran.

## Integración de Hyprland

Los ajustes de bloqueo, dictado y capturas se leen del archivo de Zenda y se cambian juntos con `zenda hyprland set`; usa `zenda hyprland show --json` para consultar rutas, estado y avisos. Los modificadores y teclas se validan antes de escribir. Un ejecutable temporal generado por `go run` no se acepta: utiliza un binario persistente, tanto en desarrollo como en una release. Consulta [Bloqueo de pantalla](lock-screen.md).

## Portapapeles

`ZENDA_CLIPBOARD_ENABLED` (`true` o `false`, activo por defecto) y `ZENDA_CLIPBOARD_MAX` (de 1 a 1000, 100 por defecto) controlan el [historial del portapapeles](clipboard.md).
