# Bluetooth

El desplegable de Bluetooth del centro de control muestra dispositivos con nombre. Las entradas cuyo único nombre es una dirección MAC se ocultan. Los dispositivos todavía no vinculados aparecen como **Sin emparejar**.

Al abrir el desplegable comienza la búsqueda; termina al cerrar la lista o el centro de control. No hace falta abrir Blueman para iniciar la búsqueda desde Senda.

## Emparejamiento desde Senda

Al pulsar un dispositivo sin emparejar, el backend inicia el emparejamiento y comunica las solicitudes de BlueZ a un diálogo con el estilo de la confirmación de pantallas:

- Confirmación de un código de seis dígitos: hay que compararlo con el del dispositivo y pulsar **Confirmar**.
- Solicitud de PIN o clave numérica: se introduce en el diálogo.
- Código para un teclado: se muestra para introducirlo y confirmarlo en el dispositivo.
- Autorización de emparejamiento o de un servicio: requiere confirmación explícita.

**Cancelar**, el cierre del proceso o dos minutos sin terminar abortan el intento. Los fallos aparecen en el desplegable. Tras emparejar, Senda solicita la conexión; los dispositivos ya vinculados siguen usando la conexión directa de Quickshell.

BlueZ sigue siendo necesario como servicio del sistema. Senda registra un agente únicamente para los emparejamientos que inicia, sin sustituir al agente predeterminado de Blueman ni gestionar solicitudes entrantes ajenas. No guarda los PIN.

## Contrato interno

`senda bluetooth pair /org/bluez/hciN/dev_XX_XX_XX_XX_XX_XX` registra el agente y ejecuta `Pair` en la misma conexión D-Bus. La salida contiene eventos JSON por línea con `kind`, `id` y, si procede, `code`; la entrada recibe `{ "id": 1, "accept": true, "value": "123456" }` o `{ "cancel": true }`. `paired` cierra el diálogo antes de conectar. Véase el [ADR 009](adr/adr-009-bluetooth-pairing-agent.md).

## Validación en sesión

Con el binario y QML de la misma versión, cerrar Blueman y abrir la lista de Bluetooth. Desde un dispositivo sin emparejar, comprobar la aparición del diálogo, la coincidencia del PIN y la conexión después de confirmar. Repetir rechazando y dejando vencer el intento; comprobar que no se acepta el emparejamiento. Para teclados, verificar también la introducción del código en el dispositivo. Estas comprobaciones requieren hardware y no quedan acreditadas por compilar el backend.
