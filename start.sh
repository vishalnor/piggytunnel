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
# FIX: Add '--break-system-packages' to comply with PEP 668 on externally managed environments.
echo "Installing pinggy via python3 -m pip..."
python3 -m pip install --user --break-system-packages pinggy

# Ensure 'jq' is installed via Homebrew for JSON parsing later.
if ! command -v jq &> /dev/null; then
    echo "jq not found, installing via Homebrew..."
    # Homebrew is usually in the PATH on GitHub runners, but being explicit doesn't hurt.
    export PATH="/opt/homebrew/bin:$PATH"
    brew install jq
fi

# Ensure the output file is empty before starting pinggy
> ~/pinggy_tunnel_info.json

# Start Pinggy tunnel in background and write its JSON output to a file.
# Use 'python3 -m pinggy' to run the module directly, avoiding potential PATH issues
# with the executable after a --user install.
echo "Starting pinggy tunnel using 'python3 -m pinggy'..."
nohup python3 -m pinggy --output json --port 5900 > ~/pinggy_tunnel_info.json 2>&1 &

# Give Pinggy a moment to start and write the file.
# Increased sleep time to be safer.
sleep 20

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
