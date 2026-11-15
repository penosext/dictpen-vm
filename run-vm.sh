#!/bin/sh
# dictpen-vm: start the VM. Same as: python3 scripts/dpctl.py up
# QEMU command line lives in ONE place (scripts/dpctl.py), this only forwards.
# Usage: sh run-vm.sh [--pack NAME] [--display gtk|none] [--fresh] ...
set -eu
cd "$(dirname "$0")"
PY=${DICTPEN_PYTHON:-python3}
exec "$PY" scripts/dpctl.py up "$@"
