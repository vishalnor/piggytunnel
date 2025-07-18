#!/bin/bash

echo ".........................................................."
echo "Tunnel Details:"

# Check if the pinggy_tunnel_info.json file exists
if [ -f "$HOME/pinggy_tunnel_info.json" ]; then
    # Read the JSON and extract the tunnel address using jq
    TUNNEL_INFO=$(cat "$HOME/pinggy_tunnel_info.json")
    PUBLIC_URL=$(echo "$TUNNEL_INFO" | jq -r '.tunnels[0].address // empty') # Use // empty for robustness

    if [ -n "$PUBLIC_URL" ]; then # Check if URL is not empty
        echo "URL: $PUBLIC_URL"
    else
        echo "URL: Not found in pinggy_tunnel_info.json. Check the file content."
        cat "$HOME/pinggy_tunnel_info.json" # Print file content for debugging
    fi
else
    echo "Error: pinggy_tunnel_info.json not found in $HOME. The Pinggy tunnel might not have started correctly."
    echo "Please ensure 'start.sh' created this file."
fi

echo "Username: runneradmin"
echo "Password: P@ssw0rd!"
echo ".........................................................."
