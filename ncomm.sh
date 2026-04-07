#!/bin/bash
# NCOMM - Quick command wrapper for Machine 1 N operations

set -e

REMOTE_HOST="machine1n"
REMOTE_SCRIPT="~/NCOMM/machine1n-automate.sh"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

case "${1:-help}" in
    deploy)
        ./deploy-to-machine1n.sh
        ;;
    
    setup)
        echo -e "${BLUE}→${NC} Running setup on Machine 1 N..."
        MACHINE2_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
        ssh $REMOTE_HOST "export MACHINE2_IP=$MACHINE2_IP; $REMOTE_SCRIPT setup"
        ;;
    
    status)
        echo -e "${BLUE}→${NC} Getting Machine 1 N status..."
        ssh $REMOTE_HOST "$REMOTE_SCRIPT status"
        ;;
    
    info)
        echo -e "${BLUE}→${NC} Getting Machine 1 N network info..."
        ssh $REMOTE_HOST "$REMOTE_SCRIPT info"
        ;;
    
    project)
        echo -e "${BLUE}→${NC} Setting up Project N on Machine 1 N..."
        ssh $REMOTE_HOST "$REMOTE_SCRIPT project"
        ;;
    
    sync-to)
        if [ -z "$2" ]; then
            echo "Usage: $0 sync-to <local-path>"
            exit 1
        fi
        echo -e "${BLUE}→${NC} Syncing to Machine 1 N Project N..."
        ./automation-machine1n.sh sync-to "$2" ~/Projects/N/
        ;;
    
    sync-from)
        if [ -z "$2" ]; then
            echo "Usage: $0 sync-from <local-path>"
            exit 1
        fi
        echo -e "${BLUE}→${NC} Syncing from Machine 1 N Project N..."
        ./automation-machine1n.sh sync-from ~/Projects/N/ "$2"
        ;;
    
    shell)
        echo -e "${GREEN}=== Opening shell on Machine 1 N ===${NC}"
        ssh $REMOTE_HOST
        ;;
    
    check)
        echo -e "${BLUE}→${NC} Checking connection..."
        ./automation-machine1n.sh check
        ;;
    
    help|*)
        cat << EOF
${GREEN}NCOMM - Network Communication Tool${NC}

Quick commands for Machine 1 N automation:

  ${BLUE}Setup & Deploy:${NC}
    deploy          Deploy automation script to Machine 1 N
    setup           Run full setup on Machine 1 N
    check           Test SSH connection

  ${BLUE}Information:${NC}
    status          Show Machine 1 N status
    info            Display network information

  ${BLUE}Project N:${NC}
    project         Initialize Project N on Machine 1 N
    sync-to <path>  Sync local directory to Machine 1 N Project N
    sync-from <path> Sync from Machine 1 N Project N to local

  ${BLUE}Advanced:${NC}
    shell           Open SSH shell on Machine 1 N

Examples:
  $0 deploy                    # First time setup
  $0 status                    # Check Machine 1 N
  $0 sync-to ./myproject       # Upload project
  $0 shell                     # Interactive session

Full automation available via:
  ./automation-machine1n.sh <command>

EOF
        ;;
esac
