# Notificaciones

QuickShell recibe las notificaciones de escritorio y mantiene una lista de pendientes. El almacenamiento conserva solo las notificaciones no leídas; no hay historial de leídas.

## Comportamiento

- Una notificación nueva aparece en un pop-up y queda disponible en el panel.
- El pop-up se oculta tras unos segundos. Ese timeout no elimina la notificación pendiente.
- Deslizar el pop-up a cualquiera de los lados, eliminar una notificación desde el panel o borrar todas la descarta por completo.
- No molestar suprime los pop-ups y conserva las notificaciones en pendientes.
- La lista de pendientes se recupera después de recargar la configuración, reiniciar QuickShell o reiniciar el equipo.
- Las acciones de la aplicación emisora no se conservan al reiniciar QuickShell; este primer corte restaura el contenido de la notificación.

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
