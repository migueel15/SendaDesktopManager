# Teclado, ratón y cursor

La sección **Teclado y ratón** de Ajustes define la distribución de teclado, la velocidad del ratón (en porcentaje; 0–100 % equivale a -1…1 en Hyprland), la aceleración, el foco con el ratón, el touchpad (tocar para hacer clic, desplazamiento natural, desactivar al escribir, velocidad de desplazamiento). El tema y el tamaño del cursor están en **Apariencia**. Se guarda y se aplica al cambiar, y persiste tras recargar y reiniciar.

## Comandos

```sh
zenda input show [--json]
zenda input set --layout us,es --sensitivity 0.2 --tap-to-click true --natural-scroll false --cursor-theme Bibata-Modern-Ice --cursor-size 26 \
  --accel-profile flat --follow-mouse 1 --disable-while-typing true --scroll-factor 0.4 --touchpad-sensitivity 0.6
zenda input cursor-themes
zenda input sync
```

Un valor vacío (`--layout=`) devuelve ese campo a su valor por defecto.

## Valores por defecto

Lo que nadie haya elegido ni definido usa: la distribución del sistema (`00-keyboard.conf` o `/etc/vconsole.conf`; si no se conoce, no se genera), velocidad del 50 %, aceleración plana, foco que sigue al ratón, y tocar para hacer clic y desplazamiento natural activados.

Cada ajuste cambiado muestra en Ajustes un icono para restablecerlo a su valor por defecto. Al quitar el tema o el tamaño de cursor, el cambio se completa al iniciar sesión de nuevo.

## Convivencia con tu configuración

Zenda solo escribe en `~/.config/zenda/config` y en su módulo generado `zenda/`; fuera de archivos, solo cambia el cursor GTK con `gsettings`. Sigue los `require` y `source` desde `hyprland.lua` o `hyprland.conf`, sin contar comentarios, archivos no cargados ni bloques de dispositivo, y busca:

- `kb_layout`, `sensitivity`, `accel_profile`, `follow_mouse`, `tap_to_click`, `natural_scroll`, `disable_while_typing` y `scroll_factor` en `input`.
- `XCURSOR_THEME`, `HYPRCURSOR_THEME`, `XCURSOR_SIZE` o `HYPRCURSOR_SIZE` con `hl.env` o `env =`, `hyprctl setcursor`, `gsettings set org.gnome.desktop.interface cursor…`, y esas variables en `uwsm/env*` y `environment.d`.

Lo que definas tú gana: Zenda no lo genera, aunque tenga un valor guardado, y lo muestra como gestionado por el usuario, con el control desactivado. `zenda input set` rechaza esos campos. Los campos que nadie define no muestran ninguna indicación y usan los valores por defecto. Si quitas tu definición, vuelve a aplicarse el valor guardado en Zenda.

`zenda input sync` regenera el módulo si tu configuración cambió. Se ejecuta al iniciar Hyprland y al abrir Ajustes.

## Límites

- Los `hl.device` y `tablet` no se controlan desde Ajustes. Un `hl.device` con `sensitivity` o `accel_profile` manda sobre el ajuste global para ese ratón.
- La velocidad del touchpad vale lo mismo que la del ratón mientras no elijas una propia (`--touchpad-sensitivity`, de -1 a 1; vacío vuelve a heredar). Con valor propio, Zenda añade un `hl.device` con `sensitivity` por cada touchpad que udev marca con `ID_INPUT_TOUCHPAD=1`, porque Hyprland no tiene esa opción dentro de `input.touchpad`. Si tu configuración ya define un `hl.device` con `sensitivity` para ese touchpad, gana el tuyo y el control aparece como gestionado. La aceleración sigue siendo común.
- Los `require` construidos en tiempo de ejecución no se siguen.
- El tema se aplica con `hyprctl setcursor`, por entorno a las aplicaciones nuevas y con `gsettings` a las GTK. El cambio en `gsettings` se queda aunque quites el tema de Zenda.
