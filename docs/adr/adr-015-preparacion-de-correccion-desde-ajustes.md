# ADR 015: Preparación de la corrección desde Ajustes

- Estado: aceptada para la implementación; validación visual pendiente.
- Fecha: 2026-10-31

## Contexto

La integración del [ADR 014](adr-014-postprocesamiento-local-conservador.md) requería preparar manualmente llama.cpp y un GGUF. Activar la preferencia sin ellos devolvía el original, lo que podía confundirse con un corrector funcionando. El usuario requiere que todo se prepare desde la interfaz, sin instalar componentes por su cuenta.

## Decisión

Al activar la corrección en Ajustes, Senda prepara un paquete propio con llama.cpp CPU b11979 y Qwen3 1.7B Q4_K_M, para Linux x86-64. Usa descargas con revisión, tamaño y SHA-256 fijados; verifica el ejecutable antes de descargar el modelo, muestra progreso y admite cancelación y reintento. Activa la preferencia tras el éxito. Reutiliza el patrón de staging y renombrado de los modelos y runtime STT, y el proceso de escritura de Ajustes.

El paquete reside en los datos de Senda; la sesión lo utiliza por ruta absoluta. Se reemplaza la preparación manual del ADR 014, manteniendo su ejecución offline, filtro conservador, plazo máximo y respaldo al original. La interfaz no pide rutas y distingue disponibilidad de preferencia activada. La conexión solo se utiliza para descargar los componentes, nunca para procesar texto o audio.

## Consecuencias

No se necesitan comandos, paquetes del sistema ni un servicio adicional para preparar la corrección. Cancelar o fallar conserva cualquier instalación anterior. Desactivar conserva los archivos; la desinstalación normal de Senda los elimina. Otras arquitecturas muestran un mensaje de incompatibilidad. Los artefactos fijados requieren una actualización explícita en el código cuando se cambie de versión. «Preparada» acredita disponibilidad del paquete, no calidad semántica de las propuestas.
