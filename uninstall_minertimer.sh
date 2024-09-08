#!/bin/zsh
###
# Script to remove the AppTimer files and configuration
# The script needs to be run with sudo privileges
# Copyright OzDaddyDayCare
###

# Check for sudo privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo privileges" 
   exit 1
fi

# Define variables
INSTALL_DIR="/Library/Application Support/OzDaddyDayCare/AppTimer"
PLIST_PATH="/Library/LaunchDaemons/com.ozdaddydaycare.Apptimer_daily_timer.plist"
LOG_DIR="/var/lib/ozdaddydaycare_Apptimer"

# Step 1: Unregister and remove the LaunchDaemon
if [ -f "$PLIST_PATH" ]; then
    echo "Unloading and removing LaunchDaemon..."
    launchctl bootout system/com.ozdaddydaycare.Apptimer_daily_timer
    rm "$PLIST_PATH"
else
    echo "LaunchDaemon PLIST not found. Skipping..."
fi

# Step 2: Remove AppTimer script and installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing AppTimer installation directory..."
    rm -rf "$INSTALL_DIR"
else
    echo "AppTimer installation directory not found. Skipping..."
fi

# Step 3: Remove log directory and files
if [ -d "$LOG_DIR" ]; then
    echo "Removing AppTimer log directory and files..."
    rm -rf "$LOG_DIR"
else
    echo "AppTimer log directory not found. Skipping..."
fi

# Step 4: Remove system immutable flags if they exist
chflags -R noschg "$INSTALL_DIR" "$PLIST_PATH" "$LOG_DIR" 2>/dev/null

# Step 5: Final cleanup
rm -rf "$INSTALL_DIR" "$PLIST_PATH" "$LOG_DIR" 2>/dev/null

# Step 6: Report
echo ""
echo "Uninstall script has been run."
echo "To verify that the AppTimer background process is no longer running, type:"
echo "sudo launchctl list | grep com.ozdaddydaycare.Apptimer_daily_timer"
echo "If you get no output, it means the background process is no longer running and Minecraft is not limited."
echo ""
echo "The following locations have been cleaned:"
echo "- $INSTALL_DIR"
echo "- $PLIST_PATH"
echo "- $LOG_DIR"
echo ""
echo "If you see any error messages above, please check those locations manually and remove any remaining files if necessary."
