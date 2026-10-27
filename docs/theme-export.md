# Exportación del tema a otras aplicaciones

El tema activo de Senda es la fuente de colores del resto del escritorio. Cada vez que cambia, Senda genera archivos de configuración para otras aplicaciones a partir de plantillas, y pide a las que están abiertas que los recarguen.

## Cuándo se exporta

- `senda theme apply`, incluido el selector de temas.
- `senda theme save` cuando se guarda el tema activo, incluido el editor.
- `senda theme delete` cuando se borra el tema activo (se exporta `zenda-ice`).
- A mano, con `senda theme export`.

La exportación usa el tema efectivo, igual que `senda theme current`: respeta `SENDA_THEME` del entorno y el fallback. Si falla, el cambio de tema se mantiene y el aviso aparece en stderr. `--no-reload` en `apply`, `save` y `delete` solo afecta a la shell; las aplicaciones se recargan igualmente.

```sh
senda theme export              # escribe los archivos y recarga las aplicaciones
senda theme export --json       # {"theme": "...", "files": [...]}
senda theme export --no-reload  # solo escribe los archivos
```

Los cambios hechos a mano en `theme.json` se aplican en vivo a la shell, pero no se exportan hasta ejecutar `senda theme export`.

## Archivos generados

Se escriben en `$XDG_CONFIG_HOME/senda/generated/` (por defecto `~/.config/senda/generated/`). Cada archivo se reemplaza de forma atómica. Senda no edita la configuración de ninguna aplicación: hay que enlazar cada archivo una vez.

| Aplicación | Archivo | Cómo enlazarlo | Recarga |
|---|---|---|---|
| Kitty | `kitty/senda.conf` | `include ~/.config/senda/generated/kitty/senda.conf` al final de `kitty.conf` | Automática (`SIGUSR1`) |
| Hyprland | `hyprland/colors.conf` | `source = ~/.config/senda/generated/hyprland/colors.conf` al final de `hyprland.conf` | Automática (`hyprctl reload`) |
| GTK 4 / libadwaita | `gtk-4.0/gtk.css` | `@import url("file:///home/USUARIO/.config/senda/generated/gtk-4.0/gtk.css");` al principio de `~/.config/gtk-4.0/gtk.css` | Al abrir de nuevo la aplicación |
| GTK 3 | `gtk-3.0/gtk.css` | Igual, en `~/.config/gtk-3.0/gtk.css`. Funciona mejor con el tema `adw-gtk3-dark` | Al abrir de nuevo la aplicación |
| Qt (qt5ct / qt6ct) | `qt/senda.conf` | En `[Appearance]` de `qt6ct.conf`: `custom_palette=true` y `color_scheme_path=` con la ruta absoluta del archivo | Al abrir de nuevo la aplicación |
| KDE (Dolphin…) | `kde/senda.colors` | Enlace en `~/.local/share/color-schemes/Senda.colors` y esquema **Senda** (ver Qt) | Al abrir de nuevo la aplicación |
| Neovim | `nvim/colors/senda.lua` y `nvim/lua/lualine/themes/senda.lua` | Ver más abajo | Automática en las instancias que usan `senda` |
| T3 Code | `t3code/senda.json` | Ver más abajo | Automática en clientes compatibles que usen el tema publicado |

Hyprland define además una variable `$senda_<color>` por cada color del tema, que puedes usar en tu propia configuración, y ajusta los bordes de ventanas y grupos.

### T3 Code

T3 Code vigila su directorio de temas. Para que detecte cada actualización atómica, enlaza el directorio de salida de Senda al directorio de temas de T3 Code antes de exportar. Si `generated/t3code` ya existe como directorio, revisa su contenido y muévelo antes de crear el enlace; no lo sobrescribas.

```sh
mkdir -p ~/.t3/userdata/themes ~/.config/senda/generated
ln -s ~/.t3/userdata/themes ~/.config/senda/generated/t3code
senda theme export --no-reload
t3 theme set senda
```

Si usas `XDG_CONFIG_HOME` o un directorio de estado personalizado de T3 Code, sustituye las rutas por las correspondientes. `t3 theme show` muestra el directorio de publicación. El tema publicado se actualiza al exportar; los clientes compatibles que lo tengan seleccionado reciben los colores sin reiniciar. La aplicación móvil, `app.t3.codes` y las conexiones adicionales no siguen los temas del entorno. Un tema personalizado guardado con el mismo ID tiene prioridad.

### GTK

GTK no se colorea solo con el `@import` si hay otro tema que fija sus propios colores. Para que Senda controle GTK:

