# Dictado por voz

`zenda stt` controla el dictado local. El audio se reconoce con el micrófono predeterminado y el texto final se copia al portapapeles; según el modo elegido también se pega en la ventana activa.

## Primer uso

`zenda setup` instala las dependencias del sistema y crea el módulo Lua de atajos si aún no existe. Para reconocer voz hacen falta un modelo y el motor Python:

```sh
zenda stt models list
zenda stt models install parakeet-tdt-0.6b-v3-int8
zenda stt runtime install
```

También se pueden instalar el motor y los modelos desde Ajustes → Dictado; ningún modelo se instala por sí solo. El catálogo muestra tipo, tamaño, idiomas, licencia y enlace a la licencia. Todos los modelos escriben texto en vivo mientras hablas. Los modelos con streaming lo hacen de forma nativa. Con los modelos sin streaming, como Parakeet, el motor retranscribe por rondas el audio que aún no ha fijado, con unos segundos de contexto previo; a partir de unos 16 s de audio pendiente fija ese tramo, salvo los últimos 2 s. Al terminar solo vuelve a transcribir los últimos segundos, así que la espera no crece con la duración del dictado, y si después de la última ronda solo hubo silencio entrega esa ronda sin transcribir nada más. Incluye Parakeet TDT 0.6B V3 INT8 (sin streaming; multilingüe, con español e inglés; CC-BY-4.0), Nemotron 3.5 Streaming 0.6B INT8 (español, OpenMDW 1.1), Nemotron Speech Streaming EN 0.6B INT8 (inglés, NVIDIA Open Model License), Streaming Zipformer EN 20M INT8 y Streaming Zipformer ZH/EN INT8 (Apache 2.0).

El motor se instala en un entorno virtual Python bajo `$XDG_DATA_HOME/zenda/stt/venv` (por defecto `~/.local/share/zenda/stt/venv`). Usa sherpa-onnx. Si `nvidia-smi -L` detecta NVIDIA, intenta instalar el runtime CUDA; si no está disponible o falla, instala CPU. Comprueba el estado con `zenda stt runtime status`.

## Control

El atajo predeterminado es `Alt + ñ`. Púlsalo para empezar a escuchar y otra vez para terminar y entregar el texto. `zenda stt toggle` hace el mismo toggle desde la terminal; `zenda stt cancel` cancela y descarta el resultado, y `zenda stt status` muestra el estado. El toggle comprueba que haya modelo, motor y micrófono antes de iniciar.

La cancelación con `Esc` está desactivada por ahora. La sesión puede mostrar el aviso «Esc no está disponible en esta sesión.»; para cancelar, usa `zenda stt cancel`. La segunda pulsación del atajo termina el dictado y entrega el texto.

En Ajustes → Dictado puedes activar o desactivar «Atenuar volumen durante el dictado» y ajustar el volumen deseado entre 0 y 100 % (Enter o pérdida de foco). Por defecto está activado al 10 %. Los cambios se aplican al siguiente dictado, también con el modelo precargado. Durante cada dictado con la opción activada, Zenda baja la salida al porcentaje elegido y restaura el volumen anterior al terminar, cancelar o producirse un error. Si la salida está silenciada o su volumen ya es igual o menor que ese porcentaje, no la toca. No cambia el silencio ni el volumen del micrófono. La precarga en reposo no modifica el volumen.

Las barras del dock se animan cuando el nivel capturado por el micrófono supera un umbral y quedan quietas durante el silencio. El ruido ambiental también puede activar el indicador: mide audio, no distingue voces de otros sonidos.

Si el puente de Discord está autorizado y el micro de Discord está abierto (ni silenciado ni ensordecido) al empezar la captura, Zenda lo silencia durante el dictado y lo desmutea al entregar, cancelar o fallar, solo si fue Zenda quien lo silenció. Si el micro estaba silenciado o ensordecido, no lo toca. Nunca cambia el ensordecido: si Discord está ensordecido al terminar, el micro queda silenciado y lo desmuteas tú. Si el puente no está autorizado o no responde en un segundo, el dictado sigue sin silenciar Discord.

## Precarga del modelo

En Ajustes → Dictado, el interruptor «Precargar modelo» está desactivado por defecto. Al activarlo, la shell mantiene el modelo cargado en reposo sin abrir el micrófono. El modelo predeterminado ocupa aproximadamente 475 MB en RAM o VRAM mientras está cargado, y permanece cargado entre dictados: al terminar o cancelar uno, se cierra el micrófono y se puede empezar otro sin volver a cargar el modelo. Sin precarga, cada dictado carga el modelo y lo libera al terminar o cancelarse; el micrófono solo vuelve a abrirse con una nueva pulsación.

Si pulsas el atajo mientras se carga el modelo, el dictado empieza al terminar la carga. Una segunda pulsación durante la carga anula esa petición. Tras tres fallos seguidos de carga, la shell deja de reintentar y Ajustes muestra el error. La siguiente pulsación permite volver a cargarlo incluso después de esos tres fallos. Los cambios de modelo, idioma o precarga durante un dictado se aplican al terminar ese dictado. La shell utiliza internamente `zenda stt session --standby` para mantener el modelo preparado.

