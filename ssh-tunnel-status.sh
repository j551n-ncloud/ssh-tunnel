#!/usr/bin/env bash

# Port range to check
BASE_PORT=${BASE_PORT:-8443}
END_PORT=${END_PORT:-8500}

# Function to list and close SSH tunnels
list_and_close_tunnels() {
    echo "Searching for active SSH tunnels using ports starting from ${BASE_PORT}..."

    # Find processes using ports from BASE_PORT onwards
    active_ports=()
    for port in $(seq "$BASE_PORT" "$END_PORT"); do
        # only ssh processes listening on the port, never other programs that happen to use it
        PID=$(lsof -a -nP -iTCP:"$port" -sTCP:LISTEN -c ssh -t 2>/dev/null | head -1)
        if [ -n "$PID" ]; then
            active_ports+=($port)
        fi
    done

    if [ ${#active_ports[@]} -eq 0 ]; then
        echo "No active SSH tunnels found."
        exit 0
    fi

    echo "Active SSH tunnels found on the following ports:"
    for port in "${active_ports[@]}"; do
        echo "- Port $port"
    done

    read -p "Enter the port you want to close (or 'all' to close all): " selected_port

    if [ "$selected_port" == "all" ]; then
        for port in "${active_ports[@]}"; do
            PID=$(lsof -a -nP -iTCP:"$port" -sTCP:LISTEN -c ssh -t 2>/dev/null | head -1)
            echo "Closing tunnel on port $port (PID: $PID)..."
            kill "$PID"
        done
        echo "All detected SSH tunnels closed."
    else
        PID=$(lsof -a -nP -iTCP:"$selected_port" -sTCP:LISTEN -c ssh -t 2>/dev/null | head -1)
        if [ -n "$PID" ]; then
            echo "Closing tunnel on port $selected_port (PID: $PID)..."
            kill "$PID"
            echo "Tunnel on port $selected_port closed."
        else
            echo "No active tunnel found on port $selected_port."
        fi
    fi
}

# Run the function
list_and_close_tunnels

