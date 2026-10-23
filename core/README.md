# Senda

Senda is a simple and modular desktop manager for Linux Wayland.

The project is currently in an early stage. Quickshell renders wallpapers for each screen.

## Features

- Set wallpapers from the command line
- Support for wallpaper transitions
- Initial support for transition position
- Modular backend-based architecture
- Current wallpaper backend: Quickshell

## Requirements

- Linux
- Wayland
- Quickshell

The wallpaper backend sends requests to Quickshell. See [wallpaper](../docs/wallpaper.md) and [themes](../docs/themes.md) for the supported commands and settings.

## Instalación

- [Instalación](../docs/installation.md): instalador, `senda update` y estado de `senda setup`.
- [Configuración](../docs/configuration.md): archivo `KEY=VALUE`, ubicación y claves que se leen.
