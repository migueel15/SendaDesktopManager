# ADR 0006: Bloqueo de pantalla y teclado en Senda

## Estado

Aceptada.

## Contexto

El bloqueo de teclado externo impedía introducir la contraseña al bloquear la sesión. Senda necesita coordinar ambas acciones y recuperar una pantalla bloqueada si su proceso termina.

## Decisión

Quickshell gestiona el bloqueo de sesión con el protocolo Wayland y autentica mediante PAM. Senda reactiva los teclados antes de bloquear y rechaza desactivarlos durante el bloqueo. La CLI detecta teclados físicos por udev y sysfs, los cruza con Hyprland y conserva el estado volátil; una recarga de Hyprland restablece ese estado. El compositor debe permitir restaurar el bloqueo y Senda conserva un marcador para volver a solicitarlo.

Se descarta EVIOCGRAB porque requiere acceso al grupo input. Una capa Quickshell con foco exclusivo tampoco es suficiente porque no bloquea los atajos de Hyprland.

## Integración de setup

`setup` ofrece instalar hypridle y crea, si no existen, archivos propios para Hyprland y hypridle. El usuario carga el módulo y decide cómo integrar la configuración de inactividad; Senda no modifica los archivos existentes ni inicia una segunda instancia de hypridle. El ejemplo espera la confirmación del bloqueo antes de suspender. Esta creación de un módulo propio sigue la excepción del ADR 0004, sin modificar `hyprland.lua`.

## Consecuencias

El estado refleja las operaciones de Senda, no cambios externos que Hyprland no permite consultar. La recuperación depende de la restauración del compositor y de volver a ejecutar Senda; debe comprobarse en la sesión concreta antes de sustituir el bloqueador anterior.

## Enmienda: configuración común y gestión de hypridle

El módulo único `senda.lua` reúne los ajustes de bloqueo y dictado; el archivo de hypridle queda en el directorio privado de configuración de Senda. `senda hyprland set` genera ambos y comprueba los conflictos. Una instancia de hypridle independiente se conserva y requiere integración manual; solo se reinicia una instancia iniciada y registrada por Senda. Una referencia antigua inequívoca puede reemplazarse por una referencia marcada, que se retira al desinstalar.

## Enmienda: vinculación automática y elección de hypridle

Para simplificar la instalación, `setup` y `senda hyprland set` detectan si el módulo está cargado preguntando a Hyprland por la función global `senda_module_version`, independientemente de la organización de la configuración del usuario. Si no está cargado, añaden la referencia marcada al final de `hyprland.lua`; esto sustituye la regla anterior de no modificar `hyprland.lua` y la excepción del ADR 0004. Si el usuario no tiene configuración de hypridle, Senda usa la suya y la arranca desde el módulo. Si la tiene, `setup` pregunta una vez y guarda la elección en `SENDA_IDLE_MODE`; elegir la de Senda detiene el hypridle del usuario, sin modificar su archivo.
