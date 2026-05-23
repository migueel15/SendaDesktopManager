# Senda

Senda is a simple and modular desktop manager for Linux Wayland.

The project is currently in an early stage. For now, it includes basic wallpaper management using `awww`.

## Features

- Set wallpapers from the command line
- Support for wallpaper transitions
- Initial support for transition position
- Modular backend-based architecture
- Current wallpaper backend: `swww`

## Requirements

- Linux
- Wayland
- `swww`

If you are using the current wallpaper backend, make sure `awww-daemon` is running before setting a wallpaper.

```bash
swww-daemon
