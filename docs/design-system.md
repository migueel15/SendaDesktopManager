# Sistema de diseño

Guía visual común a la barra, los paneles y los pop-ups de Senda. Los componentes toman sus tokens de `quickshell/common/Theme.qml`. Los colores se cargan desde el [tema activo](themes.md); los valores de las tablas corresponden a `zenda-ice`. Las escalas de tamaño y movimiento permanecen en `Theme.qml`.

## Principios

- **Sobrio y frío.** Fondos oscuros neutros; el color se reserva para lo activo, lo seleccionado y los estados.
- **Un solo acento.** Hielo (`primary`) marca interacción y selección. Los colores de estado solo comunican éxito, aviso, error o información.
- **Capas planas.** La profundidad se marca con un cambio de tono y un borde de 1 px, no con sombras.
- **Escalas cerradas.** Espaciados, radios, tamaños de texto y duraciones salen de las escalas de abajo.

## Color

### Neutros

| Token | Valor | Uso |
|---|---|---|
| `base` | `#0A0E16` Noche | Fondo del escritorio y zonas más profundas |
| `background` | `#141A26` Grafito | Barras y cuerpo de los paneles |
| `surface` | `#11161F` | Tarjetas dentro de los paneles |
| `border` | `#222B3A` | Borde de tarjetas y separadores |
| `surfaceVariant` | `#263042` Pizarra | Relleno al pasar el ratón y bordes de controles inactivos |
| `surfaceRaised` | `#1A2130` | Desplegables que salen de una tarjeta |
| `surfaceRaisedBorder` | `#3E4A60` | Borde de esos desplegables |
| `overlay` | `#8695AD` Humo | Texto secundario e iconos inactivos |
| `textMuted` | `#C6CFDD` | Texto atenuado sobre fondos claros de acento |
| `text` | `#E8EEF7` Bruma | Texto principal |
| `white` | `#F2F7FF` Nieve | Texto o icono sobre la selección más fuerte |

### Acento

| Token | Valor | Uso |
|---|---|---|
| `primary` | `#7AA7FF` Hielo | Acción principal, foco, elemento activo |
| `secondary` | `#CFE3FF` Escarcha | Detalles de acento suaves: fechas destacadas, valores |
| `accent` | `#3D6FD1` Cobalto | Rellenos de acento más intensos, progreso |
| `selection` | `#1F3A66` | Fondo de un elemento seleccionado o activado |
| `accentDeep` | `#0F1E38` | Fondo de un modo activo de baja intensidad (p. ej. No molestar) |
| `focus` | `#7AA7FF` | Borde de un control con foco de teclado |

### Estados

| Token | Valor |
|---|---|
| `success` | `#6FD3A0` |
| `warning` | `#F2C46D` |
| `error` | `#F27A8A` |
| `info` | `#A79CFF` |

## Tipografía

Texto en **Inter**; iconos en **Symbols Nerd Font**. Los glifos de iconos dentro de un texto en Inter se resuelven solos con la fuente de símbolos.

| Token | Tamaño | Peso | Uso |
|---|---|---|---|
| `font.display` | 36 | Light | Números grandes, como el reloj del dashboard |
| `font.title` | 16 | DemiBold | Título de un panel |
| `font.heading` | 14 | DemiBold | Título de tarjeta o sección |
| `font.body` | 13 | Normal | Texto por defecto dentro de los paneles |
| `font.caption` | 11 | Normal | Horas, contadores y pistas, en `overlay` |
| `font.label` | 10 | DemiBold, mayúsculas | Etiquetas sobre grupos |
| `font.base` | 17 | Normal | Barra superior |
| `font.icon` | 13 | — | Iconos sueltos |

Todos los tamaños se multiplican por la escala de texto de los ajustes. `font.overlay` se mantiene como alias histórico de `body`.

## Espaciado

Escala `Theme.spacing`: `xxs` 2 · `xs` 4 · `sm` 8 · `md` 12 · `lg` 16 · `xl` 24.

- Relleno interior de un panel: `lg`.
- Relleno interior de una tarjeta: `md`.
- Separación entre tarjetas: `sm`.
- Separación entre icono y texto: `sm`; entre líneas de una fila: `xxs` o `xs`.

## Forma

