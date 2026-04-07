#!/bin/bash

# WiFi Master-Slave Network Simulation
# Uses native macOS /Applications/Utilities tools for machine-to-machine communication
# Based on NCOMM architecture for WiFi topology

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MASTER_HOST="${MASTER_HOST:-$(hostname)}"
SLAVE_HOST="${SLAVE_HOST:-machine1n.local}"
WIFI_INTERFACE="${WIFI_INTERFACE:-en0}"
PING_COUNT=3
MONITORING_DURATION=10

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  WiFi Master-Slave Network Simulation            ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Detect role based on network topology
detect_role() {
    print_status "Detecting machine role..."
    
    # Check if we can reach the slave (we are master)
    if ping -c 1 -W 1000 "$SLAVE_HOST" &>/dev/null; then
        echo "master"
    else
        echo "slave"
    fi
}

# Get WiFi network information
get_wifi_info() {
    print_status "Gathering WiFi network information..."
    
    # Get SSID
    SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " SSID:" | awk '{print $2}')
    
    # Get IP address
    IP_ADDR=$(ifconfig "$WIFI_INTERFACE" | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    
    # Get MAC address
    MAC_ADDR=$(ifconfig "$WIFI_INTERFACE" | grep ether | awk '{print $2}')
    
    # Get BSSID (router MAC)
    BSSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " BSSID:" | awk '{print $2}')
    
    # Get signal strength
    RSSI=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep "agrCtlRSSI:" | awk '{print $2}')
    
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "WiFi Network Configuration"
    echo "═══════════════════════════════════════════════════"
    echo "  SSID:           $SSID"
    echo "  IP Address:     $IP_ADDR"
    echo "  MAC Address:    $MAC_ADDR"
    echo "  Router (BSSID): $BSSID"
    echo "  Signal (RSSI):  $RSSI dBm"
    echo "═══════════════════════════════════════════════════"
}

# Scan for other machines on network using Bonjour/mDNS
scan_network() {
    print_status "Scanning for SSH-enabled machines on WiFi network (Bonjour)..."
    
    echo ""
    echo "Available SSH services:"
    timeout 5 dns-sd -B _ssh._tcp local. 2>/dev/null | grep -v "Browsing" | head -10 &
    sleep 3
    kill %1 2>/dev/null || true
    echo ""
}

