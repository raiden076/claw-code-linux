#!/bin/bash
# Trigger rebuild of Claw binaries when upstream updates are detected

set -e

REPO_DIR="${REPO_DIR:-$HOME/claw-code-linux}"
STATE_DIR="${STATE_DIR:-$REPO_DIR/.update-state}"
LOG_FILE="$STATE_DIR/rebuild.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Upstream repos
CLAW_UPSTREAM="ultraworkers/claw-code"
PROXY_UPSTREAM="router-for-me/CLIProxyAPI"

# Our fork
OUR_REPO="raiden076/claw-code-linux"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send WhatsApp notification via Hermes
send_whatsapp_notification() {
    local message="$1"
    
    # Use Hermes proactive_nudge to send to WhatsApp
    # This will be called via the Hermes API
    echo "$message" > "$STATE_DIR/notification_pending"
    
    log "WhatsApp notification queued"
}

# Function to sync upstream changes for Claw
sync_claw_upstream() {
    log "Syncing Claw upstream changes..."
    
    cd "$REPO_DIR"
    
    # Add upstream remote if not exists
    if ! git remote | grep -q "^upstream$"; then
        git remote add upstream "https://github.com/$CLAW_UPSTREAM.git"
        log "Added upstream remote"
    fi
    
    # Fetch upstream
    git fetch upstream
    
    # Check if there are changes
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse upstream/main)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log "Merging upstream changes..."
        git merge upstream/main --no-edit || {
            log "Merge conflict detected, attempting rebase..."
            git rebase upstream/main || {
                log "ERROR: Rebase failed, manual intervention needed"
                send_whatsapp_notification "⚠️ Claw Update Error: Rebase failed for claw-code. Manual intervention needed."
                return 1
            }
        }
        
        # Push to our fork
        git push origin main
        log "Upstream changes synced and pushed"
        
        # Create new version tag
        NEW_VERSION=$(date +'v0.1.%Y%m%d')
        git tag "$NEW_VERSION"
        git push origin "$NEW_VERSION"
        log "Created and pushed tag: $NEW_VERSION"
        
        echo "$NEW_VERSION"
        return 0
    else
        log "No upstream changes to sync"
        return 1
    fi
}

# Function to check CLIProxyAPI for new releases
check_proxy_release() {
    log "Checking CLIProxyAPI releases..."
    
    # Get latest release info
    local latest_url="https://api.github.com/repos/$PROXY_UPSTREAM/releases/latest"
    local release_info=$(curl -s "$latest_url")
    local latest_tag=$(echo "$release_info" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    # Read last known release
    local state_file="$STATE_DIR/proxy_last_release"
    local last_tag=""
    if [ -f "$state_file" ]; then
        last_tag=$(cat "$state_file")
    fi
    
    if [ "$latest_tag" != "$last_tag" ]; then
        log "New CLIProxyAPI release: $latest_tag (was: ${last_tag:-none})"
        echo "$latest_tag" > "$state_file"
        echo "$latest_tag"
        return 0
    else
        log "CLIProxyAPI up to date: $latest_tag"
        return 1
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   🔄 Triggering Rebuild${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

UPDATES_FOUND=false
UPDATE_MSG=""

# Check and sync Claw
echo -e "${YELLOW}📦 Processing Claw updates...${NC}"
if [ -f "$STATE_DIR/claw_update_pending" ]; then
    NEW_VERSION=$(sync_claw_upstream)
    if [ $? -eq 0 ]; then
        UPDATES_FOUND=true
        CLAW_SHA=$(cat "$STATE_DIR/claw_update_pending")
        CLAW_MSG=$(cat "$STATE_DIR/claw_update_msg" 2>/dev/null || echo "No message")
        UPDATE_MSG="🦀 Claw: $NEW_VERSION
└─ ${CLAW_SHA:0:7}: $CLAW_MSG"
        rm -f "$STATE_DIR/claw_update_pending" "$STATE_DIR/claw_update_msg"
    fi
else
    echo -e "${GREEN}No Claw updates pending${NC}"
fi
echo ""

# Check CLIProxyAPI
echo -e "${YELLOW}🌐 Processing CLIProxyAPI updates...${NC}"
PROXY_VERSION=$(check_proxy_release)
if [ $? -eq 0 ]; then
    UPDATES_FOUND=true
    if [ -n "$UPDATE_MSG" ]; then
        UPDATE_MSG="$UPDATE_MSG

🌐 CLIProxyAPI: $PROXY_VERSION"
    else
        UPDATE_MSG="🌐 CLIProxyAPI: $PROXY_VERSION"
    fi
else
    echo -e "${GREEN}No CLIProxyAPI updates pending${NC}"
fi
echo ""

# Send notification if updates were processed
if [ "$UPDATES_FOUND" = true ]; then
    echo -e "${GREEN}✅ Updates processed successfully!${NC}"
    
    # Create notification message
    NOTIFICATION="🔄 *Claw Code Updates Available!*

$UPDATE_MSG

📦 New binaries are being built by GitHub Actions.
⏱️  ETA: ~5-10 minutes

Run the following to update:
\`curl -sSL https://raw.githubusercontent.com/raiden076/claw-code-linux/main/install-claw.sh | bash -s -- update\`

Or wait for auto-notification when build completes."
    
    send_whatsapp_notification "$NOTIFICATION"
    
    echo ""
    echo -e "${BLUE}📱 WhatsApp notification sent${NC}"
else
    echo -e "${YELLOW}No updates to process${NC}"
fi

echo ""
echo -e "${BLUE}Finished: $(date)${NC}"
