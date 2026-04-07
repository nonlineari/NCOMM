#!/bin/bash
# Machine 1 N Automation: Project N Connection & Network Sharing
# This script runs ON Machine 1 N to automate tasks

set -e

# Configuration
PROJECT_NAME="N"
PROJECTS_DIR="$HOME/Projects"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
MACHINE2_IP="${MACHINE2_IP:-}"  # Set this to Machine 2's IP
SSH_PORT="${SSH_PORT:-22}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function: Create/verify Project N directory
setup_project_n() {
    log_info "Setting up Project N..."
    
    if [ ! -d "$PROJECT_PATH" ]; then
        mkdir -p "$PROJECT_PATH"
        log_success "Created project directory: $PROJECT_PATH"
    else
        log_success "Project directory exists: $PROJECT_PATH"
    fi
    
    # Create initial structure if empty
    if [ -z "$(ls -A $PROJECT_PATH)" ]; then
        mkdir -p "$PROJECT_PATH"/{src,config,data,logs}
        touch "$PROJECT_PATH/README.md"
        log_success "Initialized project structure"
    fi
}

# Function: Get current IP address
get_current_ip() {
    local ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
    echo "$ip"
}

# Function: Enable SSH (Remote Login)
enable_ssh() {
    log_info "Configuring SSH/Remote Login..."
    
    # Check current state
    local ssh_status=$(sudo systemsetup -getremotelogin 2>/dev/null || echo "Unknown")
    
    if [[ "$ssh_status" == *"On"* ]]; then
        log_success "Remote Login already enabled"
    else
        log_info "Enabling Remote Login..."
        sudo systemsetup -setremotelogin on
        log_success "Remote Login enabled"
    fi
    
    # Verify SSH is running
    if pgrep -x "sshd" > /dev/null; then
        log_success "SSH daemon is running"
    else
        log_warn "SSH daemon not detected, may need manual start"
    fi
}

# Function: Configure network sharing to same IP
configure_network_sharing() {
    log_info "Configuring network sharing preferences..."
    
    local current_ip=$(get_current_ip)
    log_info "Current IP: $current_ip"
    
    # Ensure SSH is bound to all interfaces (default behavior)
    if [ -f /etc/ssh/sshd_config ]; then
        # Check if ListenAddress is set
        if grep -q "^ListenAddress" /etc/ssh/sshd_config; then
            log_info "SSH listening configuration found"
            sudo grep "^ListenAddress" /etc/ssh/sshd_config
        else
            log_success "SSH configured to listen on all interfaces (default)"
        fi
    fi
    
    # Display network interfaces
    log_info "Active network interfaces:"
    ifconfig | grep -E "^[a-z]|inet " | grep -v "inet6"
    
    # Check firewall status
    local firewall_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "Unknown")
    log_info "Firewall status: $firewall_status"
    
    if [[ "$firewall_status" == *"enabled"* ]]; then
        log_warn "Firewall is enabled - ensuring SSH is allowed"
        # SSH should be allowed by default when Remote Login is enabled
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd 2>/dev/null || true
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/sbin/sshd 2>/dev/null || true
    fi
}

# Function: Setup SSH keys from Machine 2
setup_ssh_keys() {
    log_info "Checking SSH key configuration..."
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    if [ -f ~/.ssh/authorized_keys ]; then
        local key_count=$(wc -l < ~/.ssh/authorized_keys)
        log_success "Found $key_count authorized key(s)"
    else
        log_warn "No authorized_keys file found"
        log_info "Create it with: echo 'PUBLIC_KEY' >> ~/.ssh/authorized_keys"
    fi
    
    chmod 600 ~/.ssh/authorized_keys 2>/dev/null || true
}

# Function: Test connection back to Machine 2
test_machine2_connection() {
    if [ -z "$MACHINE2_IP" ]; then
        log_warn "MACHINE2_IP not set, skipping connection test"
        return 0
    fi
    
    log_info "Testing connection to Machine 2 ($MACHINE2_IP)..."
    
    if ping -c 1 -W 2 "$MACHINE2_IP" > /dev/null 2>&1; then
        log_success "Machine 2 is reachable at $MACHINE2_IP"
    else
        log_error "Cannot reach Machine 2 at $MACHINE2_IP"
        return 1
    fi
}

# Function: Create network info file
create_network_info() {
    local current_ip=$(get_current_ip)
    local hostname=$(hostname)
    
    cat > "$PROJECT_PATH/network-info.txt" << EOF
Machine 1 N Network Information
Generated: $(date)

Hostname: $hostname
IP Address: $current_ip
SSH Port: $SSH_PORT
Project Path: $PROJECT_PATH

SSH Connection Command:
  ssh $(whoami)@$current_ip

From Machine 2, use:
  ./automation-machine1n.sh check
  ./automation-machine1n.sh exec "cd $PROJECT_PATH && ls -la"
EOF
    
    log_success "Network info saved to $PROJECT_PATH/network-info.txt"
    cat "$PROJECT_PATH/network-info.txt"
}

# Function: Display status
show_status() {
    echo ""
    echo -e "${GREEN}=== Machine 1 N Status ===${NC}"
    echo ""
    echo "Hostname:     $(hostname)"
    echo "IP Address:   $(get_current_ip)"
    echo "SSH Port:     $SSH_PORT"
    echo "Project Path: $PROJECT_PATH"
    echo "Remote Login: $(sudo systemsetup -getremotelogin 2>/dev/null | grep -o 'On\|Off')"
    echo ""
    echo -e "${GREEN}=== Project N ===${NC}"
    if [ -d "$PROJECT_PATH" ]; then
        echo "Status:       Ready"
        echo "Contents:     $(ls -1 $PROJECT_PATH 2>/dev/null | wc -l | tr -d ' ') items"
    else
        echo "Status:       Not initialized"
    fi
    echo ""
}

# Main execution
main() {
    echo -e "${GREEN}=== Machine 1 N Automation ===${NC}"
    echo ""
    
    case "${1:-setup}" in
        setup)
            log_info "Running full setup..."
            setup_project_n
            enable_ssh
            configure_network_sharing
            setup_ssh_keys
            create_network_info
            show_status
            log_success "Setup complete!"
            ;;
        
        project)
            setup_project_n
            ;;
        
        ssh)
            enable_ssh
            ;;
        
        network)
            configure_network_sharing
            ;;
        
        keys)
            setup_ssh_keys
            ;;
        
        test)
            test_machine2_connection
            ;;
        
        status)
            show_status
            ;;
        
        info)
            create_network_info
            ;;
        
        *)
            cat << EOF
${GREEN}Machine 1 N Automation${NC}

Usage: $0 [command]

Commands:
  setup     Run full setup (default)
  project   Setup Project N directory
  ssh       Enable SSH/Remote Login
  network   Configure network sharing
  keys      Setup SSH keys
  test      Test connection to Machine 2
  status    Show current status
  info      Display network information

Environment Variables:
  MACHINE2_IP   IP address of Machine 2 (for testing)
  SSH_PORT      SSH port (default: 22)

EOF
            ;;
    esac
}

main "$@"
