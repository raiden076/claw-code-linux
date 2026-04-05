#!/bin/bash
# Claw Code Update Checker
# Monitors upstream repos for new commits and triggers rebuilds

set -e

REPO_DIR="${REPO_DIR:-$HOME/claw-code-linux}"
STATE_DIR="${STATE_DIR:-$REPO_DIR/.update-state}"
LOCK_FILE="$STATE_DIR/check.lock"

# Upstream repos to monitor
CLAW_UPSTREAM="ultraworkers/claw-code"
PROXY_UPSTREAM="router-for-me/CLIProxyAPI"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "Update check already running (PID: $PID)"
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Function to get latest commit from a repo
get_latest_commit() {
    local repo="$1"
    local branch="${2:-main}"
    curl -s "https://api.github.com/repos/$repo/commits/$branch" | grep -o '"sha": "[^"]*"' | head -1 | cut -d'"' -f4
}

# Function to get commit message
get_commit_message() {
    local repo="$1"
    local sha="$2"
    curl -s "https://api.github.com/repos/$repo/commits/$sha" | grep -o '"message": "[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-80
}

# Function to check for updates
check_repo() {
    local name="$1"
    local repo="$2"
    local branch="${3:-main}"
    local state_file="$STATE_DIR/${name}_last_commit"
    
    echo -e "${BLUE}Checking $name ($repo)...${NC}"
    
    # Get current upstream commit
    local current_sha=$(get_latest_commit "$repo" "$branch")
    
    if [ -z "$current_sha" ]; then
        echo -e "${RED}Failed to fetch latest commit for $name${NC}"
        return 1
    fi
    
    # Read last known commit
    local last_sha=""
    if [ -f "$state_file" ]; then
        last_sha=$(cat "$state_file")
    fi
    
    # Compare
    if [ "$current_sha" = "$last_sha" ]; then
        echo -e "${GREEN}✓ $name is up to date (commit: ${current_sha:0:7})${NC}"
        return 1  # No update
    else
        echo -e "${YELLOW}↻ $name has updates!${NC}"
        echo -e "   Last known: ${last_sha:0:7:-'(none)'}"
        echo -e "   Current:    ${current_sha:0:7}"
        
        # Get commit message
        local msg=$(get_commit_message "$repo" "$current_sha")
        echo -e "   Message: $msg"
        
        # Save new state
        echo "$current_sha" > "$state_file"
        
        # Store update info for notification
        echo "$current_sha" > "$STATE_DIR/${name}_update_pending"
        echo "$msg" > "$STATE_DIR/${name}_update_msg"
        
        return 0  # Update available
    fi
}

# Check both repos
echo "========================================"
echo "🔄 Claw Code Update Check"
echo "Started: $(date)"
echo "========================================"
echo ""

CLAW_UPDATED=false
PROXY_UPDATED=false

if check_repo "claw" "$CLAW_UPSTREAM" "main"; then
    CLAW_UPDATED=true
fi
echo ""

if check_repo "proxy" "$PROXY_UPSTREAM" "main"; then
    PROXY_UPDATED=true
fi
echo ""

# If updates found, trigger rebuild
if [ "$CLAW_UPDATED" = true ] || [ "$PROXY_UPDATED" = true ]; then
    echo -e "${YELLOW}Updates detected! Triggering rebuild...${NC}"
    echo ""
    
    # Run the rebuild script
    "$REPO_DIR/scripts/trigger-rebuild.sh"
    
    echo ""
    echo -e "${GREEN}Rebuild triggered successfully!${NC}"
else
    echo -e "${GREEN}All repositories are up to date.${NC}"
fi

echo ""
echo "Finished: $(date)"
