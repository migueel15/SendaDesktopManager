#!/usr/bin/env bash
# Installs the latest Senda release (Linux amd64) into a user-local bin directory.
# Never requires root and never uses sudo.
set -euo pipefail

REPO="migueel15/SendaDesktopManager"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
DOWNLOAD_BASE="https://github.com/${REPO}/releases/download"

die() {
  echo "Error: $*" >&2
  exit 1
}

# 1. Refuse to run as root.
if [ "${EUID}" -eq 0 ]; then
  die "no ejecutes este instalador como root. Ejecútalo con tu usuario normal."
fi

# 2. Check platform.
if [ "$(uname -s)" != "Linux" ]; then
  die "sistema operativo no soportado: $(uname -s). Senda solo tiene binarios para Linux."
fi
if [ "$(uname -m)" != "x86_64" ]; then
  die "arquitectura no soportada: $(uname -m). Senda solo tiene binarios para x86_64."
fi

# 3. Check required tools.
for cmd in curl sha256sum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "falta la herramienta requerida '$cmd'. Instálala e inténtalo de nuevo."
  fi
done

# 4. Read the latest release tag without requiring jq.
api_response=$(curl --proto '=https' --tlsv1.2 -fsSL "$API_URL") \
  || die "no se pudo consultar la última versión en GitHub."
tag=$(printf '%s\n' "$api_response" \
  | grep -m1 '"tag_name"' \
  | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/') || true

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "la etiqueta de la última versión no es válida: '${tag}'."
fi

asset="senda-${tag}-linux-amd64"

# 5. Temporary workspace, removed on exit (including the install temp file).
tmp_dir=$(mktemp -d) || die "no se pudo crear el directorio temporal."
tmp_target=""
trap 'rm -rf "$tmp_dir"; rm -f "${tmp_target:-}"' EXIT

# 6. Download the binary and the checksums file.
echo "Descargando Senda ${tag}..."
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp_dir/$asset" \
  "$DOWNLOAD_BASE/$tag/$asset" \
  || die "no se pudo descargar el binario ${asset}."
curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp_dir/checksums.txt" \
  "$DOWNLOAD_BASE/$tag/checksums.txt" \
  || die "no se pudo descargar checksums.txt."

# 7. Verify the binary checksum before installing anything.
# Keep only the checksum line for this asset (accepts an optional '*' binary marker).
awk -v f="$asset" '{ n = $2; sub(/^\*/, "", n); if (n == f) print }' \
  "$tmp_dir/checksums.txt" > "$tmp_dir/binary.sha256"
if [ ! -s "$tmp_dir/binary.sha256" ]; then
  die "checksums.txt no contiene una entrada para ${asset}. No se instala nada."
fi

echo "Verificando la suma SHA-256..."
if ! (cd "$tmp_dir" && sha256sum -c binary.sha256); then
  die "la verificación SHA-256 ha fallado. No se ha instalado nada."
fi

# 8. Install atomically: copy to a temp file in the target directory, then rename.
target_dir="${SENDA_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$target_dir"
tmp_target=$(mktemp "$target_dir/.senda.XXXXXX")
cp "$tmp_dir/$asset" "$tmp_target"
chmod 755 "$tmp_target"
mv -f "$tmp_target" "$target_dir/senda"

# 9. Report the result.
echo "Senda ${tag} instalada en ${target_dir}/senda"

case ":${PATH}:" in
  *":${target_dir}:"*) ;;
  *)
    echo "Aviso: ${target_dir} no está en tu PATH. Añade esta línea a tu ~/.bashrc o ~/.zshrc:"
    echo "  export PATH=\"${target_dir}:\$PATH\""
    ;;
esac

echo "Ejecuta: senda setup"
