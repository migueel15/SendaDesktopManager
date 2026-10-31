# ADR 0010: Carpeta generada dentro de la configuración de Hyprland

## Estado

Aceptada. Sustituye al módulo único `modules/senda.lua` de los ADR 0004 y 0006.

## Contexto

Lo generado para Hyprland estaba en un solo archivo dentro de los dotfiles del usuario, y `hypridle.conf` en `~/.config/senda`, que es portable y no debe contener nada generado.

## Decisión

- Todo lo generado vive en `~/.config/hypr/senda/`: `init.lua`, un módulo por área, `hypridle.conf` y un `.gitignore` que ignora todo. Se regenera por completo desde `~/.config/senda`.
- `hyprland.lua` importa la carpeta con `require("senda.init")`, que no depende de que `package.path` tenga `?/init.lua`.
- `init.lua` carga sus módulos por ruta, a partir de su propia ubicación. Así la carpeta funciona esté donde esté, y `hypridle.conf` tampoco depende de una ruta absoluta generada.
- La ubicación se pregunta a la sesión con `senda_module_version` y `debug.getinfo`. Si la carpeta no está importada se considera inexistente y se regenera en la ruta por defecto con su import. Si la carpeta cargada se ha borrado, se regenera en esa misma ruta, porque el import sigue apuntando ahí. Sin sesión, se siguen los `require` literales de `hyprland.lua`.
- Para añadir un módulo basta una entrada en `generatedModules` (`core/internal/hyprland/integration/generated.go`). Escritura, carga, comprobación de propiedad, limpieza y desinstalación salen de esa lista.
- Si `modules/senda.lua` no se puede borrar porque hay otras referencias, se vacía y se avisa: conservar su contenido duplicaría los atajos.

## Consecuencias

Solo se migra la ruta antigua por defecto; un `senda.lua` movido por el usuario hay que retirarlo a mano. Los temas exportados siguen en `~/.config/senda/generated`, porque no son de Hyprland; moverlos es una decisión aparte.
