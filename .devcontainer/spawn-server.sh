#!/bin/bash

# Store PIDs of background servers
PIDS=()

function start_server {
    local venv_path=$1
    local port=$2

    echo "Starting Server on port $port with venv: $venv_path"
    source "$venv_path/bin/activate"
	chmod +x ./script/*
    xt-server -p "$port" &  # Start server in background
    PIDS+=($!)  # Save the process ID (PID) of the server
}

# Function to stop all servers
function stop_servers {
    echo "Stopping servers..."
    for pid in "${PIDS[@]}"; do
        echo "Killing process $pid"
        kill "$pid"
    done
    wait  # Wait for processes to fully terminate
    echo "All servers stopped."
    exit 0
}

# Catch Ctrl+C (SIGINT) and stop servers
trap stop_servers SIGINT

# Array of ports and venv paths
ports=(7410 7411 7420 7421)
venvs=("db1.venv" "db2.venv" "db3.venv" "db4.venv")

# Start multiple servers with different venvs
for i in "${!ports[@]}"; do
    start_server "${venvs[$i]}" "${ports[$i]}"  # Call the function for each server
done

# Keep script running
wait
