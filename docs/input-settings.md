# Teclado, ratón y cursor

La sección **Teclado y ratón** de Ajustes define la distribución de teclado, la velocidad del ratón (en porcentaje; 0–100 % equivale a -1…1 en Hyprland), la aceleración, el foco con el ratón, el touchpad (tocar para hacer clic, desplazamiento natural, desactivar al escribir, velocidad de desplazamiento) y el tema y tamaño de cursor. Se guarda y se aplica al cambiar, y persiste tras recargar y reiniciar.

## Comandos

```sh
senda input show [--json]
senda input set --layout us,es --sensitivity 0.2 --tap-to-click true --natural-scroll false --cursor-theme Bibata-Modern-Ice --cursor-size 26 \
  --accel-profile flat --follow-mouse 1 --disable-while-typing true --scroll-factor 0.4
senda input cursor-themes
senda input sync
```

Un valor vacío (`--layout=`) devuelve ese campo a su valor por defecto.

## Valores por defecto

Lo que nadie haya elegido ni definido usa: la distribución del sistema (`00-keyboard.conf` o `/etc/vconsole.conf`; si no se conoce, no se genera), velocidad del 50 %, aceleración plana, foco que sigue al ratón, y tocar para hacer clic y desplazamiento natural activados.

Cada ajuste cambiado muestra en Ajustes un icono para restablecerlo a su valor por defecto. Al quitar el tema o el tamaño de cursor, el cambio se completa al iniciar sesión de nuevo.

## Convivencia con tu configuración

Senda solo escribe en `~/.config/senda/config` y en su módulo generado `modules/senda.lua`; fuera de archivos, solo cambia el cursor GTK con `gsettings`. Sigue los `require` y `source` desde `hyprland.lua` o `hyprland.conf`, sin contar comentarios, archivos no cargados ni bloques de dispositivo, y busca:

- `kb_layout`, `sensitivity`, `accel_profile`, `follow_mouse`, `tap_to_click`, `natural_scroll`, `disable_while_typing` y `scroll_factor` en `input`.
- `XCURSOR_THEME`, `HYPRCURSOR_THEME`, `XCURSOR_SIZE` o `HYPRCURSOR_SIZE` con `hl.env` o `env =`, `hyprctl setcursor`, `gsettings set org.gnome.desktop.interface cursor…`, y esas variables en `uwsm/env*` y `environment.d`.

Lo que definas tú gana: Senda no lo genera, aunque tenga un valor guardado, y lo muestra como gestionado por el usuario, con el control desactivado. `senda input set` rechaza esos campos. Los campos que nadie define no muestran ninguna indicación y usan los valores por defecto. Si quitas tu definición, vuelve a aplicarse el valor guardado en Senda.

`senda input sync` regenera el módulo si tu configuración cambió. Se ejecuta al iniciar Hyprland y al abrir Ajustes.

## Límites

- Los `hl.device` y `tablet` no se controlan desde Ajustes. Un `hl.device` con `sensitivity` o `accel_profile` manda sobre el ajuste global para ese ratón.
- Los `require` construidos en tiempo de ejecución no se siguen.
- El tema se aplica con `hyprctl setcursor`, por entorno a las aplicaciones nuevas y con `gsettings` a las GTK. El cambio en `gsettings` se queda aunque quites el tema de Senda.
