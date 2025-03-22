#!/bin/bash

# Set variables
LOG_DIR="/var/log/clamav"
DAILY_SCAN_LOG="$LOG_DIR/daily_scan.log"   # Log file for the daily scan
SCAN_LOGS="$LOG_DIR/scan_logs.log"          # Log file for all scan logs
USERNAME=$(who | awk '{print $1}' | head -n 1)    # Get the username of the currently logged-in user to send notification

# Run ClamAV scan with priority and I/O niceness settings
nice -n 19 ionice -c 3 clamscan --suppress-ok-results --recursive=yes --cross-fs=no / > "$DAILY_SCAN_LOG" 2>&1
result=$?

# Define tee command for appending to scan logs
TEE_SCAN="tee -a $SCAN_LOGS"

# Function to send desktop notification
send_notification() {
    local urgency="$1"
    local title="$2"
    local message="$3"
    
    # Use notify-send to send a desktop notification to the user
    sudo -u "$USERNAME" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$USERNAME")/bus notify-send --urgency="$urgency" "$title" "$message" 2>&1
}

# Check if a virus was found
if [ "$result" -eq 1 ]; then
    echo "---------------\n- VIRUS FOUND -\n---------------" | $TEE_SCAN
    tail -n 11 "$DAILY_SCAN_LOG" | $TEE_SCAN
    grep FOUND "$DAILY_SCAN_LOG" | $TEE_SCAN

    # Get the message about the found virus
    MESSAGE=$(grep FOUND "$DAILY_SCAN_LOG")

    # Send a critical desktop notification about the found virus
    send_notification "critical" "ClamAV - VIRUS FOUND" "$MESSAGE"
fi

# Check if there were problems running ClamAV
if [ "$result" -gt 1 ]; then
    echo "---------------------------------------\n- Problems running ClamAV, check logs -\n---------------------------------------\n" | $TEE_SCAN
    cat "$DAILY_SCAN_LOG" | $TEE_SCAN

    # Send a critical desktop notification about the problems running ClamAV
    send_notification "critical" "ClamAV" "Problems running ClamAV, check logs"
fi
