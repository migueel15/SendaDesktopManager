# Aplicaciones de inicio

La sección **Inicio** de Ajustes elige qué se abre al iniciar Hyprland, sin tocar Lua: aplicaciones instaladas, scripts ejecutables o archivos, que se abren con `xdg-open`. Cada entrada tiene un interruptor y se puede eliminar.

Senda guarda la lista en `SENDA_STARTUP_APPS` y la declara en `hypr/senda/startup.lua`, dentro del evento `hyprland.start`. Los cambios se aplican en el siguiente arranque; recargar Hyprland no ejecuta nada. Lo que el usuario tenga en su propia configuración no se lee ni se modifica.

Las rutas dentro de la carpeta personal se guardan como `~/` para que la configuración sirva en otro equipo. De una aplicación se guarda su comando, sin más datos de su archivo `.desktop`.

Desde la terminal:

```sh
senda startup show
senda startup add --kind app --name Firefox firefox
senda startup add --kind script ~/scripts/inicio.sh
senda startup add --kind file ~/notas.md
senda startup disable firefox
senda startup enable firefox
senda startup remove firefox
```
