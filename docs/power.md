# Energía

La sección **Energía** de Ajustes reúne el aviso de batería baja y el tiempo de inactividad. Sin batería, el aviso no se muestra ni se comprueba.

## Aviso de batería baja

Zenda envía una notificación crítica, mediante `notify-send`, cuando la batería está descargándose y su nivel llega al umbral `ZENDA_BATTERY_WARNING` (de 5 a 95 %; 20 % por defecto). Avisa una sola vez hasta que la carga vuelve a superar el umbral. El umbral se guarda en `~/.config/zenda/config`.

## Tiempo de inactividad

Es el tiempo antes del bloqueo automático; consulta [Bloqueo de pantalla](lock-screen.md).