1. Instala el tema base `adw-gtk3`, que usa los colores con nombre de libadwaita: `sudo pacman -S adw-gtk-theme`.
2. Elige `adw-gtk3-dark` para GTK 3:
   ```sh
   gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
   gsettings set org.gnome.desktop.interface color-scheme prefer-dark
   ```
   y pon `gtk-theme-name=adw-gtk3-dark` en `~/.config/gtk-3.0/settings.ini`.
3. En `~/.config/gtk-4.0/`, deja `gtk.css` solo con el `@import` de Senda, borra los enlaces `assets` y `gtk-dark.css` que dejan temas como Catppuccin y quita `gtk-theme-name` de `settings.ini`. GTK 4 carga esos archivos por encima de libadwaita.
4. En `~/.config/gtk-3.0/`, deja `gtk.css` solo con el `@import` de Senda. Herramientas como Matugen suelen convertirlo en un enlace a su propio archivo.

Haz una copia de ambas carpetas antes de cambiarlas. Las aplicaciones GTK abiertas no se recargan: hay que cerrarlas y abrirlas de nuevo (por ejemplo, `nautilus -q`).

### Qt

Senda solo colorea las aplicaciones Qt a través de qt5ct y qt6ct:

1. `QT_QPA_PLATFORMTHEME=qt5ct:qt6ct` en el entorno de la sesión. En Hyprland, por ejemplo, con `env` o `hl.env`.
2. En `qt5ct.conf` y en `qt6ct.conf`, sección `[Appearance]`: `custom_palette=true`, `color_scheme_path` con la ruta absoluta de `qt/senda.conf` y un estilo que respete la paleta, como `style=Fusion`.

Las aplicaciones de KDE, como Dolphin, no usan la paleta de qt6ct: aplican un esquema de color de KDE y, si no tienen ninguno, usan Breeze claro. Senda genera también `kde/senda.colors`:

```sh
mkdir -p ~/.local/share/color-schemes
ln -sf ~/.config/senda/generated/kde/senda.colors ~/.local/share/color-schemes/Senda.colors
```

Después elige **Senda** en *Preferencias → Esquema de color* de la aplicación, o escribe `ColorScheme=Senda` en la sección `[UiSettings]` de su archivo (por ejemplo, `~/.config/dolphinrc`). Como el enlace apunta al archivo generado, el esquema sigue al tema activo.

Las aplicaciones Qt y KDE abiertas no se recargan: hay que cerrarlas y abrirlas de nuevo.

### Programas de terminal

Kitty solo traduce los 16 colores ANSI. Un programa que pide un color en hexadecimal lo recibe tal cual y no cambia con el tema. Para que un programa siga al tema, configúralo con nombres o números ANSI (`green`, `yellow`, `8`…) en lugar de `#RRGGBB`. Por ejemplo, en zsh-syntax-highlighting:

```zsh
ZSH_HIGHLIGHT_STYLES[command]='fg=green'
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
```

Así el cambio se ve al momento, también en las terminales abiertas.

### Neovim

```lua
vim.opt.rtp:append(vim.fn.expand("~/.config/senda/generated/nvim"))
vim.cmd.colorscheme("senda")
require("lualine").setup({ options = { theme = "senda" } })
```

El esquema cubre la interfaz del editor, la sintaxis clásica, Tree-sitter, los tokens semánticos de LSP, los diagnósticos, diff, y los plugins más comunes: gitsigns, diffview, neogit, fugitive, telescope, fzf-lua, nvim-cmp, blink.cmp, neo-tree, nvim-tree, oil, mini (files, statusline, pick, diff, indentscope, hipatterns), bufferline, lualine, indent-blankline, which-key, nvim-notify, noice, fidget, flash, leap, hop, todo-comments, trouble, lazy, mason, snacks, dashboard, alpha, render-markdown y nvim-dap / dap-ui. También define los 16 colores de `:terminal`.

Opciones, antes de `colorscheme`:

```lua
vim.g.senda_transparent = true          -- fondo transparente
vim.g.senda_italic_comments = false     -- comentarios sin cursiva
vim.g.senda_no_italic = true            -- sin cursiva en ningún grupo
vim.g.senda_overrides = function(C)     -- C es la paleta con nombres de Catppuccin
  return { CursorLine = { bg = C.surface0 } }
end
```

Tras cargar el esquema, `vim.g.senda_palette` contiene la paleta.

