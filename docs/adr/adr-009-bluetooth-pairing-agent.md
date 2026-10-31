# ADR 009: Agente de emparejamiento Bluetooth de Senda

- Estado: aceptada
- Fecha: 2026-10-31

## Contexto

Quickshell expone conexión, emparejamiento y estado de los dispositivos, pero su módulo Bluetooth instalado no expone un agente `org.bluez.Agent1`. Sin un agente, las confirmaciones dependen de otra aplicación abierta. El backend Go ya depende de `godbus/dbus/v5`.

## Decisión

Cada intento iniciado desde Senda usa un proceso `senda bluetooth pair`, que registra un agente con capacidad `KeyboardDisplay` y llama a `Pair` desde la misma conexión al bus de sistema. El agente solo admite llamadas del propietario de `org.bluez` y para el dispositivo solicitado. Las preguntas y respuestas se intercambian con QML por JSON en entrada y salida estándar; ninguna confirmación se acepta automáticamente.

## Consecuencias

BlueZ sigue gestionando Bluetooth y no se sustituye el agente predeterminado de otras aplicaciones. El proceso dura como máximo dos minutos, se cancela al perder la entrada y libera su agente al salir. Los PIN no se guardan. El binario y el QML deben distribuirse juntos. La confirmación se presenta como un diálogo de Senda con el estilo del diálogo de pantallas; los flujos reales requieren validación con hardware.
