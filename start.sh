#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

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

# Install pip3 if not found
if ! command -v pip3 &> /dev/null
then
    echo "pip3 not found, attempting to install it..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user --break-system-packages # Use --break-system-packages here too
fi

# Install Pinggy CLI and jq (jq is needed for parsing later if not already installed via brew)
# --break-system-packages is essential here for macOS runners
# --user installs to user's home directory (e.g., ~/.local/bin or ~/Library/Python/X.Y/bin)
echo "Installing pinggy and jq (if needed) with --break-system-packages and --user..."
pip3 install pinggy --user --break-system-packages

# Also ensure 'jq' is installed via Homebrew, as it's critical for parsing
if ! command -v jq &> /dev/null
then
    echo "jq not found, installing via Homebrew..."
    brew install jq
fi

# Find the correct python user bin path to ensure pinggy is found within nohup
# This uses 'pip3 show pinggy' to find its installed location reliably
PYTHON_USER_BIN=$(python3 -c "import site; print(site.getuserbase())")/bin
if [ ! -d "$PYTHON_USER_BIN" ]; then
    echo "Warning: Python user bin directory not found at $PYTHON_USER_BIN, trying common paths."
    # Fallback to common paths if dynamic detection fails (e.g. for older python versions/configs)
    if [ -d "$HOME/Library/Python/3.10/bin" ]; then PYTHON_USER_BIN="$HOME/Library/Python/3.10/bin"; fi
    if [ -d "$HOME/.local/bin" ]; then PYTHON_USER_BIN="$HOME/.local/bin"; fi
fi

export PATH="$PATH:$PYTHON_USER_BIN" # Temporarily set PATH for this nohup command

# Ensure the output file is empty before starting pinggy
> ~/pinggy_tunnel_info.json

# Start Pinggy tunnel in background and write its JSON output to a file.
# Redirecting pinggy's stdout to the file.
# Redirecting nohup's own messages and pinggy's stderr to /dev/null to keep JSON file clean.
echo "Starting pinggy tunnel via $PYTHON_USER_BIN/pinggy and saving info to ~/pinggy_tunnel_info.json"
nohup bash -c "$PYTHON_USER_BIN/pinggy --output json --port 5900 > ~/pinggy_tunnel_info.json" > /dev/null 2>&1 &

# Give Pinggy a moment to start and write the file
sleep 15 # Increased sleep time slightly for robustness

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
