#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Try to find picotool
PICOTOOL="${PICOTOOL:-${HOME}/.pico-sdk/picotool/2.3.0/picotool/picotool}"
if [ ! -x "$PICOTOOL" ]; then
  PICOTOOL="$(command -v picotool || true)"
fi
if [ -z "$PICOTOOL" ] || [ ! -x "$PICOTOOL" ]; then
  echo "picotool not found. Install Pico SDK tools or set PICOTOOL env var to the picotool binary." >&2
  exit 1
fi

echo "Flashing SuperLoop ELF to Pico using $PICOTOOL"
if [ ! -f build/SuperLoop.elf ]; then
  echo "Build output build/SuperLoop.elf not found. Run ./scripts/run_cpp.sh first." >&2
  exit 1
fi

"$PICOTOOL" load build/SuperLoop.elf -fx
echo "Flashed."
