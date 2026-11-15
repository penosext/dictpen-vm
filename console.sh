#!/bin/sh
# dictpen-vm: interactive serial console of the dev VM (Ctrl+] quits).
# Same as: python3 scripts/console.py
set -eu
cd "$(dirname "$0")"
PY=${DICTPEN_PYTHON:-python3}
exec "$PY" scripts/console.py "$@"
