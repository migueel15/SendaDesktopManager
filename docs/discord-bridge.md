# Puente de voz de Discord

Senda incluye un puente local independiente de DankMaterialShell. El puente Python se comunica con el cliente de Discord mediante su socket IPC; la CLI Go y el widget de la barra hablan con el puente por un socket Unix privado.

## Primer uso

Abre Discord y ejecuta:

```sh
senda discord connect
```

Al iniciar Quickshell, el widget pone en marcha el puente local. El puente detecta la aparición del socket IPC de Discord y conecta automáticamente, incluso si Discord se abre después. Si falta autorización o Discord rechaza el token guardado, aparece un icono de Discord en la barra para volver a autorizar el acceso. Cuando la sesión está autorizada, el widget muestra los avatares del canal y ofrece botones de mute y deafen; si Discord está cerrado, permanece oculto.

La autorización solicita `rpc.voice.read` y `rpc.voice.write`. El token se guarda en `$XDG_CACHE_HOME/senda/discord/token.json` (o `~/.cache/senda/discord/token.json`) con permisos de archivo `0600` y directorio `0700`. No se imprime en la CLI ni en los logs.

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
```

El proceso del puente se inicia en segundo plano con `connect` o `authorize`; el widget ejecuta `connect` al cargar la barra. `status` no lo inicia. Los comandos responden con código distinto de cero si el puente no está disponible o Discord no está autorizado. La interfaz estable para scripts es la CLI; el socket interno usa JSON Lines en `$XDG_RUNTIME_DIR/senda-discord.sock`, modo `0600`, y no requiere conocer ni manejar el token.

El ejecutable `senda` localiza `core/scripts/discord-bridge.py` junto al checkout o desde el directorio de trabajo. Para otra instalación, configura `SENDA_DISCORD_BRIDGE` con la ruta absoluta del script. Se requiere Python 3 y no hay dependencias de paquetes externas.

## Limitaciones

Discord debe estar abierto en la misma sesión de usuario y exponer su IPC local. La primera autorización y cualquier nueva autorización tras revocar/expirar el token requieren interacción con Discord. El token se conserva entre reinicios, pero puede caducar o revocarse; en ese caso hay que volver a autorizarlo desde el icono de la barra o con `senda discord authorize`.
