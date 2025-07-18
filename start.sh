#!/bin/bash

# --- 1. Initial System Setup ---

echo "Starting initial system setup..."

# Disable Spotlight indexing
# Output messages from mdutil will be printed.
sudo mdutil -i off -a

# Create new account 'runneradmin'
echo "Creating runneradmin user..."
sudo dscl . -create /Users/runneradmin
sudo dscl . -create /Users/runneradmin UserShell /bin/bash
sudo dscl . -create /Users/runneradmin RealName Runner_Admin
sudo dscl . -create /Users/runneradmin UniqueID 1001
sudo dscl . -create /Users/runneradmin PrimaryGroupID 80
# IMPORTANT: Changed NFSHomeDirectory from /Users/tcv to /Users/runneradmin
# It's best practice for the home directory to match the username.
sudo dscl . -create /Users/runneradmin NFSHomeDirectory /Users/runneradmin
# Set password for runneradmin
echo "Setting password for runneradmin..."
sudo dscl . -passwd /Users/runneradmin P@ssw0rd!
# Create the home directory for the new user
sudo createhomedir -c -u runneradmin > /dev/null
# Add runneradmin to the admin group for sudo privileges
echo "Adding runneradmin to admin group..."
sudo dscl . -append /Groups/admin GroupMembership runneradmin

# --- 2. VNC Configuration ---

echo "Configuring VNC (Remote Management)..."
# Enable VNC for all users with all privileges
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
# Enable VNC legacy password (important for some VNC clients)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes 

# Set VNC password for the legacy VNC access
# This uses the specific hash you provided earlier for 'runnerrdp'
echo "Setting VNC password (runnerrdp)..."
echo runnerrdp | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# Restart and activate Remote Management services
echo "Restarting and activating Remote Management..."
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# --- 3. Pinggy Tunnel Setup ---

echo "Setting up Pinggy tunnel for VNC (port 5900)..."

# Install Pinggy CLI using pip
# Check if pip is available, install if not (basic check)
if ! command -v pip &> /dev/null
then
    echo "pip not found, attempting to install it..."
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python3 get-pip.py --user
    export PATH=$PATH:/Users/runneradmin/Library/Python/3.X/bin # Adjust 3.X if needed, usually 3.9 on macOS runners
    echo "pip installed. Please restart the runner if you face issues."
fi

# Ensure pinggy is installed for the current user
pip install pinggy --user

# Start Pinggy tunnel in background and write its JSON output to a file
# This file will be read by the GitHub Actions workflow to extract the URL.
# Redirecting stderr (2>&1) ensures any error messages from pinggy are also captured in the file.
echo "Starting pinggy tunnel and saving info to ~/pinggy_tunnel_info.json"
# Using 'nohup' and 'bash -c' to ensure it runs even if the parent script exits.
# This makes the tunnel more resilient within a CI environment.
nohup bash -c "pinggy --output json --port 5900 > ~/pinggy_tunnel_info.json 2>&1" &

# Give Pinggy a moment to start and write the file
sleep 10

echo "start.sh script finished. Pinggy tunnel should be active."
echo "Check ~/pinggy_tunnel_info.json for tunnel details in subsequent steps."
