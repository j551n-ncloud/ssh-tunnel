#!/bin/bash

# Input the FQDN of the iDRAC server
read -p "Enter the FQDN of the iDRAC server: " IDRAC_FQDN

# Variables
LOCAL_PORT=8443             # Local port on your laptop
JUMP_HOST="odcf-admin01.dkfz-heidelberg.de" # Jump host hostname
USER="j551n"            # Your SSH username on the jump host

# SSH Tunnel Command
echo "Setting up SSH tunnel to iDRAC (${IDRAC_FQDN}) via jump host..."
ssh -L ${LOCAL_PORT}:${IDRAC_FQDN}:443 ${USER}@${JUMP_HOST} -N

# Notify user
echo "Tunnel established! Access iDRAC at https://localhost:${LOCAL_PORT}"
