# ADR 0007: Comunicación centralizada con Hyprland

## Estado

Aceptada.

## Contexto

Hyprland cambió su configuración a Lua y, con ello, la sintaxis de `hyprctl dispatch` y de los binds. Senda llamaba a `hyprctl` desde muchos paquetes, cada uno con sus propias cadenas, formatos JSON y comprobaciones de respuesta, de modo que un cambio de API obligaba a tocar decenas de sitios.

## Decisión

El paquete `core/internal/hyprland/hyprctl` es el único que se comunica con Hyprland:

- `Client` ejecuta todas las peticiones a `hyprctl` (consultas JSON, dispatchers, `eval`, `repl`, recarga) y comprueba sus respuestas. Acepta un ejecutor inyectable para los tests.
- `lua.go` construye las expresiones Lua de la API de Hyprland (`Dsp*`, `BindLua`, `DefineSubmap`, `OnStart`, `SessionLockConfig`), usadas tanto en tiempo de ejecución como en la configuración generada.
- `events.go` gestiona el socket de eventos.
- `SignatureEnv` nombra la variable de la instancia de Hyprland, e `InSession` / `InSessionEnv` son la única comprobación de sesión; el servicio de usuario y `setup` también los usan.

El resto de paquetes llama a operaciones con nombre (`ActiveWindow`, `SendShortcut`, `FocusWindow`, `SetDeviceEnabled`, `Reload`…). Quickshell y los scripts no invocan `hyprctl`; usan subcomandos de `senda`, como `senda hyprland exit`.

El pegado del dictado usa `SendShortcut` (dispatcher `send_shortcut`) en lugar de `wtype`: el teclado virtual de `wtype` perdía pulsaciones en Firefox y Electron, y `wtype` deja de ser una dependencia.

## Consecuencias

Un cambio en la API de Hyprland se corrige en un único paquete, con sus tests. Las nuevas funciones que actúen sobre el compositor deben añadir una operación a `hyprctl` en lugar de llamar a `hyprctl` directamente.
