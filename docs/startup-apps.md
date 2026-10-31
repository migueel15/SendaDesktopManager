# Aplicaciones de inicio

La sección **Inicio** de Ajustes elige qué se abre al iniciar Hyprland, sin tocar Lua: aplicaciones instaladas, scripts ejecutables o archivos, que se abren con `xdg-open`. Cada entrada tiene un interruptor y se puede eliminar.

Senda guarda la lista en `SENDA_STARTUP_APPS` y la declara en `hypr/senda/startup.lua`, dentro del evento `hyprland.start`. Los cambios se aplican en el siguiente arranque; recargar Hyprland no ejecuta esas entradas. Senda no modifica las entradas de la configuración del usuario.

Las rutas dentro de la carpeta personal se guardan como `~/` para que la configuración sirva en otro equipo. De una aplicación se guarda su comando, sin más datos de su archivo `.desktop`.

Desde la terminal:

```sh
senda startup show
senda startup external --json
senda startup add --kind app --name Firefox firefox
senda startup add --kind script ~/scripts/inicio.sh
senda startup add --kind file ~/notas.md
senda startup disable firefox
senda startup enable firefox
senda startup remove firefox
```

## Inicio definido en Hyprland

Debajo de las entradas gestionadas por Senda, Ajustes muestra **Configuradas en Hyprland · Solo lectura**. Consulta la tabla global `senda_user_startup` de la sesión con `hyprctl repl`; no ejecuta los callbacks de inicio ni analiza archivos. Sin tabla, muestra que la configuración no expone su lista; si no puede consultar la sesión, muestra un error, sin afectar a las entradas gestionadas por Senda.

Para exponer las entradas, la configuración personal debe declarar una lista con `name` y `command` y usarla también para arrancar los programas. Por ejemplo, dentro de un módulo cargado por `hyprland.lua`:

```lua
senda_user_startup = {
    { name = "Firefox", command = "firefox" },
    { name = "Red", command = "nm-applet" },
}

hl.on("hyprland.start", function()
    for _, entry in ipairs(senda_user_startup) do
        hl.exec_cmd(entry.command)
    end
end)
```

Al adaptar la configuración, sustituye las llamadas de inicio equivalentes para no duplicarlas. Esta adaptación es manual: Senda solo consulta la tabla y no modifica tus archivos. La lista muestra lo declarado, no comprueba si el proceso está ejecutándose. Los programas definidos fuera de esta tabla no se descubren automáticamente. La consulta se actualiza al abrir Ajustes.
