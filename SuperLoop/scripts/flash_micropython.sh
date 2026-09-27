#!/usr/bin/env bash
# Flash the MicroPython firmware onto a Pico in BOOTSEL mode.
#
# This must be done BEFORE scripts/deploy_python.sh. MicroPython is a
# self-contained firmware image that provides the interpreter; the C++ and
# FreeRTOS variants replace it entirely, so switching between the Python and the
# native variants means reflashing this every time.
set -euo pipefail
cd "$(dirname "$0")/.."

# Board family -> MicroPython board id. Override with e.g. BOARD=PICOW.
BOARD="${BOARD:-PICO}"
# MicroPython release to install. Override to pin a version for class.
VERSION="${VERSION:-1.25.0}"
UF2_URL="https://github.com/micropython/micropython/releases/download/v${VERSION}/micropython-${BOARD}-${VERSION}.uf2"

# Prefer a UF2 that was already downloaded, so class can run offline.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/micropython-uf2"
UF2="$CACHE_DIR/$(basename "$UF2_URL")"

if [ ! -f "$UF2" ]; then
  echo "Downloading $(basename "$UF2_URL")..."
  mkdir -p "$CACHE_DIR"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar -o "$UF2" "$UF2_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$UF2" "$UF2_URL"
  else
    echo "Need curl or wget to download the MicroPython UF2." >&2
    echo "Or download it manually to: $UF2" >&2
    exit 1
  fi
fi

# Find the RPI-RP2 mass-storage volume. Handles Linux (udisks2 mounts under
# /media/$USER or /run/media/$USER) and WSL, which mounts Windows drives under
# /mnt.
find_mount() {
  local base
  for base in "/media/$USER" "/run/media/$USER" "/media" "/mnt/c" "/mnt/d"; do
    [ -d "$base" ] || continue
    for d in "$base"/*; do
      [ -d "$d" ] || continue
      if [ "$(basename "$d")" = "RPI-RP2" ]; then
        echo "$d"
        return 0
      fi
    done
  done
  return 1
}

if ! MOUNT="$(find_mount)"; then
  echo "No RPI-RP2 drive found." >&2
  echo "Hold BOOTSEL while plugging the Pico in, then release once the RPI-RP2" >&2
  echo "drive appears. On Linux you may also need to mount it from your file manager." >&2
  exit 2
fi

echo "Flashing $UF2 to $MOUNT"
# The drive is read-only FAT; sync then drop it so the bootloader reboots.
cp -v "$UF2" "$MOUNT/" || {
  echo "Copy failed. If the board is mounted read-only, unmount and reinsert it." >&2
  exit 1
}
sync
echo "Copied. The Pico will now reboot into MicroPython."
echo "Then run: ./scripts/deploy_python.sh"
