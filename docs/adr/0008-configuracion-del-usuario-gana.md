# ADR 0008: La configuración del usuario gana a la generada por Senda

## Estado

Aceptada.

## Contexto

Senda añade páginas de Ajustes sobre opciones que el usuario también puede definir en Hyprland, como pantallas, teclado y ratón. `require("modules.senda")` suele cargarse el último, de modo que una regla generada pisaría la del usuario. Además, quien no define nada no debe ver ninguna mención a esto.

## Decisión

- Senda solo escribe en sus archivos generados y guarda sus valores en `~/.config/senda/config`. Nunca edita los archivos del usuario.
- `integration.UserDefinitions(Selector)` detecta lo que define el usuario. El `Selector` indica la función Lua, su campo de destino y la palabra clave de `hyprland.conf`, y cada página declara el suyo (`MonitorSelector` para pantallas).
- Solo se analizan los archivos que Hyprland carga: desde `hyprland.lua` (o `hyprland.conf`), siguiendo `require`, `dofile` y `source` literales. Se ignoran los comentarios, los archivos sin cargar y los generados por Senda.
- Un destino concreto reclama su elemento. Un destino calculado (no literal) podría ser cualquiera, así que los reclama todos. Un destino vacío (`output = ""`) es solo un valor por defecto y no reclama nada, porque es la línea que trae la configuración inicial de Hyprland y las reglas concretas la sustituyen.
- Una llamada precedida por la línea `-- senda: runtime` no es una definición. Sirve para plugins que ajustan una opción en tiempo de ejecución. Esos plugins deben reconstruir sus cambios al recargar.
- Lo reclamado no se genera, la CLI rechaza cambiarlo y la interfaz lo muestra como gestionado por el usuario, con su `archivo:línea`. Esa sección no existe si no hay nada reclamado. Los valores guardados se conservan por si el usuario retira su definición.
- Como el módulo se carga el último, un módulo obsoleto ganaría al usuario. `senda display watch` lo regenera al recargar la configuración si sus reglas han cambiado. Solo puede haber un vigilante por usuario y hace como mucho una recarga automática por minuto: dos vigilantes con distinta visión de las reglas se recargaban por turnos sin fin.
- Los cambios de pantalla se aplican evaluando `hl.monitor` solo en el monitor afectado. Una recarga cambia el modo de todos los monitores y borra lo ajustado en tiempo de ejecución, así que solo se usa cuando desaparece una regla.

## Consecuencias

Una página nueva solo necesita un `Selector` y el mismo tratamiento de lo reclamado. Un `require` con ruta calculada no se sigue, y lo que defina no se detecta; es un análisis estático y se acepta ese límite. El primer `reload` tras añadir una definición puede aplicar aún la regla antigua, hasta que `watch` regenera el módulo.
