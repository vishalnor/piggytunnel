#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

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

# Ensure pip3 is available and install it if not
if ! command -v pip3 &> /dev/null
then
    echo "pip3 not found, attempting to install it..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user --break-system-packages
fi

# Install Pinggy CLI with --user and --break-system-packages
echo "Installing pinggy with --break-system-packages and --user..."
pip3 install pinggy --user --break-system-packages

# Also ensure 'jq' is installed via Homebrew, as it's critical for parsing
if ! command -v jq &> /dev/null
then
    echo "jq not found, installing via Homebrew..."
    brew install jq
fi

# --- CRITICAL FIX: Determine the actual path of the installed 'pinggy' executable ---
# Method 1: Use `pip show` to find the 'Location' and derive the bin directory
# This assumes the 'bin' directory is typically directly under the userbase directory.
PINGGY_LOCATION=$(pip3 show pinggy | grep -E "^Location:" | awk '{print $2}')
if [ -n "$PINGGY_LOCATION" ]; then
    # The 'Location' is typically where the 'pinggy' *package* is. The executable is usually in a 'bin'
    # directory relative to the Python user base.
    # A common pattern for --user installs on macOS for python 3.X is /Users/runner/Library/Python/3.X/bin
    PYTHON_MAJOR_MINOR=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PYTHON_USER_BIN_DIR="$HOME/Library/Python/$PYTHON_MAJOR_MINOR/bin"
    
    if [ -f "$PYTHON_USER_BIN_DIR/pinggy" ]; then
        PINGGY_CMD="$PYTHON_USER_BIN_DIR/pinggy"
    elif [ -f "$HOME/.local/bin/pinggy" ]; then
        PINGGY_CMD="$HOME/.local/bin/pinggy"
    else
        echo "Warning: Specific pinggy executable path not found at common locations. Trying command -v."
        # Fallback to command -v if specific paths don't work, ensure PATH is updated first
        export PATH="$PATH:$PYTHON_USER_BIN_DIR:$HOME/.local/bin"
        PINGGY_CMD=$(command -v pinggy)
    fi
fi

if [ -z "$PINGGY_CMD" ]; then
    echo "Error: 'pinggy' command could not be located after installation. Exiting."
    exit 1 # Fail fast if pinggy isn't found
else
    echo "Found pinggy executable at: $PINGGY_CMD"
fi

# Ensure the output file is empty before starting pinggy
> ~/pinggy_tunnel_info.json

# Start Pinggy tunnel in background and write its JSON output to a file.
# Redirecting pinggy's stdout to the file.
# Redirecting nohup's own messages and pinggy's stderr to /dev/null to keep JSON file clean.
echo "Starting pinggy tunnel via $PINGGY_CMD and saving info to ~/pinggy_tunnel_info.json"
nohup bash -c "$PINGGY_CMD --output json --port 5900 > ~/pinggy_tunnel_info.json" > /dev/null 2>&1 &

# Give Pinggy a moment to start and write the file
sleep 15 

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
