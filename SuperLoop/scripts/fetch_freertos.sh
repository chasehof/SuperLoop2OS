#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
THIRDParty="$ROOT/freertos/third_party"
mkdir -p "$THIRDParty"

echo "Fetching FreeRTOS kernel into $THIRDParty"
if [ -d "$THIRDParty/FreeRTOS-Kernel" ]; then
  echo "FreeRTOS-Kernel already present. Pulling latest changes."
  (cd "$THIRDParty/FreeRTOS-Kernel" && git pull)
else
  git clone --depth 1 https://github.com/FreeRTOS/FreeRTOS-Kernel.git "$THIRDParty/FreeRTOS-Kernel"
fi

echo "Fetched FreeRTOS kernel. You can now build the FreeRTOS variant with CMake in freertos/"
