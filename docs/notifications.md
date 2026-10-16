# Notificaciones

QuickShell recibe las notificaciones de escritorio y mantiene una lista de pendientes. El almacenamiento conserva solo las notificaciones no leídas; no hay historial de leídas.

## Comportamiento

- Una notificación nueva aparece en un pop-up y queda disponible en el panel.
- Los pop-ups pueden permanecer visibles a la vez; el más reciente aparece arriba y los anteriores se desplazan hacia abajo. Cada uno muestra la hora de recepción y tiene cinco segundos de vida contados desde su llegada.
- El panel también muestra la hora de recepción en cada notificación.
- El pop-up se oculta tras unos segundos. Ese timeout no elimina la notificación pendiente.
- Deslizar el pop-up o una notificación del panel hacia la derecha o eliminarla desde el panel la descarta por completo.
- El panel muestra todas las notificaciones en una lista plana, de la más reciente a la más antigua.
- El botón de borrado situado en la parte superior del panel descarta de golpe todas las notificaciones pendientes.
- No molestar suprime los pop-ups y conserva las notificaciones en pendientes.
- La lista de pendientes se recupera después de recargar la configuración, reiniciar QuickShell o reiniciar el equipo.
- Pulsar el nombre de la aplicación intenta enfocar una ventana abierta que coincida con su identificador de escritorio o `appId` de Hyprland. Pulsar el resumen ejecuta la acción estándar `default` cuando el manejador de la aplicación sigue disponible; si no, enfoca la aplicación. Si el cuerpo incluye enlaces, solo se abren destinos `http`, `https` y `mailto`.
- Cada tarjeta muestra sus metadatos disponibles, incluidos identificadores, urgencia, tiempos, acciones recibidas, banderas, enlaces y datos de imagen; los valores binarios de los hints se describen sin volcar sus bytes.
- Las etiquetas e identificadores de las acciones emisoras se conservan como metadatos, pero la invocación remota requiere que el emisor siga activo.

El panel y el pop-up leen el mismo registro persistido y delegan sus interacciones en el servicio de notificaciones. El registro conserva los datos necesarios para reconstruir el foco, los enlaces y las acciones descriptivas. La acción remota `default` requiere un manejador vivo del emisor; si ya no está disponible, pulsar el resumen enfoca la aplicación. Los enlaces se abren con la aplicación externa asociada al protocolo.

## CLI

Los comandos operan sobre la instancia de QuickShell activa mediante IPC. No acceden directamente al almacenamiento.

```sh
senda notifications list
senda notifications dismiss <id>
senda notifications clear
```

`list` muestra únicamente los identificadores, sin el contenido privado de las notificaciones. Si Senda/QuickShell no está en ejecución, el comando informa de que debe iniciarse con `senda shell run`.

## Datos locales y privacidad

Las notificaciones pendientes se guardan como JSON en `Quickshell.stateDir/notifications.json`, fuera del checkout del repositorio. El archivo contiene texto recibido de las aplicaciones y es dato privado del usuario. No se deben copiar notificaciones reales a ejemplos, capturas, registros, issues, documentación ni commits. El repositorio público contiene únicamente código y datos sintéticos.

El almacén se actualiza con escrituras atómicas que terminan antes de continuar. El directorio de estado se crea con permisos solo para el usuario. Las entradas descartadas se quitan del archivo. El servicio también conserva el estado de No molestar en ese archivo.

## Activación

QuickShell y SwayNC implementan el servicio D-Bus `org.freedesktop.Notifications`; solo uno debe estar activo para recibir notificaciones. El inicio de SwayNC debe retirarse de la sesión cuando se active esta versión del gestor. La ruta de inicio local observada es `~/.config/hypr/modules/startup.lua`; esa configuración no forma parte de este repositorio.