El esquema reparte los colores igual que [catppuccin/nvim](https://github.com/catppuccin/nvim), pero cada nombre de color de Catppuccin usa la variable de Senda que cumple ese papel. Así un elemento del código usa siempre la misma variable y solo cambia su valor entre temas:

| Catppuccin | Uso principal | Variable de Senda |
|---|---|---|
| `red` | errores, `self`/`this` | `error` |
| `maroon` | parámetros | `error` con un 20 % de `text` |
| `peach` | números, constantes, funciones integradas | `orange` (mezcla de `error` y `warning`) |
| `yellow` | tipos, clases | `warning` |
| `green` | cadenas | `success` |
| `teal` | caracteres, miembros de enum | mezcla de `success` e `info` |
| `sky` | operadores | `cyan` de la terminal |
| `sapphire` | etiquetas | `info` |
| `blue` | funciones, directorios, títulos | `primary` |
| `lavender` | propiedades, campos | `secondary` |
| `mauve` | palabras clave | `accent` aclarado un 30 % |
| `pink` | macros, regex | `accent` aclarado un 55 % |
| `flamingo` / `rosewater` | identificadores / cursor | `textMuted` / `white` |

Los neutros (`base`, `mantle`, `crust`, `surface0-2`, `overlay0-2`, `subtext0-1`, `text`) salen de las superficies y textos del tema. Las plantillas propias pueden usarlos como `{{.K.blue}}`, `{{.K.mantle}}`… Al cambiar de tema, Senda busca los sockets `$XDG_RUNTIME_DIR/nvim.*` y vuelve a cargar `senda` solo en las instancias que lo usan.

## Fondos de las aplicaciones

La barra, el marco y los paneles de Senda usan `background`. Para que una ventana se distinga de un panel abierto encima, las plantillas usan `surface`, más claro en los temas integrados, como fondo principal de Kitty, Neovim, GTK, Qt y KDE. Las zonas secundarias (barras laterales de GTK, vistas de Qt y KDE, `mantle` en Neovim) usan una mezcla aún más oscura de `surface` y `base`.

## Colores de terminal

Los 16 colores ANSI se derivan de la paleta del tema:

| Color | Origen |
|---|---|
| negro / negro brillante | `surfaceVariant` / `overlay` |
| rojo, verde, amarillo | `error`, `success`, `warning` |
| azul, magenta, cian | El color de `info`, `primary`, `secondary`, `focus` o `accent` con el tono más cercano (a menos de 36°, saturado y de luminosidad media). Si ninguno encaja, se sintetiza con la saturación y luminosidad de `primary` |
| blanco / blanco brillante | `textMuted` / `white` |
| versiones brillantes | El color normal aclarado un 18 % |

Las plantillas también reciben `orange`, una mezcla de `error` y `warning`.

## Plantillas propias

Puedes añadir o sustituir plantillas en `$XDG_CONFIG_HOME/senda/templates/`. Cada archivo se renderiza en la misma ruta relativa dentro de `generated/`. Si coincide con una plantilla integrada (por ejemplo `kitty/senda.conf`), la sustituye. Una plantilla con errores cancela la exportación y no escribe ningún archivo.

Las plantillas usan `text/template` de Go:

| Expresión | Valor |
|---|---|
| `{{.Name}}` | Nombre del tema |
| `{{.C.primary}}` | Cualquiera de los 21 colores del tema, en `#RRGGBB` |
| `{{.T.red}}`, `{{.T.brightBlue}}`, `{{.T.orange}}` | Colores derivados |
| `{{.K.mauve}}`, `{{.K.surface0}}` | La paleta con nombres de Catppuccin (ver Neovim) |
| `{{range $i, $c := .ANSI}}color{{$i}} {{$c}}{{end}}` | Los 16 colores ANSI en orden |
| `{{if .Dark}}…{{end}}` | Si el fondo es oscuro |
| `{{mix .C.error .C.background 0.8}}` | Mezcla: 0 devuelve el primero, 1 el segundo |
| `{{lighten .C.primary 0.2}}`, `{{darken .C.primary 0.2}}` | Mezcla con blanco o negro |
| `{{bare .C.primary}}` | Sin `#` |
| `{{rgba .C.base 0.5}}` | `rgba(r, g, b, 0.5)` |
| `{{contrast .C.primary .C.base .C.white}}` | El segundo argumento si el primero es claro; si no, el tercero |

Ejemplo para rofi en `~/.config/senda/templates/rofi/colors.rasi`:

```
* { bg: {{.C.background}}; fg: {{.C.text}}; accent: {{.C.primary}}; }
```
