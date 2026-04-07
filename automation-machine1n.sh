#!/bin/bash
# Automation Scripts for Machine 1 N Operations

set -e

REMOTE_HOST="machine1n"
REMOTE_USER="${MACHINE1N_USER:-nonlineari}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Execute command on Machine 1 N
remote_exec() {
    echo -e "${BLUE}→ Executing on Machine 1 N:${NC} $1"
    ssh $REMOTE_HOST "$1"
}

# Function: Copy file to Machine 1 N
remote_copy_to() {
    local src="$1"
    local dest="$2"
    echo -e "${BLUE}→ Copying to Machine 1 N:${NC} $src -> $dest"
    scp "$src" "$REMOTE_HOST:$dest"
}

# Function: Copy file from Machine 1 N
remote_copy_from() {
    local src="$1"
    local dest="$2"
    echo -e "${BLUE}→ Copying from Machine 1 N:${NC} $src -> $dest"
    scp "$REMOTE_HOST:$src" "$dest"
}

# Function: Sync directory to Machine 1 N
remote_sync_to() {
    local src="$1"
    local dest="$2"
    echo -e "${BLUE}→ Syncing to Machine 1 N:${NC} $src -> $dest"
    rsync -avz --progress "$src" "$REMOTE_HOST:$dest"
}

# Function: Sync directory from Machine 1 N
remote_sync_from() {
    local src="$1"
    local dest="$2"
    echo -e "${BLUE}→ Syncing from Machine 1 N:${NC} $src -> $dest"
    rsync -avz --progress "$REMOTE_HOST:$src" "$dest"
}

# Function: Get system info from Machine 1 N
remote_sysinfo() {
    echo -e "${GREEN}=== Machine 1 N System Information ===${NC}"
    remote_exec "sw_vers && echo '' && uname -a && echo '' && uptime"
}

# Function: Check disk space on Machine 1 N
remote_diskspace() {
    echo -e "${GREEN}=== Machine 1 N Disk Space ===${NC}"
    remote_exec "df -h | grep -E '(Filesystem|/dev/disk)'"
}

# Function: Interactive SSH session
remote_shell() {
    echo -e "${GREEN}=== Opening SSH session to Machine 1 N ===${NC}"
    ssh $REMOTE_HOST
}

# Function: Run script on Machine 1 N
remote_run_script() {
    local script="$1"
    if [ ! -f "$script" ]; then
        echo "Error: Script $script not found"
        return 1
    fi
    echo -e "${BLUE}→ Running script on Machine 1 N:${NC} $script"
    ssh $REMOTE_HOST 'bash -s' < "$script"
}

# Function: Check SSH connection
check_connection() {
    echo -e "${BLUE}→ Testing connection to Machine 1 N...${NC}"
    if ssh -o ConnectTimeout=5 $REMOTE_HOST "echo 'Connection successful'" 2>/dev/null; then
        echo -e "${GREEN}✓ Connection OK${NC}"
        return 0
    else
        echo "✗ Connection failed"
        return 1
    fi
}

# Main script logic
case "${1:-help}" in
    exec)
        remote_exec "$2"
        ;;
    copy-to)
        remote_copy_to "$2" "$3"
        ;;
    copy-from)
        remote_copy_from "$2" "$3"
        ;;
    sync-to)
        remote_sync_to "$2" "$3"
        ;;
    sync-from)
        remote_sync_from "$2" "$3"
        ;;
    sysinfo)
        remote_sysinfo
        ;;
    disk)
        remote_diskspace
        ;;
    shell)
        remote_shell
        ;;
    run-script)
        remote_run_script "$2"
        ;;
    check)
        check_connection
        ;;
    help|*)
        cat << EOF
${GREEN}NCOMM - Machine 1 N Automation${NC}

Usage: $0 <command> [arguments]

Commands:
  exec <cmd>              Execute command on Machine 1 N
  copy-to <src> <dest>    Copy file to Machine 1 N
  copy-from <src> <dest>  Copy file from Machine 1 N
  sync-to <src> <dest>    Sync directory to Machine 1 N (rsync)
  sync-from <src> <dest>  Sync directory from Machine 1 N (rsync)
  sysinfo                 Get system information
  disk                    Check disk space
  shell                   Open interactive SSH session
  run-script <file>       Run local script on Machine 1 N
  check                   Test SSH connection
  help                    Show this help

Examples:
  $0 exec "ls -la ~"
  $0 copy-to ./file.txt ~/remote/file.txt
  $0 sync-to ./NCOMM/ ~/Projects/NCOMM/
  $0 sysinfo
  $0 shell

EOF
        ;;
esac
