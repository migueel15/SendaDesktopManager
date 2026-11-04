# ADR 0004: Dictado local y binds de Hyprland

## Estado

Aceptada.

## Contexto

El dictado necesita un motor de reconocimiento, modelos descargables y un atajo que pueda cancelar la sesión con `Esc`. La instalación debe integrarse con Hyprland sin apropiarse de la configuración principal del usuario.

## Decisiones

1. El motor de dictado se implementa como un proceso Python que usa sherpa-onnx. Zenda instala sherpa-onnx en un entorno virtual bajo `$XDG_DATA_HOME/zenda/stt/venv`, junto a los datos de dictado. Así el runtime se actualiza de forma independiente del binario Go y no requiere instalar sherpa-onnx en el Python global.
2. Se descarta enlazar sherpa-onnx con cgo porque acoplaría el binario a una dependencia nativa y su distribución. Se descarta distribuir binarios del motor porque habría que mantener y publicar sus variantes de plataforma. No se requiere un paquete de AUR para el motor: el venv se instala con Python y pip desde la CLI.
3. El runtime intenta CUDA cuando detecta `nvidia-smi`; si la instalación CUDA no funciona, instala la variante CPU. La ubicación de datos sigue la ruta XDG de Zenda.
4. `zenda_binds.lua` es propiedad de Zenda y se ubica en `~/.config/hypr/modules/`. `zenda setup` lo crea solo si no existe; los ajustes del atajo lo regeneran. `zenda uninstall` lo sustituye por una versión desactivada y recarga Hyprland cuando puede.
5. Ni el instalador ni `zenda setup` editan `hyprland.lua`. Como en el punto 6 del [ADR 0003](0003-servicio-de-usuario.md), el usuario conserva el control de su configuración. La carga manual de `require("modules.zenda_binds")` en `hyprland.lua` es la excepción necesaria para activar este bind: el servicio arranca sin editar ese archivo, pero Hyprland no carga el atajo hasta que el usuario añade el `require`.

## Consecuencias

- El runtime de Python y los modelos residen en los datos de Zenda y se eliminan con `zenda uninstall`.
- El usuario decide dónde cargar el módulo en su configuración de Hyprland y debe quitar el `require` al desinstalar Zenda.
- Regenerar el módulo sustituye su contenido, por lo que no debe usarse para guardar personalizaciones dentro de `zenda_binds.lua`.

## Revisión (2026-10-22)

En f-002 se elimina el submapa `zenda_stt` y se deshabilita la cancelación con `Esc`. El atajo de Hyprland inicia o termina el dictado; para cancelarlo se usa `zenda stt cancel`.

## Enmienda: módulo único

Se sustituyen las decisiones 4 y 5 sobre `zenda_binds.lua` por `modules/zenda.lua`, compartido por bloqueo y dictado. Los ajustes se guardan en el archivo de Zenda y el atajo anterior se importa. Solo se migran referencias y módulos antiguos identificados como propios cuando la operación es inequívoca; las referencias manuales nuevas siguen bajo control del usuario. `zenda uninstall` retira el módulo propio y la referencia marcada por Zenda.
