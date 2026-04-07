#!/bin/bash
# Compare automation scripts between Machine 2 and Machine 1 N

set -e

REMOTE_HOST="machine1n"
REMOTE_SCRIPT="~/NCOMM/machine1n-automate.sh"
LOCAL_SCRIPTS_DIR="/Users/nonlineari/Projects/NCOMM"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== NCOMM Automation Script Comparison ===${NC}"
echo ""

# Function: Display script info
show_script_info() {
    local script="$1"
    local location="$2"
    
    echo -e "${BLUE}Script:${NC} $script"
    echo -e "${BLUE}Location:${NC} $location"
    
    if [ -f "$script" ]; then
        echo -e "${BLUE}Size:${NC} $(wc -c < "$script") bytes"
        echo -e "${BLUE}Lines:${NC} $(wc -l < "$script") lines"
        echo -e "${BLUE}Modified:${NC} $(stat -f "%Sm" "$script")"
        echo -e "${BLUE}Functions:${NC}"
        grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$script" | sed 's/().*$//' | sed 's/^/  - /'
    else
        echo -e "${RED}Not found${NC}"
    fi
    echo ""
}

# Function: Compare with remote
compare_with_remote() {
    local local_script="$1"
    local remote_path="$2"
    
    echo -e "${YELLOW}→ Fetching remote script for comparison...${NC}"
    
    # Create temp directory
    local temp_dir=$(mktemp -d)
    local remote_script="$temp_dir/remote_script.sh"
    
    # Fetch remote script
    if scp -q "$REMOTE_HOST:$remote_path" "$remote_script" 2>/dev/null; then
        echo -e "${GREEN}✓ Remote script fetched${NC}"
        echo ""
        
        # Compare sizes
        local local_size=$(wc -c < "$local_script")
        local remote_size=$(wc -c < "$remote_script")
        
        echo -e "${BLUE}Size Comparison:${NC}"
        echo "  Local:  $local_size bytes"
        echo "  Remote: $remote_size bytes"
        echo ""
        
        # Check if identical
        if diff -q "$local_script" "$remote_script" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Scripts are identical${NC}"
        else
            echo -e "${YELLOW}⚠ Scripts differ${NC}"
            echo ""
            echo -e "${BLUE}Differences:${NC}"
            diff -u "$remote_script" "$local_script" | head -50 || true
        fi
    else
        echo -e "${RED}✗ Could not fetch remote script${NC}"
        echo "  Make sure it's deployed to Machine 1 N"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    echo ""
}

# Machine 2 Scripts (Local)
echo -e "${GREEN}=== Machine 2 (Local) Scripts ===${NC}"
echo ""

show_script_info "$LOCAL_SCRIPTS_DIR/setup-ssh-machine1n.sh" "Machine 2"
show_script_info "$LOCAL_SCRIPTS_DIR/automation-machine1n.sh" "Machine 2"
show_script_info "$LOCAL_SCRIPTS_DIR/machine1n-automate.sh" "Machine 2 (for deployment)"
show_script_info "$LOCAL_SCRIPTS_DIR/deploy-to-machine1n.sh" "Machine 2"
show_script_info "$LOCAL_SCRIPTS_DIR/ncomm.sh" "Machine 2"

echo ""
echo -e "${GREEN}=== Machine 1 N (Remote) Scripts ===${NC}"
echo ""

# Check if we can connect
if ! ssh -o ConnectTimeout=5 "$REMOTE_HOST" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to Machine 1 N${NC}"
    echo "  Run ./setup-ssh-machine1n.sh first"
    exit 1
fi

# Check remote scripts
echo -e "${BLUE}Checking remote scripts...${NC}"
ssh "$REMOTE_HOST" "ls -lh ~/NCOMM/*.sh 2>/dev/null || echo 'No scripts found'"
echo ""

# Compare automation script
if [ -f "$LOCAL_SCRIPTS_DIR/machine1n-automate.sh" ]; then
    echo -e "${GREEN}=== Comparing machine1n-automate.sh ===${NC}"
    echo ""
    compare_with_remote "$LOCAL_SCRIPTS_DIR/machine1n-automate.sh" "~/NCOMM/machine1n-automate.sh"
fi

# Summary
echo -e "${GREEN}=== Summary ===${NC}"
echo ""

echo -e "${BLUE}Machine 2 Scripts:${NC}"
echo "  • setup-ssh-machine1n.sh   - Initial SSH setup"
echo "  • automation-machine1n.sh  - Remote command execution"
echo "  • machine1n-automate.sh    - Script to deploy"
echo "  • deploy-to-machine1n.sh   - Deployment tool"
echo "  • ncomm.sh                 - Quick command wrapper"
echo ""

echo -e "${BLUE}Machine 1 N Scripts:${NC}"
echo "  • machine1n-automate.sh    - Runs on Machine 1 N"
echo "    - Setup Project N"
echo "    - Enable SSH"
echo "    - Configure network sharing"
echo "    - Manage SSH keys"
echo ""

echo -e "${BLUE}Script Roles:${NC}"
echo ""
echo -e "${YELLOW}On Machine 2:${NC}"
echo "  1. setup-ssh-machine1n.sh     → Generate keys, configure SSH"
echo "  2. deploy-to-machine1n.sh     → Push automation to Machine 1 N"
echo "  3. automation-machine1n.sh    → Execute remote commands"
echo "  4. ncomm.sh                   → Simplified interface"
echo ""
echo -e "${YELLOW}On Machine 1 N:${NC}"
echo "  1. machine1n-automate.sh      → Local automation tasks"
echo "     • Project setup"
echo "     • Network configuration"
echo "     • SSH management"
echo ""

# Check synchronization
echo -e "${BLUE}Synchronization Status:${NC}"
if ssh "$REMOTE_HOST" "[ -f ~/NCOMM/machine1n-automate.sh ]"; then
    echo -e "  ${GREEN}✓${NC} Machine 1 N has automation script"
else
    echo -e "  ${RED}✗${NC} Machine 1 N missing automation script"
    echo "    Run: ./ncomm.sh deploy"
fi

echo ""
