#!/bin/sh
# dictpen-vm: open the visual console (device view + status bar + drawer).
# Same as: python3 scripts/dpctl.py console
set -eu
cd "$(dirname "$0")"
PY=${DICTPEN_PYTHON:-python3}
exec "$PY" scripts/dpctl.py console "$@"
