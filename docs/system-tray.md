# Bandeja del sistema

Los iconos anclados aparecen a la izquierda del botón que abre la bandeja. Los demás permanecen en el desplegable.

## Anclar y desanclar

- Abre el desplegable y arrastra un icono hasta la zona a la izquierda del botón. Al soltarlo allí, se añade al final de los anclados.
- También puedes abrir Ajustes → Barra y pulsar «Anclar» junto a una aplicación abierta.
- Para desanclar un icono de la barra, haz clic derecho sobre él y elige «Desanclar de la barra».
- En Ajustes → Barra, pulsa «Desanclar» junto a una aplicación abierta.
- Si la aplicación está cerrada, aparece en «Anclados no abiertos ahora». Pulsa «Quitar» para desanclarla.

Los clics izquierdo y central en un icono anclado usan las mismas acciones que en el desplegable. Si todos los iconos abiertos están anclados, el desplegable muestra «Todos los iconos están anclados».

Una aplicación anclada que se cierra no deja un hueco en la barra. Su identificador sigue guardado. Al abrirla de nuevo, el icono vuelve a la zona de anclados.

El anclado se hace por el `id` de StatusNotifierItem. Varias instancias con el mismo `id` se muestran juntas al anclarlas. Su orden relativo no está garantizado.

Pendiente de validación en varios monitores (F6).

## Estado local

La lista se guarda en `$XDG_STATE_HOME/senda/tray-pinned.json`. Si `XDG_STATE_HOME` no está definido o está vacío, la ruta es `~/.local/state/senda/tray-pinned.json`. El archivo JSON tiene este formato:

```json
{
  "version": 1,
  "pinned": ["<id>"]
}
```

Cada entrada de `pinned` es el `id` de StatusNotifierItem de una aplicación. Puedes borrar el archivo y recargar Quickshell para quitar todos los anclados.

## Aplicaciones que arrancan con la sesión

`senda.service` es de tipo `dbus`: `systemctl --user start senda.service` no vuelve hasta que Quickshell posee `org.kde.StatusNotifierWatcher`. Las aplicaciones con icono de bandeja que se lanzan al iniciar sesión (Discord y otras basadas en Electron) registran su icono una única vez; si el vigilante aún no existe, el icono no aparece ni en la bandeja ni en los anclados. Lánzalas después de arrancar la shell. Ejemplo con un auxiliar en Lua para Hyprland:

```lua
local function after_shell(cmd)
	hl.exec_cmd("systemctl --user start senda.service; " .. cmd)
end
after_shell(apps.discord)
```

Se usa `;` y no `&&` para que la aplicación se lance igualmente aunque la shell no arranque. La espera tiene un máximo de 30 segundos.
