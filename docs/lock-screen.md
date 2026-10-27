# Bloqueo de pantalla

Senda proporciona `senda lock` y el target IPC `lock`: `lock()` solicita el bloqueo e `isLocked()` indica si está solicitado o activo. El servicio reactiva primero los teclados gestionados por Senda; si falla, registra el error y solicita igualmente el bloqueo. PAM utiliza la configuración `login` y la contraseña solo se entrega a PAM.

La pantalla deja ver el escritorio oscurecido a través de la superficie translúcida. En Hyprland, `misc.session_lock_xray` y `misc.session_lock_blur` deben estar activos y `decoration.blur` debe estar habilitado para que el compositor desenfoque lo que hay detrás; su intensidad depende de `decoration.blur.size` y `passes`. Comprueba visualmente que el texto no sea legible en cada monitor antes de confiar en el efecto. Hyprland debe tener `misc.allow_session_lock_restore = true` para permitir recuperar una sesión bloqueada si Quickshell termina. Senda guarda un marcador volátil mientras está bloqueada y vuelve a solicitar el bloqueo al arrancar. Si Quickshell muere con la sesión bloqueada, pasa a un TTY y vuelve a lanzar la instancia de Senda con su entorno gráfico y de Hyprland. `loginctl unlock-session` por sí solo no garantiza desbloquear el protocolo Wayland; no sustituye la autenticación PAM.

`senda setup` genera `~/.config/hypr/modules/senda.lua` y el archivo privado `~/.config/senda/hypridle.conf`. Si no se ha migrado una referencia antigua, carga `require("modules.senda")` desde `hyprland.lua`. El módulo contiene los atajos de bloqueo y dictado y habilita la recuperación del bloqueo. Senda no sobrescribe archivos sin cabecera propia.

```sh
senda hyprland show --json
senda hyprland set --lock-shortcut 'SUPER + CTRL + l' --dictation-shortcut 'ALT + ñ' --idle-seconds 600 --blur true --json
```

El tiempo `0` desactiva el bloqueo por inactividad. `set` valida los ajustes, los guarda y reemplaza cada archivo generado de forma atómica; en sesión recarga Hyprland. Si hay un hypridle con otra configuración, lo conserva y avisa: integra antes los ajustes que necesites y decide cómo activar una sola instancia. Si no hay ninguna instancia, `set` inicia `hypridle -c ~/.config/senda/hypridle.conf` en sesión. Solo reinicia automáticamente una instancia iniciada y registrada por Senda; si fue iniciada de otra manera, pide reiniciarla manualmente. Para que hypridle arranque en cada sesión, configura su inicio en tu entorno después de eliminar el arranque duplicado existente.

El archivo usa `inhibit_sleep = 3`, `lock_cmd`, `before_sleep_cmd` y `after_sleep_cmd`; espera la confirmación del bloqueo antes de suspender. Requiere hypridle y Senda activos. El desenfoque también requiere `decoration.blur.enabled` y valores positivos de `size` y `passes` en Hyprland.
