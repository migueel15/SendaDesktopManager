# Aplicaciones de inicio

La sección **Inicio** de Ajustes elige qué se abre al iniciar Hyprland, sin tocar Lua. Los tipos aparecen en este orden: **Aplicación**, **Comando**, **Script** y **Archivo**. Aplicación permite elegir una aplicación instalada; Comando permite escribir la orden completa con argumentos, como `openrgb --startminimized -p purple`; Script ejecuta una ruta y Archivo la abre mediante `xdg-open`. Cada entrada tiene un interruptor y se puede eliminar.

Al elegir una aplicación, el desplegable permite buscar por nombre sin distinguir mayúsculas. Escribe parte del nombre y selecciona una coincidencia con el ratón o con las flechas y Enter; después pulsa **Añadir**. Escape cierra el desplegable y al volver a abrirlo se limpia la búsqueda.

Senda guarda la lista en `SENDA_STARTUP_APPS` y la declara en `hypr/senda/startup.lua`, dentro del evento `hyprland.start`. Los cambios se aplican en el siguiente arranque; recargar Hyprland no ejecuta esas entradas. Senda no modifica las entradas de la configuración del usuario.

Las rutas dentro de la carpeta personal se guardan como `~/` para que la configuración sirva en otro equipo. De una aplicación se guarda su comando, sin más datos de su archivo `.desktop`.

Cada entrada activada espera a que `systemctl --user start senda.service` termine con éxito y comprueba después `systemctl --user is-active --quiet senda.service`. Solo entonces ejecuta el comando completo. Si el servicio falla o no está activo, esa entrada no se ejecuta. Con la unidad `Type=dbus` instalada por Senda, el arranque espera a que esté disponible el vigilante de la bandeja (ADR 0003).

Esta comprobación se añade internamente al módulo generado para aplicaciones, comandos, scripts y archivos; el comando guardado y mostrado en Ajustes se conserva. También protege todos los pasos de comandos compuestos con `;`, `&&` o `||`. Se comprueba el servicio antes del lanzamiento; no se vigila la aplicación después. Las entradas externas de solo lectura mantienen el comportamiento definido en su propia configuración.

Desde la terminal:

```sh
senda startup show
senda startup external --json
senda startup add --kind app --name Firefox firefox
senda startup add --kind command 'openrgb --startminimized -p purple'
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
