#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v mpremote >/dev/null 2>&1; then
  echo "mpremote not found." >&2
  echo "Install it with:  pip install mpremote" >&2
  exit 1
fi

# A C++ or FreeRTOS image has no MicroPython REPL, so mpremote will hang or
# error here. Check up front and say something useful.
if ! mpremote connect serial://auto exec "print('ok')" >/dev/null 2>&1; then
  echo "Could not reach a MicroPython REPL on the Pico." >&2
  echo "The board is probably still running the C++ or FreeRTOS firmware." >&2
  echo "Flash MicroPython first (see scripts/flash_micropython.sh), then re-run this." >&2
  exit 1
fi

# Stage a clean copy. The repo contains CPython __pycache__ directories that are
# useless on MicroPython (and can shadow modules), so never copy them.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r python/. "$STAGE/"
find "$STAGE" -type d -name __pycache__ -prune -exec rm -rf {} +
find "$STAGE" -type f -name '*.pyc' -delete

echo "Deploying MicroPython package to Pico root..."
COUNT=0
while IFS= read -r f; do
  rel="${f#"$STAGE"/}"
  # rel already uses '/' as the separator, so it is the remote path as-is
  remote=":/$rel"
  echo "  $rel -> $remote"
  mpremote connect serial://auto fs put "$f" "$remote"
  COUNT=$((COUNT + 1))
done < <(find "$STAGE" -type f -name '*.py' | sort)

if [ "$COUNT" -eq 0 ]; then
  echo "No .py files staged - nothing to upload." >&2
  exit 1
fi

echo "Deployed $COUNT file(s). Files now on the board:"
mpremote connect serial://auto fs ls : | sed 's/^/  /'
echo
echo "Unplug and replug the Pico (or press Ctrl-D in the REPL) to run boot.py."
