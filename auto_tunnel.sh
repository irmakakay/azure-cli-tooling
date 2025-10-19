#!/bin/bash

CONFIG="$HOME/.azure/ssh_config_vmcmreprod01shape"
HOST="rg_dtl_cmre_expl_dynamic-vmcmreprod01shape"

echo "Starting persistent SSH tunnel to $HOST..."

while true; do
    ssh -F "$CONFIG" -L 3389:localhost:3389 "$HOST"
    echo "Tunnel disconnected. Reconnecting in 5 seconds..."
    sleep 5
done
