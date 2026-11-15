#!/bin/sh
# dictpen-vm: SSH into the dev VM as root (key auth, port 2222).
# The key is generated locally by: python3 scripts/bootstrap.py
set -eu
cd "$(dirname "$0")"
KEY=tools/ssh/id_devvm
if [ ! -f "$KEY" ]; then
    echo "[!] missing $KEY - run: python3 scripts/bootstrap.py" >&2
    exit 1
fi
exec ssh -i "$KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=vm/known_hosts_devvm \
    -o ConnectTimeout=6 \
    -p 2222 root@127.0.0.1 "$@"
