# Puente de voz de Discord

Senda incluye un puente local independiente de DankMaterialShell. El puente Python se comunica con el cliente de Discord mediante su socket IPC; la CLI Go y el widget de la barra hablan con el puente por un socket Unix privado.

## Primer uso

Abre Discord y ejecuta:

```sh
senda discord connect
```

Al iniciar Quickshell, el widget pone en marcha el puente local. El puente conecta automáticamente si Discord ya está abierto, detecta la aparición de su socket IPC si se abre después y vuelve a comprobar la conexión mientras Discord todavía no está listo, aumentando la espera desde 1 segundo hasta un máximo de 30 segundos. Así cubre también el caso en que Discord cree el socket antes de que su endpoint RPC acepte conexiones. Si falta autorización o Discord rechaza el token guardado, aparece un icono de Discord en la barra para volver a autorizar el acceso. Cuando la sesión está autorizada, el widget muestra los avatares del canal y ofrece botones de mute, deafen y salida de la llamada; el botón para salir aparece a la derecha del control de deafen mientras estás en un canal. Si Discord está cerrado, el widget permanece oculto.

El botón de mute se muestra activo mientras estás muteado o ensordecido. Al pulsarlo mientras estás ensordecido, el puente desactiva mute y deafen. Al pulsar solo el botón de deafen para salir del ensordecimiento, conserva el estado previo del micrófono.

Durante un dictado de `senda stt`, Senda silencia el micro si estaba abierto y lo desmutea al terminar solo si fue él quien lo silenció. Ver [stt.md](stt.md).

Al pasar el cursor sobre los avatares se abre una extensión con todos los participantes del canal. Cada fila muestra el avatar a la izquierda, el nombre y el botón de mute local a su derecha, y debajo un control de volumen individual de 0 a 200 %. Al pulsar el avatar de una fila, Discord abre el perfil de esa persona para acceder a su chat. Los iconos junto al nombre indican si la persona tiene el micrófono silenciado o el audio ensordecido, ya sea por sí misma o por el servidor. En el tramo de 0 a 100 %, el slider convierte la escala perceptual visible a la amplitud RPC con una curva de potencia 2,8, y aplica la conversión inversa al mostrar valores recibidos de Discord; de 100 a 200 % conserva una relación lineal. Los cambios se aplican al soltar el control y el indicador sigue el arrastre. Esta extensión comparte el grupo `tray-popups` con Spotify y se cierra medio segundo después de salir de ella y de la sección de avatares.

Al pulsar un avatar pequeño de la barra, Discord abre el canal de voz actual. Al pulsar el avatar de una persona en la extensión, Discord abre su perfil para acceder al chat.

La autorización solicita `rpc`, `rpc.voice.read` y `rpc.voice.write`. El token se guarda en `$XDG_CACHE_HOME/senda/discord/token.json` (o `~/.cache/senda/discord/token.json`) con permisos de archivo `0600` y directorio `0700`. No se imprime en la CLI ni en los logs.

## CLI e integración con scripts

```sh
senda discord status       # JSON con conexión, autorización, canal, mute y deafen
senda discord authorize    # iniciar autorización de Discord
senda discord mute
senda discord unmute
senda discord toggle-mute
senda discord deafen
senda discord undeafen
senda discord toggle-deafen
senda discord leave        # salir del canal de voz actual
senda discord set-user-volume <user-id> <0-200>
senda discord set-user-mute <user-id> <true|false>
senda discord reset-user <user-id>
```

Los comandos de volumen y mute cambian los ajustes locales de un participante del canal actual mediante `SET_USER_VOICE_SETTINGS`. `reset-user` restaura el volumen a 100 y desactiva el mute local si estaba aplicado. Requieren una sesión RPC autorizada y que el usuario siga en el canal.

El proceso del puente se inicia en segundo plano con `connect` o `authorize`; el widget ejecuta `connect` al cargar la barra. `status` no lo inicia. Los comandos responden con código distinto de cero si el puente no está disponible o Discord no está autorizado. La interfaz estable para scripts es la CLI; el socket interno usa JSON Lines en `$XDG_RUNTIME_DIR/senda-discord.sock`, modo `0600`, y no requiere conocer ni manejar el token.

El ejecutable `senda` usa `SENDA_DISCORD_BRIDGE` si está definido, en el entorno o en el archivo de configuración `$XDG_CONFIG_HOME/senda/config` (ver [configuration.md](configuration.md)). Si no, busca `discord-bridge.py` en este orden: el directorio de datos `$XDG_DATA_HOME/senda/scripts/` (o `SENDA_HOME/scripts/` si `SENDA_HOME` está definido), junto al binario, en `../scripts/` respecto al binario, y en el directorio de trabajo (`core/scripts/` o `scripts/`). Para otra instalación, configura `SENDA_DISCORD_BRIDGE` con la ruta absoluta del script. Se requiere Python 3 y no hay dependencias de paquetes externas.

## Limitaciones

Discord debe estar abierto en la misma sesión de usuario y exponer su IPC local. La primera autorización y cualquier nueva autorización tras revocar/expirar el token requieren interacción con Discord. El token se conserva entre reinicios, pero puede caducar o revocarse; en ese caso hay que volver a autorizarlo desde el icono de la barra o con `senda discord authorize`.

Discord restringe el acceso RPC a aplicaciones aprobadas y a sus testers; si la autorización falla por esa restricción, la aplicación debe tener acceso RPC concedido por Discord.
