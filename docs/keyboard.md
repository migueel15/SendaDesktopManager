# Teclados físicos

`senda keyboard devices` enumera los dispositivos de entrada, su inclusión y su correspondencia con Hyprland. `senda keyboard off` desactiva los teclados físicos detectados; `on` reactiva los detectados y los guardados en el último bloqueo; `toggle` alterna y `status` muestra el estado y los dispositivos. Los dispositivos virtuales se excluyen. Los teclados físicos sin correspondencia en Hyprland generan un aviso. La interfaz de teclas de un ratón puede considerarse teclado sin afectar a su movimiento.

El estado es volátil en `$XDG_RUNTIME_DIR/senda/keyboard.json`: es la fuente de verdad de Senda, ya que Hyprland no expone el valor real. Una recarga de configuración de Hyprland lo restablece a `on`. No cambies manualmente el estado de dispositivos desde otras herramientas si necesitas que `status` sea exacto. Si hay un fallo se muestra `error`; ejecuta `senda keyboard on` para intentar recuperar los dispositivos. `off` se rechaza mientras se solicita o mantiene el bloqueo de pantalla.

## Teclas multimedia

El módulo generado `media.lua` asigna de serie las teclas de volumen, silencio, micrófono, reproducción y brillo. Todas funcionan con la pantalla bloqueada; volumen y brillo se repiten al mantener la tecla. El volumen sube hasta el 100 %, y la reproducción actúa por MPRIS sobre el reproductor activo mediante `senda media play-pause|next|previous`, por lo que necesita la shell en marcha.

Si tu configuración de Hyprland ya asigna una de esas teclas sin modificadores, Senda no genera esa tecla ([ADR 0008](adr/0008-configuracion-del-usuario-gana.md)). Solo se reconocen las teclas escritas literalmente; un `hl.bind` con la tecla calculada no reclama ninguna, porque es la forma habitual de los bucles de atajos.
