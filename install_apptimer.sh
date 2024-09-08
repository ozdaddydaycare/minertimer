#!/bin/zsh
###
# Script to securely install and configure the apptimer files
# The script needs to be run from an Administrator account with sudo privileges
# Copyright OzDaddyDayCare
###

# Check for sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo privileges" 
   exit 1
fi

# Define variables
INSTALL_DIR="/Library/Application Support/OzDaddyDayCare/MinerTimer"
SCRIPT_NAME="apptimer.sh"
PLIST_NAME="com.ozdaddydaycare.apptimer_daily_timer.plist"
CONFIG_NAME="config.txt"
LOG_DIR="/var/lib/ozdaddydaycare_apptimer"

# Step 1: Create necessary directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$LOG_DIR"

# Step 2: Copy and secure main script
cp "$SCRIPT_NAME" "$INSTALL_DIR/"
chown root:wheel "$INSTALL_DIR/$SCRIPT_NAME"
chmod 755 "$INSTALL_DIR/$SCRIPT_NAME"
chflags schg "$INSTALL_DIR/$SCRIPT_NAME"  # Set system immutable flag

# Step 3: Create and secure config file
if [ ! -f "$LOG_DIR/$CONFIG_NAME" ]; then
    cat > "$LOG_DIR/$CONFIG_NAME" << EOL
default:1800
weekend:3600
buffer:900
Minecraft:1800
firefox:0
chrome:14400
safari:0
roblox:3600
EOL
fi
chown root:wheel "$LOG_DIR/$CONFIG_NAME"
chmod 644 "$LOG_DIR/$CONFIG_NAME"

# Step 4: Copy and secure PLIST file
cp "$PLIST_NAME" "/Library/LaunchDaemons/"
chown root:wheel "/Library/LaunchDaemons/$PLIST_NAME"
chmod 644 "/Library/LaunchDaemons/$PLIST_NAME"
chflags schg "/Library/LaunchDaemons/$PLIST_NAME"  # Set system immutable flag

# Step 5: Update PLIST file with correct path
sed -i '' "s|/Users/Shared/apptimer/apptimer.sh|$INSTALL_DIR/$SCRIPT_NAME|g" "/Library/LaunchDaemons/$PLIST_NAME"

# Step 6: Set proper permissions for log directory
chown root:wheel "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Step 7: Register the apptimer as a background task
launchctl load -w "/Library/LaunchDaemons/$PLIST_NAME"

# Step 8: Post Script report
echo ""
echo "MinerTimer has been installed and configured."
echo "To check if the MinerTimer background process is running, type:"
echo "sudo launchctl list | grep com.ozdaddydaycare.apptimer_daily_timer"
echo "If you see a line of text starting with a process number, the script is running."
echo ""
echo "The configuration file is located at: $LOG_DIR/$CONFIG_NAME"
echo "You can modify this file to adjust time limits and monitored applications."
echo ""
echo "IMPORTANT: To uninstall or stop the MinerTimer, use the following commands:"
echo "sudo chflags noschg $INSTALL_DIR/$SCRIPT_NAME /Library/LaunchDaemons/$PLIST_NAME"
echo "sudo launchctl unload /Library/LaunchDaemons/$PLIST_NAME"
echo "sudo rm -rf $INSTALL_DIR /Library/LaunchDaemons/$PLIST_NAME $LOG_DIR"

# Additional security measure: Set ACL to prevent non-root users from modifying files
chmod +a "group:everyone deny delete" "$INSTALL_DIR"
chmod +a "group:everyone deny delete" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +a "group:everyone deny delete" "/Library/LaunchDaemons/$PLIST_NAME"
chmod +a "group:everyone deny delete" "$LOG_DIR"
chmod +a "group:everyone deny delete" "$LOG_DIR/$CONFIG_NAME"
