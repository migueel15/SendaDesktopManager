# Fondo de pantalla

Quickshell renderiza el fondo en una capa por pantalla. `senda wallpaper set` comprueba la imagen y envía la petición a la shell; acepta PNG, JPEG y GIF. Si no hay imagen, se ve el color `base` del tema.

```sh
senda wallpaper set /ruta/imagen.png
senda wallpaper set /ruta/imagen.jpg --monitor DP-1 --resize fit --transition-type fade --transition-duration 800ms
senda wallpaper set /ruta/imagen.png --transition-type grow --pos 200,100
```

| Opción | Comportamiento |
|---|---|
| `--monitor` | Nombre de pantalla; vacío (predeterminado) aplica a todas las conectadas. |
| `--resize` | `crop` (predeterminado), `fit`, `stretch` o `none`. |
| `--transition-type` | `none` (predeterminado), `fade`, `wipe`, `wave`, `grow`, `center`, `any`, `outer` o `random`. `random` elige una de las siete animaciones. |
| `--transition-duration` | Duración no negativa; predeterminado `3s`. Con `none` el cambio es inmediato. |
| `--transition-bezier` | Curva `x1,y1,x2,y2`; predeterminado `.61,.18,.48,.9`. `x1` y `x2` deben estar entre 0 y 1. |
| `--pos` | Origen `x,y` en píxeles de la pantalla, desde la **esquina inferior izquierda**; por defecto, el centro. `center` y `any` eligen su propio origen. |
| `--transition-fps` | Se acepta por compatibilidad, pero **no tiene efecto**. |

Quickshell carga la imagen antes de empezar la transición. `fade` funde, `wipe` y `wave` barren la pantalla, y `grow`, `center`, `any` y `outer` usan máscaras circulares. Una petición nueva sustituye una transición en curso.

La selección manual se guarda por nombre de pantalla en `$XDG_STATE_HOME/senda/wallpapers.json` (por defecto `~/.local/state/senda/wallpapers.json`); guarda ruta y modo de ajuste. Al iniciar, una selección manual guardada prevalece sobre la imagen del tema. Al aplicar o recargar un tema se borran las selecciones manuales y su estado, y la imagen del tema aparece con un fundido de 800 ms. Los cambios válidos del tema activo también actualizan el fondo.

## Selector de fondos

`senda wallpaper pick` o **Selector de fondos** en el lanzador abre un panel inferior en la pantalla enfocada, con un carrusel de las imágenes de `$XDG_CONFIG_HOME/senda/wallpapers` (por defecto `~/.config/senda/wallpapers`). También puedes dejar archivos PNG, JPEG o GIF ahí a mano.

- **Solo esta sesión** crea una selección manual: al aplicar o recargar un tema vuelve su fondo.
- **Guardar en el tema** copia la imagen al tema de usuario activo. Con un tema integrado pide un nombre, crea una copia con esa imagen y la aplica.
- **Importar…** abre un explorador y copia la imagen a la carpeta de fondos. Equivale a `senda wallpaper import /ruta/imagen.png`, que imprime la ruta de la copia. El borrado posterior del original no afecta al fondo y reimportar el mismo contenido reutiliza la copia.
