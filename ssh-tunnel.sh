#!/usr/bin/env bash
# Open an SSH tunnel to a server's web interface (e.g. iDRAC) through a jump host.
# Usage: JUMP_HOST=jump.example.com SSH_USER=me ./ssh-tunnel.sh [target-fqdn]

set -euo pipefail

BASE_PORT=${BASE_PORT:-8443}            # first local port to try
TARGET_PORT=${TARGET_PORT:-443}         # port on the target (iDRAC web UI: 443)
JUMP_HOST=${JUMP_HOST:-jumphost}        # jump host name or IP
SSH_USER=${SSH_USER:-$USER}             # your user on the jump host

TARGET=${1:-}
if [ -z "$TARGET" ]; then
    read -r -p "Enter the FQDN of the target server: " TARGET
fi

# Find the first free local port
LOCAL_PORT=$BASE_PORT
while lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; do
    LOCAL_PORT=$((LOCAL_PORT + 1))
done

# -f: go to the background after authentication, -N: no remote command, only the tunnel
if ssh -f -N -o ExitOnForwardFailure=yes -L "${LOCAL_PORT}:${TARGET}:${TARGET_PORT}" "${SSH_USER}@${JUMP_HOST}"; then
    echo "Tunnel established: https://localhost:${LOCAL_PORT} -> ${TARGET}:${TARGET_PORT} via ${JUMP_HOST}"
else
    echo "Could not open the tunnel." >&2
    exit 1
fi
