#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$HOME/.pico-sdk/cmake/v4.3.4/bin:$HOME/.pico-sdk/ninja/v1.13.2:$HOME/.pico-sdk/toolchain/15_2_Rel1/bin:$PATH"

if [ ! -d "freertos/third_party/FreeRTOS-Kernel" ]; then
  echo "FreeRTOS kernel missing. Run ./scripts/fetch_freertos.sh first." >&2
  exit 1
fi

# FreeRTOS is an add_subdirectory() of the top-level CMakeLists, so build the
# one tree rather than configuring a second one under freertos/build. Keeping a
# single output dir avoids flashing a stale artifact from the other tree.
echo "Building SuperLoop_FreeRTOS..."
cmake -S . -B build -G Ninja
cmake --build build --target SuperLoop_FreeRTOS

ELF="build/freertos/SuperLoop_FreeRTOS.elf"
UF2="build/freertos/SuperLoop_FreeRTOS.uf2"
if [ ! -f "$ELF" ]; then
  echo "Build did not produce $ELF" >&2
  exit 1
fi

PICOTOOL="${PICOTOOL:-${HOME}/.pico-sdk/picotool/2.3.0/picotool/picotool}"
if [ ! -x "$PICOTOOL" ]; then
  PICOTOOL="$(command -v picotool || true)"
fi

# Fast path: device already in BOOTSEL, flash over USB with picotool.
if [ -n "$PICOTOOL" ] && [ -x "$PICOTOOL" ] && "$PICOTOOL" load "$ELF" -f >/dev/null 2>&1; then
  echo "Flashed via picotool. Rebooting into the new firmware..."
  "$PICOTOOL" reboot >/dev/null 2>&1 || true
  echo "Done. Watch it with a serial terminal on the USB CDC port (115200 baud)."
  exit 0
fi

# Fallback: copy the UF2 to the RPI-RP2 mass-storage volume.
find_mount() {
  local base
  for base in "/media/$USER" "/run/media/$USER" "/media" "/mnt/c" "/mnt/d"; do
    [ -d "$base" ] || continue
    for d in "$base"/*; do
      [ -d "$d" ] || continue
      [ "$(basename "$d")" = "RPI-RP2" ] && { echo "$d"; return 0; }
    done
  done
  return 1
}

if [ ! -f "$UF2" ]; then
  echo "UF2 not found at $UF2" >&2
  exit 1
fi

if MOUNT="$(find_mount)"; then
  echo "Copying $UF2 to $MOUNT ..."
  cp -v "$UF2" "$MOUNT/"
  sync
  echo "Done. The Pico will reboot into the new firmware."
  exit 0
fi

cat >&2 <<EOF
Could not flash: no BOOTSEL device and no RPI-RP2 drive found.

Hold the BOOTSEL button while plugging the Pico in, then release it once the
RPI-RP2 drive appears, and re-run this script. Or copy $UF2 to the Pico's
RPI-RP2 drive by hand.
EOF
exit 2
