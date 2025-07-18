#!/bin/bash

# --- 1. Initial System Setup ---

echo "Starting initial system setup..."

# Disable Spotlight indexing
sudo mdutil -i off -a

# Create new account 'runneradmin'
echo "Creating runneradmin user..."
sudo dscl . -create /Users/runneradmin
sudo dscl . -create /Users/runneradmin UserShell /bin/bash
sudo dscl . -create /Users/runneradmin RealName Runner_Admin
sudo dscl . -create /Users/runneradmin UniqueID 1001
sudo dscl . -create /Users/runneradmin PrimaryGroupID 80
sudo dscl . -create /Users/runneradmin NFSHomeDirectory /Users/runneradmin
echo "Setting password for runneradmin..."
sudo dscl . -passwd /Users/runneradmin P@ssw0rd!
sudo createhomedir -c -u runneradmin > /dev/null
echo "Adding runneradmin to admin group..."
sudo dscl . -append /Groups/admin GroupMembership runneradmin

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

# Install Pinggy CLI using pip
if ! command -v pip3 &> /dev/null # Use pip3 for explicit Python 3
then
    echo "pip3 not found, attempting to install it..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user
    # No need to export PATH here, as we'll handle it in the GA step that *uses* pinggy
    echo "pip3 installed. Please restart the runner if you face issues."
fi

# Ensure pinggy is installed for the current user's default Python 3 environment
pip3 install pinggy --user

# --- CRITICAL FIX FOR pinggy_tunnel_info.json CONTENT ---
# Run pinggy, redirect its stdout (which is the JSON) to the file.
# Redirect stderr of the 'pinggy' command to a separate log or /dev/null.
# Redirect nohup's own messages to /dev/null (2>&1 to null).
echo "Starting pinggy tunnel and saving info to ~/pinggy_tunnel_info.json"

# Find the correct python user bin path to ensure pinggy is found within nohup
PYTHON_USER_BIN=$(python3 -m site --user-base)/bin
export PATH="$PATH:$PYTHON_USER_BIN" # Temporarily set PATH for this nohup command

# The command within nohup needs to explicitly call pinggy if it's not in the default PATH
nohup bash -c "$PYTHON_USER_BIN/pinggy --output json --port 5900 > ~/pinggy_tunnel_info.json" > /dev/null 2>&1 &

# Give Pinggy a moment to start and write the file
sleep 10

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