# Test connection to slave (master mode)
test_slave_connection() {
    local slave=$1
    print_status "Testing connection to slave: $slave"
    
    echo ""
    echo "─────────────────────────────────────────────"
    echo "PING Test"
    echo "─────────────────────────────────────────────"
    
    if ping -c "$PING_COUNT" "$slave"; then
        print_success "Slave is reachable via WiFi"
        
        # Get latency stats
        LATENCY=$(ping -c "$PING_COUNT" "$slave" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
        echo ""
        print_success "Average latency: ${LATENCY}ms"
        
        return 0
    else
        print_error "Cannot reach slave at $slave"
        return 1
    fi
}

# Test SSH connection
test_ssh_connection() {
    local slave=$1
    print_status "Testing SSH port accessibility..."
    
    echo ""
    echo "─────────────────────────────────────────────"
    echo "SSH Port Test (TCP 22)"
    echo "─────────────────────────────────────────────"
    
    if nc -z -w 3 "$slave" 22 2>/dev/null; then
        print_success "SSH port 22 is open on $slave"
        
        # Attempt SSH connection if configured
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no machine1n "echo ''" 2>/dev/null; then
            print_success "SSH key authentication working"
        else
            print_warning "SSH port open but key auth not configured (run ./setup-ssh-machine1n.sh)"
        fi
        return 0
    else
        print_error "SSH port 22 not accessible on $slave"
        return 1
    fi
}

# Monitor network traffic (Activity Monitor equivalent)
monitor_network_traffic() {
    print_status "Monitoring network traffic on $WIFI_INTERFACE (${MONITORING_DURATION}s)..."
    
    echo ""
    echo "─────────────────────────────────────────────"
    echo "Network Traffic Monitor"
    echo "─────────────────────────────────────────────"
    echo "Press Ctrl+C to stop early"
    echo ""
    
    # Get initial stats
    INITIAL_RX=$(netstat -ibn | grep "$WIFI_INTERFACE" | head -1 | awk '{print $7}')
    INITIAL_TX=$(netstat -ibn | grep "$WIFI_INTERFACE" | head -1 | awk '{print $10}')
    
    sleep "$MONITORING_DURATION"
    
    # Get final stats
    FINAL_RX=$(netstat -ibn | grep "$WIFI_INTERFACE" | head -1 | awk '{print $7}')
    FINAL_TX=$(netstat -ibn | grep "$WIFI_INTERFACE" | head -1 | awk '{print $10}')
    
    # Calculate throughput
    RX_BYTES=$((FINAL_RX - INITIAL_RX))
    TX_BYTES=$((FINAL_TX - INITIAL_TX))
    RX_RATE=$((RX_BYTES / MONITORING_DURATION))
    TX_RATE=$((TX_BYTES / MONITORING_DURATION))
    
    echo "  Received:    $(numfmt --to=iec-i --suffix=B $RX_BYTES) ($RX_RATE B/s)"
    echo "  Transmitted: $(numfmt --to=iec-i --suffix=B $TX_BYTES) ($TX_RATE B/s)"
    echo ""
}

# Display routing table
show_routing() {
    print_status "Network routing configuration..."
    
    echo ""
    echo "─────────────────────────────────────────────"
    echo "Active Routes"
    echo "─────────────────────────────────────────────"
    netstat -rn | grep -E "Destination|default|192.168|10.0"
    echo ""
}

# Show ARP table (devices on same network)
show_arp_table() {
    print_status "Discovering devices on WiFi network (ARP)..."
    
    echo ""
    echo "─────────────────────────────────────────────"
    echo "ARP Table (Layer 2 Neighbors)"
    echo "─────────────────────────────────────────────"
    arp -a | grep -v incomplete
    echo ""
}

# Master mode operations
run_master() {
    print_header
    print_success "Running as MASTER"
    echo "  Master Host: $MASTER_HOST"
    echo "  Slave Host:  $SLAVE_HOST"
    echo ""
    
    # Get WiFi info
    get_wifi_info
    
    # Scan network
    scan_network
    
    # Test slave connection
    if test_slave_connection "$SLAVE_HOST"; then
        test_ssh_connection "$SLAVE_HOST"
    fi
    
    # Show network topology
    show_routing
    show_arp_table
    
    # Monitor traffic
    monitor_network_traffic
    
    echo ""
    print_success "Master simulation complete"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "Next Steps:"
    echo "═══════════════════════════════════════════════════"
    echo "  1. Run on slave: ssh $SLAVE_HOST \"$0 slave\""
    echo "  2. Use NCOMM: ./ncomm.sh status"
    echo "  3. Deploy automation: ./ncomm.sh deploy"
    echo "═══════════════════════════════════════════════════"
    echo ""
}

# Slave mode operations
run_slave() {
    print_header
    print_success "Running as SLAVE"
    echo "  This machine: $(hostname)"
    echo ""
    
    # Get WiFi info
    get_wifi_info
    
    # Check if SSH is enabled
    print_status "Checking SSH server status..."
    if sudo systemsetup -getremotelogin | grep -q "On"; then
        print_success "Remote Login (SSH) is enabled"
    else
        print_error "Remote Login (SSH) is disabled"
        echo ""
        print_warning "To enable: System Settings → General → Sharing → Remote Login"
        print_warning "Or run: sudo systemsetup -setremotelogin on"
    fi
    
    # Show who can connect
    echo ""
    print_status "Authorized SSH keys:"
    if [ -f ~/.ssh/authorized_keys ]; then
        grep -c "^ssh-" ~/.ssh/authorized_keys 2>/dev/null || echo "0"
    else
        echo "  No authorized_keys file found"
        print_warning "Run setup on master: ./setup-ssh-machine1n.sh"
    fi
    
    # Show network topology
    show_routing
    show_arp_table
    
    # Monitor traffic
    monitor_network_traffic
    
    echo ""
    print_success "Slave simulation complete"
    echo ""
}

# Interactive mode
run_interactive() {
    print_header
    
    echo "Select mode:"
    echo "  1) Master (this machine controls slave)"
    echo "  2) Slave (this machine is controlled)"
    echo "  3) Auto-detect"
    echo ""
    read -p "Choice [1-3]: " choice
    
    case $choice in
        1)
            run_master
            ;;
        2)
            run_slave
            ;;
        3)
            ROLE=$(detect_role)
            if [ "$ROLE" = "master" ]; then
                run_master
            else
                run_slave
            fi
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Main
main() {
    if [ $# -eq 0 ]; then
        run_interactive
    else
        case "$1" in
            master)
                run_master
                ;;
            slave)
                run_slave
                ;;
            auto)
                ROLE=$(detect_role)
                if [ "$ROLE" = "master" ]; then
                    run_master
                else
                    run_slave
                fi
                ;;
            *)
                echo "Usage: $0 [master|slave|auto]"
                echo ""
                echo "Options:"
                echo "  master    Run as master (controller)"
                echo "  slave     Run as slave (worker)"
                echo "  auto      Auto-detect role"
                echo "  (none)    Interactive mode"
                echo ""
                echo "Environment variables:"
                echo "  MASTER_HOST      Master hostname (default: current hostname)"
                echo "  SLAVE_HOST       Slave hostname (default: machine1n.local)"
                echo "  WIFI_INTERFACE   WiFi interface (default: en0)"
                exit 1
                ;;
        esac
    fi
}

main "$@"
