#!/bin/bash
# Daily check wrapper - runs update checker and handles notifications

REPO_DIR="${REPO_DIR:-$HOME/claw-code-linux}"
STATE_DIR="$REPO_DIR/.update-state"
NOTIFICATION_FILE="$STATE_DIR/notification_pending"

cd "$REPO_DIR"

# Run the update check
echo "Starting daily Claw update check at $(date)"
bash "$REPO_DIR/scripts/update-checker.sh" >> "$STATE_DIR/daily.log" 2>&1

# Check if there's a notification to send
if [ -f "$NOTIFICATION_FILE" ]; then
    echo "Updates found - notification will be sent via Hermes"
    # The notification file contains the message
    # Hermes cron will pick this up and send to WhatsApp
    exit 0
else
    echo "No updates found at $(date)"
    exit 0
fi
