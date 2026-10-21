# Dictado por voz

`senda stt` controla el dictado local. El audio se reconoce con el micrófono predeterminado y el texto final se copia al portapapeles; según el modo elegido también se pega en la ventana activa.

## Primer uso

`senda setup` instala las dependencias del sistema y crea el módulo Lua de atajos si aún no existe. Para reconocer voz hacen falta un modelo y el motor Python:

```sh
senda stt models list
senda stt models install nemotron-3.5-streaming-0.6b-int8
senda stt runtime install
```

También se pueden instalar el motor y los modelos desde Ajustes → Dictado. El modelo Nemotron predeterminado ocupa unos 475 MB. El catálogo muestra tamaño, idiomas, licencia y enlace a la licencia. Incluye Nemotron 3.5 Streaming 0.6B INT8 (español, OpenMDW 1.1), Nemotron Speech Streaming EN 0.6B INT8 (inglés, NVIDIA Open Model License), Streaming Zipformer EN 20M INT8 y Streaming Zipformer ZH/EN INT8 (Apache 2.0).

El motor se instala en un entorno virtual Python bajo `$XDG_DATA_HOME/senda/stt/venv` (por defecto `~/.local/share/senda/stt/venv`). Usa sherpa-onnx. Si `nvidia-smi -L` detecta NVIDIA, intenta instalar el runtime CUDA; si no está disponible o falla, instala CPU. Comprueba el estado con `senda stt runtime status`.

## Control

El atajo predeterminado es `Alt + ñ`. Púlsalo para empezar a escuchar y otra vez para terminar y entregar el texto. `senda stt toggle` hace el mismo toggle desde la terminal; `senda stt cancel` cancela y descarta el resultado, y `senda stt status` muestra el estado. El toggle comprueba que haya modelo, motor y micrófono antes de iniciar.

La cancelación con `Esc` está desactivada por ahora. La sesión puede mostrar el aviso «Esc no está disponible en esta sesión.»; para cancelar, usa `senda stt cancel`. La segunda pulsación del atajo termina el dictado y entrega el texto.

## Precarga del modelo

En Ajustes → Dictado, el interruptor «Precargar modelo» está desactivado por defecto. Al activarlo, la shell mantiene el modelo cargado en reposo sin abrir el micrófono. El modelo predeterminado ocupa aproximadamente 475 MB en RAM o VRAM mientras está cargado, y el dictado puede empezar sin esperar a que se cargue.

Si pulsas el atajo mientras se carga el modelo, el dictado empieza al terminar la carga. Una segunda pulsación durante la carga anula esa petición. Tras tres fallos seguidos de carga, la shell deja de reintentar y Ajustes muestra el error. Los cambios de modelo durante un dictado se aplican al terminar la sesión. La shell utiliza internamente `senda stt session --standby` para mantener el modelo preparado.

## Ajustes

En Ajustes → Dictado se puede elegir idioma (español, detección automática o un código de idioma), modo de entrega y terminales reconocidas. También se puede configurar el atajo, ver si el módulo está cargado y qué binds entran en conflicto. La CLI permite consultar o cambiar el atajo:

```sh
senda stt shortcut show
senda stt shortcut set 'ALT + ñ'
senda stt shortcut apply
```

`set` escribe la preferencia y regenera y recarga el módulo. `apply` vuelve a generar el módulo con la preferencia guardada. El catálogo y motor se administran con `senda stt models` y `senda stt runtime`; consulta sus ayudas para los subcomandos.

Los modos de entrega son:

| `SENDA_STT_PASTE_MODE` | Resultado |
|---|---|
| `paste` (predeterminado) | Copia el texto y simula `Ctrl+V`; en una terminal reconocida simula `Ctrl+Shift+V`. |
| `clipboard` | Copia el texto sin simular pegado. |

Las clases de ventana de terminal se configuran en `SENDA_STT_TERMINALS`. Los valores predeterminados son `kitty`, `foot`, `Alacritty`, `org.wezfurlong.wezterm` y `com.mitchellh.ghostty`. La detección usa la clase de la ventana activa de Hyprland. La entrega usa `wl-copy` y `wtype`.

## Activar el atajo de Hyprland

`senda setup` crea `~/.config/hypr/modules/senda_binds.lua` si no existe. No modifica `hyprland.lua`: añade esta línea a tu configuración de Hyprland para cargar el módulo:

```lua
require("modules.senda_binds")
```

Revisa los conflictos que informa Ajustes o `senda stt shortcut show`. Si otra acción usa la misma combinación, elige otra en Ajustes o con `senda stt shortcut set <combo>`. Hyprland no carga el atajo hasta que se requiere el módulo. Si editas manualmente `hyprland.lua`, recarga Hyprland o usa `senda stt shortcut apply` para regenerar y recargar el módulo.

Al ejecutar `senda uninstall`, Senda intenta cancelar el dictado y, si existe `senda_binds.lua`, lo reemplaza por un módulo desactivado y recarga Hyprland. Después elimina los directorios de datos y configuración de Senda. Puedes quitar también `require("modules.senda_binds")` de `hyprland.lua`; el instalador y `setup` no editan ese archivo.

## Problemas habituales

- **No hay modelo instalado:** instala uno con `senda stt models install <id>` o desde Ajustes → Dictado.
- **No hay motor:** ejecuta `senda stt runtime install`.
- **No se detecta micrófono:** conecta o selecciona una entrada de audio predeterminada y comprueba que no sea un monitor de salida.
- **El atajo no hace nada:** comprueba que `senda stt shortcut show` indique el módulo cargado y añade el `require` a `hyprland.lua` si falta.
- **El atajo ya está asignado:** consulta los conflictos y elige otra combinación.
- **El texto no se pega:** comprueba que `wl-copy` y `wtype` estén instalados. En terminal, confirma que su clase esté incluida en `SENDA_STT_TERMINALS`.
