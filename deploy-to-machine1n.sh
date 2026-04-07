#!/bin/bash
# Deploy automation script to Machine 1 N and execute it

set -e

REMOTE_HOST="machine1n"
SCRIPT_NAME="machine1n-automate.sh"
REMOTE_PATH="~/NCOMM"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}=== Deploying to Machine 1 N ===${NC}"
echo ""

# Check connection first
echo -e "${BLUE}→${NC} Testing connection..."
if ! ssh -o ConnectTimeout=5 $REMOTE_HOST "echo 'Connected'" 2>/dev/null; then
    echo "✗ Cannot connect to Machine 1 N"
    echo "  Run ./setup-ssh-machine1n.sh first"
    exit 1
fi
echo -e "${GREEN}✓${NC} Connected"

# Get Machine 2's IP to pass to Machine 1 N
echo ""
echo -e "${BLUE}→${NC} Getting Machine 2 IP address..."
MACHINE2_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "Machine 2 IP: $MACHINE2_IP"

# Create remote directory
echo ""
echo -e "${BLUE}→${NC} Creating remote directory..."
ssh $REMOTE_HOST "mkdir -p $REMOTE_PATH"

# Copy automation script
echo -e "${BLUE}→${NC} Copying automation script..."
scp "$SCRIPT_NAME" "$REMOTE_HOST:$REMOTE_PATH/$SCRIPT_NAME"

# Make it executable
echo -e "${BLUE}→${NC} Making script executable..."
ssh $REMOTE_HOST "chmod +x $REMOTE_PATH/$SCRIPT_NAME"

echo ""
echo -e "${GREEN}✓ Deployment complete!${NC}"
echo ""

# Ask if user wants to run setup
read -p "Run setup on Machine 1 N now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}=== Running setup on Machine 1 N ===${NC}"
    echo ""
    ssh $REMOTE_HOST "export MACHINE2_IP=$MACHINE2_IP; $REMOTE_PATH/$SCRIPT_NAME setup"
    echo ""
    echo -e "${GREEN}✓ Setup completed on Machine 1 N${NC}"
else
    echo ""
    echo "To run setup later, execute:"
    echo "  ./automation-machine1n.sh exec 'cd ~/NCOMM && ./machine1n-automate.sh setup'"
fi

echo ""
echo "Available commands:"
echo "  ./automation-machine1n.sh exec '~/NCOMM/machine1n-automate.sh status'"
echo "  ./automation-machine1n.sh exec '~/NCOMM/machine1n-automate.sh info'"
