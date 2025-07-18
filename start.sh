#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting initial system setup..."

# Disable Spotlight indexing
sudo mdutil -i off -a

# --- 1. User Account Creation ---
echo "Creating runneradmin user..."
sudo dscl . -create /Users/runneradmin
sudo dscl . -create /Users/runneradmin UserShell /bin/bash
sudo dscl . -create /Users/runneradmin RealName Runner_Admin
sudo dscl . -create /Users/runneradmin UniqueID 1001
sudo dscl . -create /Users/runneradmin PrimaryGroupID 80
sudo dscl . -create /Users/runneradmin NFSHomeDirectory /Users/runneradmin
echo "Setting password for runneradmin..."
sudo dscl . -passwd /Users/runneradmin P@ssw0rd!
# The following command can cause 'getcwd' errors in some environments.
sudo createhomedir -c -u runneradmin > /dev/null
echo "Adding runneradmin to admin group..."
sudo dscl . -append /Groups/admin GroupMembership runneradmin

# FIX: Change to a stable directory to prevent 'getcwd' errors from affecting subsequent commands.
echo "Changing to /tmp to ensure a stable working directory."
cd /tmp

# --- 2. VNC Configuration ---
echo "Configuring VNC (Remote Management)..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes

echo "Setting VNC password (runnerrdp)..."
echo runnerrdp | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

echo "Restarting and activating Remote Management..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# --- 3. Pinggy Tunnel Setup ---
echo "Setting up Pinggy tunnel for VNC (port 5900)..."

# Install Pinggy using python's pip module to be robust.
echo "Installing pinggy via python3 -m pip..."
python3 -m pip install --user --break-system-packages pinggy

# Ensure 'jq' is installed via Homebrew for JSON parsing later.
if ! command -v jq &> /dev/null; then
    echo "jq not found, installing via Homebrew..."
    export PATH="/opt/homebrew/bin:$PATH"
    brew install jq
fi

# FIX: Find the absolute path to the pinggy executable to ensure we run the correct one.
# First, find the directory where pip installs user scripts.
USER_SCRIPT_DIR=$(python3 -c 'import site; print(f"{site.USER_BASE}/bin")')
# Add this directory to the PATH for the rest of the script.
export PATH="$PATH:$USER_SCRIPT_DIR"
# Now, find the absolute path to the pinggy executable.
PINGGY_CMD=$(command -v pinggy)

# Fail-safe check to ensure the command was found.
if [ -z "$PINGGY_CMD" ]; then
    echo "Error: 'pinggy' command not found in PATH after installation."
    echo "Searched in user script directory: $USER_SCRIPT_DIR"
    exit 1
fi

echo "Found pinggy executable at: $PINGGY_CMD"

# Ensure the output file is empty before starting pinggy
> ~/pinggy_tunnel_info.json

# Start Pinggy tunnel in the background using its absolute path.
# This is the most reliable way to avoid PATH and python version issues.
echo "Starting pinggy tunnel using its full path..."
nohup "$PINGGY_CMD" --output json --port 5900 > ~/pinggy_tunnel_info.json 2>&1 &

# Give Pinggy a moment to start and write the file.
sleep 20

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
