# Teclado, ratón y cursor

La sección **Teclado y ratón** de Ajustes define la distribución de teclado, la velocidad del ratón, el touchpad (tocar para hacer clic, desplazamiento natural) y el tema de cursor. Se guarda y se aplica al cambiar, y persiste tras recargar y reiniciar.

## Comandos

```sh
senda input show [--json]
senda input set --layout us,es --sensitivity 0.2 --tap-to-click true --natural-scroll false --cursor-theme Bibata-Modern-Ice
senda input cursor-themes
senda input sync
```

Un valor vacío (`--layout=`) hace que Senda deje de definir ese campo.

## Convivencia con tu configuración

Senda solo escribe en `~/.config/senda/config` y en su módulo generado `modules/senda.lua`. Sigue los `require` y `source` desde `hyprland.lua` o `hyprland.conf`, sin contar comentarios, archivos no cargados ni bloques de dispositivo, y busca:

- `kb_layout`, `sensitivity`, `tap_to_click` y `natural_scroll` en `input`.
- `XCURSOR_THEME` o `HYPRCURSOR_THEME` con `hl.env` o `env =`, `hyprctl setcursor`, y esas variables en `uwsm/env*` y `environment.d`.

Lo que definas tú gana: Senda no lo genera, aunque tenga un valor guardado, y lo muestra como gestionado por el usuario, con el control desactivado. `senda input set` rechaza esos campos. Los campos que nadie define no muestran ninguna indicación ni generan nada. Si quitas tu definición, vuelve a aplicarse el valor guardado en Senda.

`senda input sync` regenera el módulo si tu configuración cambió. Se ejecuta al iniciar Hyprland y al abrir Ajustes.

## Límites

- Los `require` construidos en tiempo de ejecución no se siguen.
- El tema se aplica con `hyprctl setcursor` y a las aplicaciones nuevas por entorno. Senda no toca `gsettings`, así que algunas aplicaciones GTK pueden mantener el suyo.
