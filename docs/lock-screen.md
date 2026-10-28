# Bloqueo de pantalla

Senda proporciona `senda lock` y el target IPC `lock`: `lock()` solicita el bloqueo e `isLocked()` indica si está solicitado o activo. El servicio reactiva primero los teclados gestionados por Senda; si falla, registra el error y solicita igualmente el bloqueo. PAM utiliza la configuración `login` y la contraseña solo se entrega a PAM.

El campo de contraseña recupera el foco con cualquier pulsación: si lo perdió (por ejemplo, al cerrar y abrir la tapa o tras una contraseña incorrecta), la tecla pulsada se escribe en él, Retroceso borra y Enter confirma. La pantalla que recibe el teclado muestra el campo aunque Hyprland indique otro monitor enfocado.

La pantalla deja ver el escritorio oscurecido a través de la superficie translúcida. En Hyprland, `misc.session_lock_xray` y `misc.session_lock_blur` deben estar activos y `decoration.blur` debe estar habilitado para que el compositor desenfoque lo que hay detrás; su intensidad depende de `decoration.blur.size` y `passes`. Comprueba visualmente que el texto no sea legible en cada monitor antes de confiar en el efecto. Hyprland debe tener `misc.allow_session_lock_restore = true` para permitir recuperar una sesión bloqueada si Quickshell termina. Senda guarda un marcador volátil mientras está bloqueada y vuelve a solicitar el bloqueo al arrancar. Si Quickshell muere con la sesión bloqueada, pasa a un TTY y vuelve a lanzar la instancia de Senda con su entorno gráfico y de Hyprland. `loginctl unlock-session` por sí solo no garantiza desbloquear el protocolo Wayland; no sustituye la autenticación PAM.

`senda setup` genera `~/.config/hypr/modules/senda.lua` y el archivo privado `~/.config/senda/hypridle.conf`. Si Hyprland no ha cargado el módulo (lo detecta con la función `senda_module_version`), añade `require("modules.senda")` al final de `hyprland.lua`; consulta [Instalación](installation.md). El módulo contiene los atajos de bloqueo, dictado y capturas y habilita la recuperación del bloqueo. Senda no sobrescribe archivos sin cabecera propia.

```sh
senda hyprland show --json
senda hyprland set --lock-shortcut 'SUPER + CTRL + l' --dictation-shortcut 'ALT + ñ' --idle-seconds 600 --blur true --json
```

El tiempo `0` desactiva el bloqueo por inactividad. `set` valida los ajustes, los guarda y reemplaza cada archivo generado de forma atómica; en sesión recarga Hyprland. El modo de hypridle (`SENDA_IDLE_MODE`) decide quién gestiona la inactividad. Con `senda`, el módulo arranca `hypridle -c ~/.config/senda/hypridle.conf` al iniciar Hyprland y `set` lo inicia o reinicia en sesión; solo reinicia una instancia iniciada y registrada por Senda. Al cambiar a `senda` con `--idle-mode senda`, detiene el hypridle del usuario. Con `user`, Senda no inicia ni detiene hypridle y el tiempo de inactividad de Senda no se aplica. Sin elección registrada, `set` usa `user`.

El archivo usa `inhibit_sleep = 3`, `lock_cmd`, `before_sleep_cmd` y `after_sleep_cmd`; espera la confirmación del bloqueo antes de suspender. Requiere hypridle y Senda activos. El desenfoque también requiere `decoration.blur.enabled` y valores positivos de `size` y `passes` en Hyprland.

## Cambiar los atajos

En Ajustes → Sistema, cada atajo (bloqueo, dictado y capturas) se cambia haciendo clic en el campo (o con Enter o Espacio si tiene el foco) y pulsando después la combinación. Mientras graba, Senda pone Hyprland en el submap `senda_capture`, que solo tiene Escape, para que los atajos existentes no se ejecuten; el atajo de dictado es universal y sí se ejecuta. La grabación termina con la combinación, con Escape, con «Cancelar», al perder el foco o a los 10 segundos, y siempre vuelve al mapa normal. Los modificadores admitidos son Super, Ctrl, Alt y Shift; las teclas, letras, números, F1–F24, Ñ, Impr Pant y teclas de navegación.

Antes de guardar, Senda comprueba con `senda hyprland check --for lock|dictation|screenshot --shortcut <combo>` si otro atajo de Hyprland usa la combinación. Si es otro atajo de Senda, no se guarda; si es uno tuyo, pide confirmación. «Restablecer» vuelve al atajo por defecto. `senda hyprland capture start|stop` entra y sale del submap.

## Atajo de capturas

El módulo `modules/senda.lua` también genera `Print` → `senda screenshot`.
`SENDA_SCREENSHOT_SHORTCUT` se configura con
`senda hyprland set --screenshot-shortcut 'Print'` o con el grabador de
**Ajustes → Sistema**. Los tres atajos de bloqueo, dictado y capturas deben ser
distintos. Consulta [Capturas de pantalla](screenshots.md).
