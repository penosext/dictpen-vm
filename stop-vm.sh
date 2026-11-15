#!/bin/sh
# dictpen-vm: stop the VM (ask the guest to power off, then kill qemu).
# Same as: python3 scripts/dpctl.py down
set -eu
cd "$(dirname "$0")"
PY=${DICTPEN_PYTHON:-python3}
exec "$PY" scripts/dpctl.py down "$@"
