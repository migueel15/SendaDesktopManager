# Senda

Senda is a simple and modular desktop manager for Linux Wayland.

The project is currently in an early stage. For now, it includes basic wallpaper management using `awww`.

## Features

- Set wallpapers from the command line
- Support for wallpaper transitions
- Initial support for transition position
- Modular backend-based architecture
- Current wallpaper backend: `awww`

## Requirements

- Linux
- Wayland
- `awww`, available in `PATH`

The wallpaper backend is `awww` (see `core/internal/wallpaper/adapter/awww/awww.go`). Senda runs `awww img` for each wallpaper change. Senda does not start the `awww` daemon.

## Instalación

- [Instalación](../docs/installation.md): instalador, `senda update` y estado de `senda setup`.
- [Configuración](../docs/configuration.md): archivo `KEY=VALUE`, ubicación y claves que se leen.
