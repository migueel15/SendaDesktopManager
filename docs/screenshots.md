# Capturas de pantalla

Pulsa `Print` (Impr Pant) o ejecuta `senda screenshot` con la shell de Senda en
marcha. Se captura cada salida con `grim` antes de mostrar los overlays; todos
los monitores muestran entonces su imagen congelada. Arrastra para seleccionar
una zona en el monitor donde empezaste. La selección no cruza a otros monitores;
el resto de la imagen queda oscurecido. `Esc` o el botón derecho cancelan y
eliminan las imágenes temporales sin copiar ni guardar la captura.

Al soltar, se cierran los overlays, se recorta la selección en PNG y se copia al
portapapeles con `wl-copy --type image/png`. Aparece «Captura de pantalla tomada»
con una vista de la imagen. Las coordenadas lógicas se convierten usando la
proporción entre el PNG y la superficie del monitor, incluidas escalas fraccionarias.
Las capturas de las salidas se toman consecutivamente antes de abrir los overlays.

## Editor

Pulsa la notificación, en el pop-up o en el panel, para abrir el editor de
Quickshell. Arrastra para definir otro rectángulo o ajusta sus ocho asas.

- **Guardar:** guarda el recorte actual en PNG y lo copia al portapapeles. El
  editor muestra la ruta del archivo creado.
- **Copiar:** copia el recorte actual sin crear un archivo en la carpeta de destino.
- **Cerrar:** cierra el editor.

Los botones quedan desactivados mientras se procesa una operación. La selección
se aplica sobre la captura original; puedes realizar varios recortes desde el
mismo editor. No se inicia otra captura mientras el editor o una operación estén
abiertos. No molestar conserva la notificación en el panel y suprime el pop-up.

## Ajustes y ubicación

En **Ajustes → Sistema** puedes grabar el atajo de captura con el mismo control
que bloqueo y dictado, y elegir la carpeta de destino. Se comprueban los
conflictos con los otros atajos de Senda y con los binds activos de Hyprland.

`SENDA_SCREENSHOT_SHORTCUT` usa `Print` por defecto. Para regenerar el módulo
`modules/senda.lua` desde la CLI:

```sh
senda hyprland set --screenshot-shortcut 'Print'
senda hyprland show --json
```

`SENDA_SCREENSHOT_DIR` admite una ruta absoluta o que empiece por `~/`. Vacío usa
`$(xdg-user-dir PICTURES)/Capturas`, con `~/Pictures/Capturas` como respaldo.
`senda screenshot dir` muestra la carpeta en uso y `--default` la predeterminada. En Ajustes, el campo vacío la muestra como texto de ayuda. El directorio se crea al guardar. El nombre es `captura-AAAA-MM-DD-HHMMSS.png`;
si ya existe, se busca el siguiente segundo libre para conservar ambos archivos.
Las variables de entorno tienen prioridad sobre la carpeta del archivo de configuración.

## Archivos privados e integración

Las imágenes completas viven en sesiones privadas con permisos `0700` bajo
`$XDG_RUNTIME_DIR/senda/screenshots/` y se eliminan al cancelar o terminar. Es
necesario que `XDG_RUNTIME_DIR` sea una ruta absoluta. Los PNG tienen permisos
`0600`.

La captura seleccionada se conserva como dato interno en
`$XDG_CACHE_HOME/senda/screenshots/` (por defecto `~/.cache/senda/screenshots/`),
con un máximo de cinco imágenes. Esta caché permite abrir las notificaciones
pendientes después de recargar la shell; no es un guardado en la carpeta de
capturas. Si una imagen ya no existe, pulsar su notificación solo la descarta.
Las operaciones del editor no añaden imágenes a esa caché ni expulsan la imagen
que está abierta. Los archivos guardados por el usuario no se podan.

`ScreenshotService` usa IPC de la shell activa. La notificación se crea dentro
del propio servidor `Notifications.qml`, sin emitir una notificación por D-Bus.
El núcleo Go implementa el recorte PNG con la biblioteca estándar y los
subcomandos internos `freeze`, `crop`, `info` y `cleanup`. El editor y la selección
inicial comparten el mismo recortador.

Las dependencias son `grim`, `wl-copy` (paquete `wl-clipboard`) y Quickshell.
No se necesitan herramientas externas de edición de imágenes.