Escala `Theme.rounding`: `small` 6 · `normal` 10 · `large` 16 · `full`.

- Filas de lista, chips y elementos de menú: `small`.
- Tarjetas, botones y campos: `normal`.
- Contenedores grandes: `large`.
- Píldoras, interruptores e indicadores circulares: `full`.

Bordes siempre de 1 px.

## Superficies

- **Panel:** fondo `background`, sin borde propio; se despliega desde la barra.
- **Extensión de barra:** comparte el fondo de la barra y añade una sombra suave que sigue su contorno al desplegarse.
- **Marco del escritorio:** una sombra interior sigue la barra, los bordes y las esquinas curvas de cada monitor.
- **Tarjeta:** fondo `surface`, borde `border`, radio `normal`, relleno `md`.
- **Desplegable o menú:** fondo `background` o `surfaceRaised`, borde `border` o `surfaceRaisedBorder`, radio `normal`, relleno `xs` con filas de radio `small`.

## Estados de interacción

| Estado | Tratamiento |
|---|---|
| Reposo | Fondo transparente o `surface`; texto `text`, icono `overlay` |
| Hover | Fondo `surfaceVariant` |
| Seleccionado o activo | Fondo `selection`, borde `primary`, texto o icono `primary` |
| Foco de teclado | Borde `focus` |
| Desactivado | Texto `overlay`, sin hover |
| Peligro | Al pasar el ratón, fondo o icono `error` |

## Botones

- **Principal:** fondo `primary`, texto `base`; hover con `secondary`.
- **Secundario:** fondo `surface`, borde `surfaceVariant`, texto `text`; hover con fondo `surfaceVariant`.
- **Fantasma:** sin fondo ni borde; hover con fondo `surfaceVariant`.
- **Icono:** botón fantasma cuadrado con radio `small`.

## Movimiento

Escala `Theme.motion`: `fast` 120 ms para hover y cambios de color · `normal` 180 ms para desplazamientos y fundidos pequeños · `slow` 310 ms para paneles que se despliegan. Curva `OutCubic`.

## Componentes de Ajustes

Las seis páginas mantienen su navegación lateral con icono Nerd Font y texto. La selección usa `selection`, texto `white` e icono `primary`. El contenido conserva el título de sección y se desplaza independientemente del pie de estado.

Encima de las secciones hay un buscador. Encuentra secciones y filas `SettingsRow` por etiqueta o descripción, sin distinguir tildes, leyendo las páginas reales; las filas generadas desde datos usan `searchable: false`. Elegir un resultado abre su sección, desplaza hasta la fila y la resalta.

Los componentes locales se registran en `Settings/qmldir`; sus archivos usan nombres en minúsculas:

| Componente | Uso |
|---|---|
| `SettingsGroup` | Tarjeta `surface`, borde `border` de 1 px, radio `normal` y relleno `md`. |
| `SettingsRow` | Etiqueta `body`, descripción opcional `caption` en `overlay`, controles a la derecha y separador de 1 px. La primera fila omite el separador. |
| `SettingsSwitch` | Píldora binaria: `primary` activo, `surfaceVariant` inactivo, foco `focus`. Conserva el valor confirmado por el servicio. |
| `SettingsSegments` | Opciones exclusivas sobre `base`; la selección se guarda al pulsar. |
| `SettingsSlider` | Deslizador con porcentaje visible; guarda al soltar o al finalizar una pulsación de teclado. Escala de texto 80–150 %, paso 10. |
| `SettingsStatus` | Pie reservado de dos líneas: éxito breve (3,5 s), error persistente hasta la siguiente operación. No desplaza el contenido. |

Los campos de texto confirman con Enter o al perder el foco solo si se han editado. Las credenciales de Google se confirman juntas desde el segundo campo o mediante su acción específica. Las acciones de búsqueda, instalación, comprobación y actualización siguen siendo botones.

`SettingsRow` admite `modified` y `resetRequested`: muestra un icono para restablecer el ajuste solo cuando su valor difiere del valor por defecto.
`SettingsSelect` es el desplegable reutilizable para listas largas: recibe `options` y `value`, y emite `chosen(value)`. Su lista es una ventana propia, así que puede salir de la ventana de Ajustes; tiene altura máxima (`maxListHeight`) y barra de desplazamiento si no cabe.
