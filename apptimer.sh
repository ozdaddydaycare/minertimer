#!/bin/zsh

# Configuration file
CONFIG_FILE="/var/lib/apptimer/config.txt"

# Default time limits in seconds
DEFAULT_TIME_LIMIT=1800
DEFAULT_WEEKEND_TIME_LIMIT=3600
DEFAULT_BUFFER_TIME=300

# Directory and file to store total played time for the day
LOG_DIRECTORY="/var/lib/apptimer"
LOG_FILE="${LOG_DIRECTORY}/apptimer_playtime.log"

# Create the directory (don't throw error if already exists)
mkdir -p $LOG_DIRECTORY

# Function to read text config
read_config() {
    declare -A app_limits
    while IFS=':' read -r app limit || [[ -n "$app" ]]; do
        app=$(echo "$app" | tr -d '[:space:]')
        limit=$(echo "$limit" | tr -d '[:space:]')
        if [[ -n "$app" && -n "$limit" ]]; then
            app_limits[$app]=$limit
        fi
    done < "$CONFIG_FILE"

    # Use default values if not set in config
    TIME_LIMIT=${app_limits[default]:-$DEFAULT_TIME_LIMIT}
    WEEKEND_TIME_LIMIT=${app_limits[weekend]:-$DEFAULT_WEEKEND_TIME_LIMIT}
    BUFFER_TIME=${app_limits[buffer]:-$DEFAULT_BUFFER_TIME}
    APPS=(${!app_limits[@]})
    APPS=(${APPS[@]/default})  # Remove 'default' from APPS array
    APPS=(${APPS[@]/weekend})  # Remove 'weekend' from APPS array
    APPS=(${APPS[@]/buffer})   # Remove 'buffer' from APPS array
}

# Initial config read
if [ -f "$CONFIG_FILE" ]; then
    read_config
else
    echo "Config file not found. Using default values."
    TIME_LIMIT=$DEFAULT_TIME_LIMIT
    WEEKEND_TIME_LIMIT=$DEFAULT_WEEKEND_TIME_LIMIT
    BUFFER_TIME=$DEFAULT_BUFFER_TIME
    APPS=("Minecraft" "firefox" "chrome" "safari")
fi

# Get the current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Initialize or read log file
if [ -f "$LOG_FILE" ]; then
    LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
    TOTAL_PLAYED_TIME=$(tail -n 1 "$LOG_FILE")
else
    LAST_PLAY_DATE="$CURRENT_DATE"
    TOTAL_PLAYED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
fi

# Reset playtime if it's a new day
if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
    TOTAL_PLAYED_TIME=0
    echo "$CURRENT_DATE" > "$LOG_FILE"
    echo "0" >> "$LOG_FILE"
fi

# Function to check if any monitored app is running
check_apps_running() {
    for app in "${APPS[@]}"; do
        if pgrep -i "$app" > /dev/null; then
            return 0  # At least one app is running
        fi
    done
    return 1  # No monitored apps are running
}

# Main loop
BUFFER_START_TIME=0
IN_BUFFER=false

while true; do
    # Re-read config file to check for updates
    if [ -f "$CONFIG_FILE" ]; then
        read_config
    fi
    
    if check_apps_running; then
        current_limit=$TIME_LIMIT
        if [[ $(date +%u) -gt 5 ]]; then
            current_limit=$WEEKEND_TIME_LIMIT
        fi

        # Check if we've entered buffer time
        if ((TOTAL_PLAYED_TIME >= current_limit)) && ! $IN_BUFFER; then
            IN_BUFFER=true
            BUFFER_START_TIME=$TOTAL_PLAYED_TIME
            osascript -e 'display notification "Time limit reached. Buffer time started." with title "Time Limit Reached"'
            say "Time limit reached. Buffer time started."
        fi

        # Buffer time logic
        if $IN_BUFFER; then
            buffer_elapsed=$((TOTAL_PLAYED_TIME - BUFFER_START_TIME))
            if ((buffer_elapsed >= BUFFER_TIME)); then
                for app in "${APPS[@]}"; do
                    pkill -i "$app"
                done
                echo "Monitored apps have been closed after buffer time expired."
                osascript -e 'display notification "Buffer time expired" with title "Apps Closed"'
                afplay /System/Library/Sounds/Glass.aiff
                IN_BUFFER=false
            elif ((buffer_elapsed % 60 == 0)); then  # Warning every minute during buffer
                remaining=$((BUFFER_TIME - buffer_elapsed))
                osascript -e "display notification \"$remaining seconds remaining in buffer time\" with title \"Buffer Time Running\""
                say "$remaining seconds remaining in buffer time"
            fi
        elif ((TOTAL_PLAYED_TIME >= current_limit - 300)) && [ "$DISPLAY_5_MIN_WARNING" = true ]; then
            osascript -e 'display notification "5 minutes until time limit" with title "Time Limit Warning"'
            say "5 minutes until time limit"
            DISPLAY_5_MIN_WARNING=false
        elif ((TOTAL_PLAYED_TIME >= current_limit - 60)) && [ "$DISPLAY_1_MIN_WARNING" = true ]; then
            osascript -e 'display notification "1 minute until time limit" with title "Time Limit Warning"'
            say "1 minute until time limit"
            DISPLAY_1_MIN_WARNING=false
        fi
        
        # Increment playtime
        sleep 20
        TOTAL_PLAYED_TIME=$((TOTAL_PLAYED_TIME + 20))
        sed -i '' "$ s/.*/$TOTAL_PLAYED_TIME/" "$LOG_FILE"
    else
        sleep 10
    fi

    # Check for new day
    CURRENT_DATE=$(date +%Y-%m-%d)
    LAST_PLAY_DATE=$(head -n 1 "$LOG_FILE")
    if [ "$LAST_PLAY_DATE" != "$CURRENT_DATE" ]; then
        TOTAL_PLAYED_TIME=0
        DISPLAY_5_MIN_WARNING=true
        DISPLAY_1_MIN_WARNING=true
        IN_BUFFER=false
        echo "$CURRENT_DATE" > "$LOG_FILE"
        echo "0" >> "$LOG_FILE"
        echo "RESET DATE - $CURRENT_DATE"
    fi
done
