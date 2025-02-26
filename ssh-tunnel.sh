#!/bin/bash

# Input the FQDN of the iDRAC server
read -p "Enter the FQDN of the iDRAC server: " IDRAC_FQDN

# Variables
BASE_PORT=8443                              # Base local port on your laptop
JUMP_HOST="jumphost"   # Jump host hostname
USER="username"                                  # Your SSH username on the jump host

# Find an available port
LOCAL_PORT=$BASE_PORT
while lsof -i :$LOCAL_PORT >/dev/null 2>&1; do
    ((LOCAL_PORT++))
done

# Notify the user that the tunnel is established
echo "Tunnel established! Access iDRAC at https://localhost:${LOCAL_PORT}"

# Run the SSH command with -f and -N options (simplified)
# -f forces SSH to go to the background just before command execution, but still prompts for the password
# -N tells SSH not to execute any command on the remote machine (only sets up the tunnel)
ssh -f -N -L ${LOCAL_PORT}:${IDRAC_FQDN}:443 ${USER}@${JUMP_HOST}

