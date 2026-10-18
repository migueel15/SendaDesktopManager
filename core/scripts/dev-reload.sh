#!/usr/bin/env bash
# Runs Senda from this checkout in place of the installed release: builds the
# binary, restarts the Quickshell shell with this checkout's QML, and opens a
# terminal that follows the shell log. QML is read from the checkout, so a
# restart is enough after editing it.
#
# Usage:
#   core/scripts/dev-reload.sh            build and restart the development shell
#   core/scripts/dev-reload.sh --release  stop the development shell and start the installed release
#
# Environment:
#   TERMINAL  terminal emulator for the log window (default: kitty)
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
core_dir=$(cd "$script_dir/.." && pwd)
repo_dir=$(cd "$core_dir/.." && pwd)

bin="$core_dir/dist/senda"
dev_home="${XDG_CACHE_HOME:-$HOME/.cache}/senda-dev"
log_file="$dev_home/shell.log"
terminal="${TERMINAL:-kitty}"

die() {
  echo "Error: $*" >&2
  exit 1
}

# Stops the installed unit and any shell started by hand. Missing pieces are
# not an error, because the first run has nothing to stop.
stop_shell() {
  systemctl --user stop senda.service 2>/dev/null || true
  if [ -x "$bin" ]; then
    "$bin" shell kill >/dev/null 2>&1 || true
  fi
}

if [ "${1:-}" = "--release" ]; then
  stop_shell
  systemctl --user start senda.service || die "no se pudo arrancar senda.service"
  echo "Senda release restaurada."
  exit 0
fi

# 1. Build this checkout. The dev version disables `senda update`, so the
# installed release is never replaced by this build.
echo "Compilando $bin..."
(cd "$core_dir" && VERSION=dev ./scripts/build.sh) || die "la compilación falló."

# 2. Data directory the development binary reads through SENDA_HOME. Symlinks
# keep it on the checkout's files, so QML and scripts edits take effect.
mkdir -p "$dev_home"
ln -sfn "$repo_dir/quickshell" "$dev_home/quickshell"
ln -sfn "$core_dir/scripts" "$dev_home/scripts"

# 3. Restart the shell with the development binary.
stop_shell
: >"$log_file"
SENDA_HOME="$dev_home" setsid "$bin" shell run >>"$log_file" 2>&1 </dev/null &
shell_pid=$!
sleep 2
if ! kill -0 "$shell_pid" 2>/dev/null; then
  tail -n 30 "$log_file" >&2
  die "el shell de desarrollo terminó al arrancar; revisa $log_file"
fi
echo "Shell de desarrollo en marcha (pid $shell_pid). Log: $log_file"

# 4. Follow the log in a new terminal window, when one is available.
if command -v "$terminal" >/dev/null 2>&1; then
  if [ "$(basename "$terminal")" = "kitty" ]; then
    setsid "$terminal" tail -n 50 -F "$log_file" >/dev/null 2>&1 </dev/null &
  else
    setsid "$terminal" -e tail -n 50 -F "$log_file" >/dev/null 2>&1 </dev/null &
  fi
else
  echo "No se encontró el terminal '$terminal'; sigue el log con: tail -F $log_file"
fi
