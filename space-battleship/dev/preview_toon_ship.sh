#!/bin/sh
set -eu
exec python3 "$(dirname "$0")/toon_ship/preview.py" --fixture Heavy_Battleship --interactive "$@"
