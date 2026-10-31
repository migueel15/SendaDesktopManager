# Pantallas

La sección **Pantallas** de Ajustes coloca los monitores y cambia su resolución, frecuencia, escala y rotación, además de encenderlos, apagarlos y duplicarlos. Los cambios confirmados persisten tras reiniciar y recargar: Senda los guarda en `SENDA_DISPLAYS`, los genera en su módulo de Hyprland y solo actualiza en la sesión las pantallas que cambian, sin recargar.

- Arrastra una pantalla y al soltarla se pega al lado de otra, sin solaparse.
- Los cambios se acumulan sin tocar las pantallas. Abajo aparece un aviso con **Aplicar cambios** y **Cancelar**.
- Al aplicar, una ventana a pantalla completa en cada pantalla ofrece **Mantener** y **Revertir** con 15 segundos de cuenta atrás. Si no respondes, se vuelve al estado anterior, aunque la shell falle. Nada se guarda hasta pulsar **Mantener**.
- La escala ofrece 100, 125, 150, 167, 175 y 200 %. Con `senda display set PANTALLA --scale` puedes usar otra, de 0.25 a 10, y la página la mostrará también.
- Al aplicar, la colocación se desplaza para empezar en `0x0`, salvo que alguna pantalla la gestione tu configuración.
- Las pantallas apagadas o que duplican a otra no aparecen en la colocación.

## Comandos

| Comando | Uso |
|---|---|
| `senda display show [--json]` | Muestra las pantallas y quién las gestiona. |
| `senda display set PANTALLA --mode 1920x1080@60` | Resolución y frecuencia. |
| `senda display set PANTALLA --position 1920x0` | Posición. |
| `senda display set PANTALLA --scale 1.5` | Escala. |
| `senda display set PANTALLA --transform 1` | Rotación: `0` normal, `1` 90°, `2` 180°, `3` 270°. |
| `senda display set PANTALLA --mirror DP-1` | Duplica otra pantalla; `--mirror none` deja de hacerlo. |
| `senda display set PANTALLA --enabled=false` | Apaga la pantalla. |
| `senda display reset PANTALLA` | Quita los ajustes de Senda de esa pantalla. |
| `senda display apply --changes JSON --confirm 15` | Prueba varios cambios y los revierte si no se confirman. |
| `senda display confirm` / `cancel` | Mantiene o revierte los cambios en prueba. |
| `senda display adopt` | Guarda el estado actual de todas las pantallas, para retirar después tus definiciones sin que cambie nada. |
| `senda display undo` | Deshace el último cambio. |
| `senda display sync` | Regenera el módulo si tu configuración de monitores ha cambiado. La shell lo hace sola. |

## Pantallas definidas por ti

Si tu configuración de Hyprland define un monitor con `hl.monitor` o `monitor =`, tu definición gana: Senda no genera nada para él, rechaza cambiarlo y lo muestra como gestionado por tu configuración, con el archivo y la línea. Si no defines ninguno, esa sección no aparece.

Una regla general (`output = ""`) no cuenta como definición: Senda puede configurar cada pantalla por encima de ella. Un `output` calculado por código podría ser cualquier pantalla, así que todas pasan a estar gestionadas por ti. Solo se leen los archivos que Hyprland carga mediante rutas literales. Ver [ADR 0008](adr/0008-configuracion-del-usuario-gana.md).

## Pasar el control a Senda

1. Ejecuta `senda display adopt` con tus monitores definidos.
2. Retira sus `hl.monitor` de tu configuración y recarga Hyprland.

Un plugin que llame a `hl.monitor` en tiempo de ejecución debe llevar `-- senda: runtime` en la línea anterior y volver a aplicar sus cambios en el evento `config.reloaded`.
