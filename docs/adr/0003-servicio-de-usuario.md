# ADR 0003: Senda como servicio de usuario de systemd

## Estado

Aceptada. Sustituye la parte del ADR 0001 que pedía al usuario añadir el arranque a Hyprland.

## Contexto

Tras `senda setup`, el usuario tenía que añadir `senda shell run` a la configuración de Hyprland, y `senda update` reiniciaba Quickshell como proceso suelto. No había reinicio ante fallos ni registros centralizados. Además, Senda va a ejecutar más procesos en segundo plano (un socket) junto a la shell.

## Decisión

1. `senda setup` instala, habilita y arranca la unidad de usuario `senda.service` en `$XDG_CONFIG_HOME/systemd/user/`. Se llama `senda`, no `senda-shell`, porque gestionará todo lo que Senda ejecuta en segundo plano. Hoy ejecuta `senda shell run`.
2. La unidad usa `WantedBy=default.target` y un `ExecStartPre` que espera al entorno de Hyprland, con `Restart=on-failure` y sin límite de arranques. Se descarta `graphical-session.target` porque Hyprland sin UWSM no lo activa.
3. `senda update` reinicia la unidad. Si se ejecuta desde dentro de ella (lanzada por Quickshell), usa `--no-block`, porque el reinicio termina también ese proceso.
4. `senda shell run|kill|restart` delegan en systemd cuando la unidad existe; `shell run` dentro de la unidad (detectado por su cgroup) ejecuta Quickshell en primer plano.
5. `senda uninstall` elimina la unidad, el binario y los directorios de datos, configuración y estado. No toca los paquetes de pacman.
6. Se mantiene que ni el instalador ni `setup` editan la configuración de Hyprland ni requieren root.

## Consecuencias

- El usuario no edita archivos tras `senda setup`.
- Si la configuración de Hyprland sigue lanzando `senda shell run`, esa línea pide a systemd que arranque la unidad, por lo que no se duplica la instancia.
- Al cerrar sesión, la unidad queda reintentando cada 2 segundos hasta que vuelve a haber una sesión de Hyprland.
- Si se mueve el binario, hay que volver a ejecutar `senda setup` para reescribir la ruta de la unidad.

## Enmienda: arranque con `Type=dbus`

### Contexto

Al iniciar sesión, Hyprland lanza aplicaciones como Discord a la vez que systemd arranca `senda.service`. Quickshell es quien posee `org.kde.StatusNotifierWatcher`, el vigilante de la bandeja. Las aplicaciones Electron registran su icono una sola vez al arrancar; si el vigilante aún no existe, no reintentan y el icono no aparece nunca en la bandeja ni en los anclados.

### Decisión

La unidad pasa de `Type=simple` a `Type=dbus` con `BusName=org.kde.StatusNotifierWatcher` y `TimeoutStartSec=30`. `systemctl --user start senda.service` vuelve solo cuando el vigilante existe, de modo que la configuración de Hyprland puede lanzar las aplicaciones con bandeja después de ese comando (véase `docs/system-tray.md`). Treinta segundos cubren la carga de Quickshell con margen y acotan la espera si nunca toma el nombre. El resto de directivas (`ExecStartPre`, `Restart=on-failure`, `RestartSec=2`, `StartLimitIntervalSec=0`, `WantedBy=default.target`) no cambia.

### Consecuencias

- `senda shell run` fuera de la unidad y `senda setup` pasan a bloquearse hasta que la bandeja está lista o vence el plazo.
- `senda update` desde dentro de la unidad sigue usando `--no-block`.
- Hay que volver a ejecutar `senda setup` para reescribir la unidad instalada.