Con precarga, una pulsación mientras termina o entrega el dictado pide el siguiente; otra pulsación anula esa petición. Lo mismo ocurre mientras el motor vuelve a estar listo o se reinicia por un cambio de ajustes. Si el proceso cae con esa petición pendiente, la shell la conserva al reiniciarlo, con el mismo límite de tres fallos. Sin precarga, las pulsaciones durante el cierre final se ignoran. Ajustes muestra «Listo» mientras el modelo residente está cargado, también durante el dictado, pero deja de mostrarlo mientras se cierra el motor. El dock permanece visible desde la pulsación hasta su cierre normal.

`zenda stt cancel` durante un dictado descarta solo ese dictado y mantiene el modelo residente. En reposo, o durante la carga sin un dictado pendiente, cierra el motor y detiene la precarga automática hasta la siguiente pulsación del atajo; los cambios de ajustes tampoco reactivan la precarga durante esa pausa. La siguiente pulsación aplica los ajustes actuales, carga el modelo, empieza el dictado y vuelve a dejarlo residente al terminar si la precarga sigue activada.

## Dock de dictado

Mientras dictas, un dock sale del marco inferior de la pantalla, con su mismo color y unido a él por esquinas curvas. Al empezar a escuchar es una burbuja compacta con barras animadas centradas; cuando llega texto en vivo se expande y muestra las últimas líneas de la transcripción bajo las barras, con desplazamiento con la rueda. Las últimas palabras, que el final del dictado aún puede corregir, aparecen atenuadas; con los modelos de streaming, lo atenuado es el fragmento que se está reconociendo. En Ajustes → Dictado, «Mostrar texto en vivo» (activado por defecto) permite ocultar el texto: el dock se queda en la burbuja con las barras y el resultado se entrega igual. El reconocimiento por rondas sigue funcionando, así que la espera al soltar no cambia. A partir del primer minuto muestra el tiempo de dictado, centrado bajo las barras. Al parar, siguen las barras hasta que el texto se entrega y el dock vuelve a meterse en el marco. Solo muestra texto mientras se prepara o carga el modelo y cuando hay un error. El dock no captura el ratón fuera de la burbuja ni el teclado.

## Ajustes

En Ajustes → Dictado se puede elegir idioma (español, detección automática o un código de idioma), modo de entrega y terminales reconocidas. Los interruptores y selectores guardan al cambiar; los campos editados (volumen, idioma, terminales y atajo) guardan con Enter o al perder el foco. El atajo se edita en Ajustes → Atajos (consulta [Bloqueo de pantalla](lock-screen.md#cambiar-los-atajos)). La CLI permite consultar o cambiar el atajo:

```sh
zenda stt shortcut show
zenda stt shortcut set 'ALT + ñ'
zenda stt shortcut apply
```

`set` escribe la preferencia y regenera y recarga el módulo. `apply` vuelve a generar el módulo con la preferencia guardada. El catálogo y motor se administran con `zenda stt models` y `zenda stt runtime`; consulta sus ayudas para los subcomandos.

Los modos de entrega son:

| `ZENDA_STT_PASTE_MODE` | Resultado |
|---|---|
| `paste` (predeterminado) | Copia el texto y simula `Ctrl+V`; en una terminal reconocida simula `Ctrl+Shift+V`. |
| `clipboard` | Copia el texto sin simular pegado. |

Las clases de ventana de terminal se configuran en `ZENDA_STT_TERMINALS`. Los valores predeterminados son `kitty`, `foot`, `Alacritty`, `org.wezfurlong.wezterm` y `com.mitchellh.ghostty`. La detección usa la clase de la ventana activa de Hyprland. La entrega copia el texto con `wl-copy` y pega con el dispatcher `send_shortcut` de Hyprland (Ctrl+V, o Ctrl+Shift+V en terminal), que envía el atajo a la ventana activa sin crear un teclado virtual; en modo `paste`, antes de pegar comprueba con `wl-paste` que el portapapeles ya contiene el texto (espera como máximo un segundo).

## Activar el atajo de Hyprland

`zenda setup` genera la carpeta común `~/.config/hypr/zenda/`. Si no se ha migrado una referencia antigua, añade esta línea a tu configuración de Hyprland:

```lua
require("zenda.init")
```

Revisa los conflictos que informa Ajustes o `zenda stt shortcut show`. Si otra acción usa la misma combinación, elige otra en Ajustes o con `zenda stt shortcut set <combo>`. Hyprland no carga el atajo hasta que se requiere el módulo. Si editas manualmente `hyprland.lua`, recarga Hyprland o usa `zenda stt shortcut apply` para regenerar y recargar el módulo.

Al ejecutar `zenda uninstall`, Zenda intenta cancelar el dictado y retira el módulo generado y las referencias que haya marcado como propias. Las referencias añadidas manualmente deben retirarse manualmente. Los archivos que no tengan una cabecera de Zenda se conservan.

## Problemas habituales

- **No hay modelo instalado:** instala uno con `zenda stt models install <id>` o desde Ajustes → Dictado.
- **No hay motor:** ejecuta `zenda stt runtime install`.
- **No se detecta micrófono:** conecta o selecciona una entrada de audio predeterminada y comprueba que no sea un monitor de salida.
- **El atajo no hace nada:** comprueba que `zenda stt shortcut show` indique el módulo cargado y añade el `require` a `hyprland.lua` si falta.
- **El atajo ya está asignado:** consulta los conflictos y elige otra combinación.
- **El texto no se pega:** comprueba que `wl-copy` esté instalado y que `hyprctl` responda en la sesión. En terminal, confirma que su clase esté incluida en `ZENDA_STT_TERMINALS`.
