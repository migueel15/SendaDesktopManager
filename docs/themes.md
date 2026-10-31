# Temas

Senda usa un tema activo para los colores de Quickshell y el fondo de pantalla. Los temas integrados `zenda-ice`, `zenda-lavanda` y `catppuccin-mocha` son de solo lectura. `catppuccin-mocha` usa la paleta Mocha de [Catppuccin](https://catppuccin.com), así que en Neovim reproduce los colores del esquema original. Los temas de usuario se guardan en `$XDG_CONFIG_HOME/senda/themes/<nombre>/` (por defecto `~/.config/senda/themes/<nombre>/`).

## Formato

Cada carpeta contiene `theme.json` y una imagen. Puedes partir de [`template.json`](../quickshell/themes/template.json); [`theme.schema.json`](../quickshell/themes/theme.schema.json) describe el contrato C-2. El objeto JSON tiene exactamente `name`, `wallpaper` y `colors`, sin campos adicionales. `wallpaper` admite una ruta absoluta o relativa a la carpeta del tema.

Las 21 claves obligatorias de `colors` son `base`, `background`, `surface`, `border`, `surfaceVariant`, `surfaceRaised`, `surfaceRaisedBorder`, `overlay`, `textMuted`, `white`, `primary`, `secondary`, `accent`, `accentDeep`, `selection`, `focus`, `success`, `warning`, `error`, `info` y `text`. Cada valor debe tener forma `#RRGGBB`; no se admiten colores adicionales.

El nombre usa minúsculas, números y guiones entre segmentos, con un máximo de 40 caracteres. En un tema de usuario debe coincidir con el nombre de la carpeta y no puede reservar el nombre de un tema integrado. La imagen debe existir y tener una cabecera PNG, JPEG o GIF con dimensiones positivas. Al guardar o validar se exige además que pueda decodificarse por completo. `senda theme validate` señala el campo que falla.

## Comandos

```sh
senda theme list                 # incluye temas inválidos y muestra su error
senda theme list --json
senda theme validate mi-tema
senda theme validate /ruta/theme.json --json
senda theme current              # nombre efectivo
senda theme current --json       # incluye fallback y warning
senda theme apply mi-tema
senda theme apply mi-tema --json  # devuelve el tema efectivo, con fallback y warning
senda theme delete mi-tema
senda theme duplicate zenda-ice mi-tema  # copia editable con nombre nuevo
senda theme watch mi-tema --notify
senda theme export               # genera los archivos para otras aplicaciones
```

`list`, `validate`, `current`, `apply` y `duplicate` admiten `--json`; `validate` y `current` admiten `--notify`. `apply` y `delete` admiten `--no-reload`. `watch` emite una línea JSON tras detectar un cambio estable en `theme.json` o la imagen; admite `--interval` (por defecto `1s`) y `--notify` para los cambios inválidos. Solo los cambios válidos del tema activo se aplican en vivo. Si la shell está abierta, `apply` solicita recarga; un cambio inválido conserva los colores anteriores.

`list`, `current`, `apply` y `watch` validan el contrato de `theme.json`, la existencia de la imagen, su formato y sus dimensiones mediante la cabecera, sin decodificar los píxeles. Por tanto, una imagen truncada después de una cabecera válida puede aceptarse en estos comandos. `validate` (por nombre o por ruta) y `save` mantienen la decodificación completa y rechazan imágenes truncadas. Todos rechazan formatos distintos de PNG, JPEG y GIF.

El selector aplica directamente los colores y el fondo devueltos por `apply --json --no-reload`, sin ejecutar `current` entre medias; después actualiza el vigilante y la lista. La respuesta respeta la prioridad de `SENDA_THEME` y el fallback de `current`. La transición del fondo mantiene sus 800 ms.

Para guardar un tema desde la CLI, `save` recibe **un** objeto JSON por stdin con `name`, `colors`, `wallpaper` (ruta de imagen origen) y, opcionalmente, `original` (nombre de un tema de usuario que se está editando). Copia la imagen al tema y valida antes de sustituir los archivos. Admite `--json` y `--no-reload`.

```sh
cat tema-para-guardar.json | senda theme save --json
```

`SENDA_THEME` en el entorno tiene prioridad sobre el valor del [archivo de configuración](configuration.md). `apply` escribe la selección en ese archivo. Si falta el tema seleccionado o es inválido, `current` vuelve a `zenda-ice` y muestra un aviso; borrar el tema activo también guarda `zenda-ice` como selección.

## Otras aplicaciones

El tema activo también colorea Kitty, GTK, Qt, Hyprland y Neovim mediante archivos generados. Consulta [theme-export.md](theme-export.md).

## Símbolo de la barra

El símbolo de Senda en la barra superior se dibuja con los colores del tema activo: la cara superior usa `secondary`, la diagonal exterior `white`, la inferior `primary` y el pliegue interior una mezcla del 63 % de `accent` sobre `base`. `quickshell/assets/senda-logo.svg` conserva la versión fija de `zenda-ice`.

## Selector y editor

El botón de temas está junto al botón de ajustes del panel del tiempo. El selector muestra una tarjeta por tema, con vista previa, colores y errores de validación. Pulsa una tarjeta válida para aplicarla. **Nuevo tema** abre el editor con un tema válido como base; **Editar** y **Borrar** aparecen solo en temas de usuario. **Duplicar**, disponible en cualquier tema válido y en el lanzador para el tema activo, abre el editor para crear una copia con nombre nuevo; el original queda intacto. El editor permite cambiar nombre y 21 colores, y elegir el wallpaper escribiendo su ruta o con **Elegir…**, que abre un explorador de imágenes PNG, JPEG y GIF dentro del propio popup (empieza en la carpeta de la imagen actual o en Imágenes). Pulsar fuera del popup lo cierra. **Borrar** pide confirmación. Aplicar de nuevo un tema descarta los fondos manuales y restaura el suyo.

El editor comprueba el nombre, los colores y la carga de una imagen PNG, JPEG o GIF antes de habilitar el guardado; la CLI vuelve a validar el contenido. Al editar el tema activo, se recarga la shell. `SendaTheme` vigila el tema activo y aplica los cambios válidos sin reiniciar Quickshell.
