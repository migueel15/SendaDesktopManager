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

En Ajustes → Dictado puedes activar o desactivar «Atenuar volumen durante el dictado» y ajustar el volumen deseado entre 0 y 100 % (Enter o pérdida de foco). Por defecto está activado al 10 %. Los cambios se aplican al siguiente dictado, también con el modelo precargado. Durante cada dictado con la opción activada, Senda ajusta la salida al porcentaje elegido y restaura el volumen anterior al terminar, cancelar o producirse un error. No cambia el silencio ni el volumen del micrófono. La precarga en reposo no modifica el volumen.

Las barras del dock se animan cuando el nivel capturado por el micrófono supera un umbral y quedan quietas durante el silencio. El ruido ambiental también puede activar el indicador: mide audio, no distingue voces de otros sonidos.

Si el puente de Discord está autorizado y el micro de Discord está abierto (ni silenciado ni ensordecido) al empezar la captura, Senda lo silencia durante el dictado y lo desmutea al entregar, cancelar o fallar, solo si fue Senda quien lo silenció. Si el micro estaba silenciado o ensordecido, no lo toca. Nunca cambia el ensordecido: si Discord está ensordecido al terminar, el micro queda silenciado y lo desmuteas tú. Si el puente no está autorizado o no responde en un segundo, el dictado sigue sin silenciar Discord.

## Precarga del modelo

En Ajustes → Dictado, el interruptor «Precargar modelo» está desactivado por defecto. Al activarlo, la shell mantiene el modelo cargado en reposo sin abrir el micrófono. El modelo predeterminado ocupa aproximadamente 475 MB en RAM o VRAM mientras está cargado, y permanece cargado entre dictados: al terminar o cancelar uno, se cierra el micrófono y se puede empezar otro sin volver a cargar el modelo. Sin precarga, cada dictado carga el modelo y lo libera al terminar o cancelarse; el micrófono solo vuelve a abrirse con una nueva pulsación.

Si pulsas el atajo mientras se carga el modelo, el dictado empieza al terminar la carga. Una segunda pulsación durante la carga anula esa petición. Tras tres fallos seguidos de carga, la shell deja de reintentar y Ajustes muestra el error. La siguiente pulsación permite volver a cargarlo incluso después de esos tres fallos. Los cambios de modelo, idioma o precarga durante un dictado se aplican al terminar ese dictado. La shell utiliza internamente `senda stt session --standby` para mantener el modelo preparado.

Con precarga, una pulsación mientras termina o entrega el dictado pide el siguiente; otra pulsación anula esa petición. Lo mismo ocurre mientras el motor vuelve a estar listo o se reinicia por un cambio de ajustes. Si el proceso cae con esa petición pendiente, la shell la conserva al reiniciarlo, con el mismo límite de tres fallos. Sin precarga, las pulsaciones durante el cierre final se ignoran. Ajustes muestra «Listo» mientras el modelo residente está cargado, también durante el dictado, pero deja de mostrarlo mientras se cierra el motor. El dock permanece visible desde la pulsación hasta su cierre normal.

`senda stt cancel` durante un dictado descarta solo ese dictado y mantiene el modelo residente. En reposo, o durante la carga sin un dictado pendiente, cierra el motor y detiene la precarga automática hasta la siguiente pulsación del atajo; los cambios de ajustes tampoco reactivan la precarga durante esa pausa. La siguiente pulsación aplica los ajustes actuales, carga el modelo, empieza el dictado y vuelve a dejarlo residente al terminar si la precarga sigue activada.

## Dock de dictado

Mientras dictas, un dock sale del marco inferior de la pantalla, con su mismo color y unido a él por esquinas curvas. Al empezar a escuchar es una burbuja compacta con barras animadas centradas; cuando llega texto en vivo se expande y muestra las últimas líneas de la transcripción bajo las barras, con desplazamiento con la rueda. A partir del primer minuto muestra el tiempo de dictado, centrado bajo las barras. Al parar, siguen las barras hasta que el texto se entrega y el dock vuelve a meterse en el marco. Solo muestra texto mientras se prepara o carga el modelo y cuando hay un error. El dock no captura el ratón fuera de la burbuja ni el teclado.

## Ajustes

En Ajustes → Dictado se puede elegir idioma (español, detección automática o un código de idioma), modo de entrega y terminales reconocidas. Los interruptores y selectores guardan al cambiar; los campos editados (volumen, idioma, terminales y atajo) guardan con Enter o al perder el foco. También se puede configurar el atajo, ver si el módulo está cargado y qué binds entran en conflicto. La CLI permite consultar o cambiar el atajo:

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

Las clases de ventana de terminal se configuran en `SENDA_STT_TERMINALS`. Los valores predeterminados son `kitty`, `foot`, `Alacritty`, `org.wezfurlong.wezterm` y `com.mitchellh.ghostty`. La detección usa la clase de la ventana activa de Hyprland. La entrega usa `wl-copy` y `wtype`; en modo `paste`, antes de pegar comprueba con `wl-paste` que el portapapeles ya contiene el texto (espera como máximo un segundo).

## Activar el atajo de Hyprland

`senda setup` genera el módulo común `~/.config/hypr/modules/senda.lua`. Si no se ha migrado una referencia antigua, añade esta línea a tu configuración de Hyprland:

```lua
require("modules.senda")
```

Revisa los conflictos que informa Ajustes o `senda stt shortcut show`. Si otra acción usa la misma combinación, elige otra en Ajustes o con `senda stt shortcut set <combo>`. Hyprland no carga el atajo hasta que se requiere el módulo. Si editas manualmente `hyprland.lua`, recarga Hyprland o usa `senda stt shortcut apply` para regenerar y recargar el módulo.

Al ejecutar `senda uninstall`, Senda intenta cancelar el dictado y retira el módulo generado y las referencias que haya marcado como propias. Las referencias añadidas manualmente deben retirarse manualmente. Los archivos que no tengan una cabecera de Senda se conservan.

## Problemas habituales

- **No hay modelo instalado:** instala uno con `senda stt models install <id>` o desde Ajustes → Dictado.
- **No hay motor:** ejecuta `senda stt runtime install`.
- **No se detecta micrófono:** conecta o selecciona una entrada de audio predeterminada y comprueba que no sea un monitor de salida.
- **El atajo no hace nada:** comprueba que `senda stt shortcut show` indique el módulo cargado y añade el `require` a `hyprland.lua` si falta.
- **El atajo ya está asignado:** consulta los conflictos y elige otra combinación.
- **El texto no se pega:** comprueba que `wl-copy` y `wtype` estén instalados. En terminal, confirma que su clase esté incluida en `SENDA_STT_TERMINALS`.
