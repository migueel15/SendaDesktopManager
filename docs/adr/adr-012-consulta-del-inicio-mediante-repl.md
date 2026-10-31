# ADR 012: Consulta del inicio del usuario mediante REPL

- Estado: aceptada.
- Fecha: 2026-10-31.

## Contexto

Hyprland 0.57 permite definir el inicio con callbacks Lua que contienen variables y funciones auxiliares. No ofrece una consulta pública que enumere sus comandos. El ADR 0008 impide que Senda edite la configuración personal.

## Decisión

La configuración personal puede exponer una tabla global `senda_user_startup`: una lista consecutiva de entradas con `name` y `command` de tipo string. El usuario utiliza esa misma tabla en su callback de arranque. `senda startup external` consulta sus datos mediante `hyprctl repl`, a través del cliente centralizado, y Ajustes los muestra de solo lectura.

## Consecuencias

No se invocan callbacks, no se ejecutan comandos para descubrirlos y no se editan archivos personales desde Senda. Exponer la tabla requiere adaptar manualmente la configuración; no detecta otros programas de inicio. Tabla ausente, tabla vacía y error de consulta son estados distintos. La lista no representa el estado de los procesos. La CLI existente `startup show` y su formato JSON se conservan.
