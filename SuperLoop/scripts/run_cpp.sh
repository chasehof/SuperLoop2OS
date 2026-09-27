#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Put the SDK's bundled cmake/ninja on PATH. Without this the script dies with
# "cmake: command not found" in any shell that isn't the VS Code extension.
export PATH="$HOME/.pico-sdk/cmake/v4.3.4/bin:$HOME/.pico-sdk/ninja/v1.13.2:$HOME/.pico-sdk/toolchain/15_2_Rel1/bin:$PATH"

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found on PATH." >&2
  echo "Install the Pico SDK, or adjust the paths at the top of this script." >&2
  exit 1
fi

# -G Ninja is required: the script invokes ninja below, but a build dir created
# earlier with a different generator (e.g. by plain cmake) has no build.ninja.
echo "Building C++ SuperLoop..."
cmake -S . -B build -G Ninja
cmake --build build

echo
echo "Built:"
echo "  build/SuperLoop.uf2"
echo "Flash it with ./scripts/deploy_cpp.sh"
