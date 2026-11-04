# Foco de ventanas desde Zenda

La CLI puede enfocar la primera ventana cuyo identificador de clase coincida exactamente:

```sh
zenda window focus discord
zenda window focus spotify
```

La comparación no distingue entre mayúsculas y minúsculas, así que `spotify` coincide con una clase `Spotify`. No se comparan títulos, porque suelen cambiar mientras se usa la aplicación. El comando solo enfoca ventanas abiertas; no inicia aplicaciones. Si no hay coincidencia, devuelve un error.

Zenda detecta el compositor de la sesión. Actualmente, el adaptador implementado es Hyprland: consulta los clientes en el orden que entrega `hyprctl -j clients`, toma el primero cuya propiedad `class` coincide y pide enfocar su dirección. En otros compositores el comando indica que todavía no hay un adaptador disponible.

Los widgets llaman a esta CLI en lugar de ejecutar órdenes del compositor directamente. Así se puede añadir soporte para otros compositores dentro de Zenda sin cambiar la interfaz de los widgets.
