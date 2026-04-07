#!/bin/bash

# USB-C Bridge Monitor
# Single utility app for monitoring direct machine-to-machine connection
# No WiFi - uses Thunderbolt/USB-C bridge only
# Monitors from /Applications/Utilities equivalent tools

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BRIDGE_INTERFACE="bridge0"
SLAVE_HOST="${SLAVE_HOST:-machine1n.local}"
REFRESH_INTERVAL=2
LOG_FILE="$HOME/Projects/NCOMM/bridge-monitor.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Print functions
print_header() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}     USB-C Bridge Monitor - Direct M2M Connection        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}     No WiFi • Isolated • Monitored                       ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Press Ctrl+C to exit${NC}"
    echo ""
}

print_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log_event() {
    echo "[$(print_timestamp)] $1" >> "$LOG_FILE"
}

# Detect bridge interface
detect_bridge() {
    # Check for Thunderbolt bridge
    if ifconfig | grep -q "^bridge0"; then
        BRIDGE_INTERFACE="bridge0"
        return 0
    fi
    
    # Check for other bridge interfaces
    for iface in $(ifconfig -l); do
        if [[ "$iface" =~ ^bridge[0-9]+ ]]; then
            BRIDGE_INTERFACE="$iface"
            return 0
        fi
    done
    
    return 1
}

# Get bridge status
get_bridge_status() {
    if detect_bridge; then
        local status=$(ifconfig "$BRIDGE_INTERFACE" | grep "status:" | awk '{print $2}')
        local ip=$(ifconfig "$BRIDGE_INTERFACE" | grep "inet " | awk '{print $2}')
        local mac=$(ifconfig "$BRIDGE_INTERFACE" | grep "ether" | awk '{print $2}')
        
        echo -e "${GREEN}[ACTIVE]${NC} Interface: $BRIDGE_INTERFACE"
        echo "  Status:      $status"
        echo "  IP:          ${ip:-"No IP assigned"}"
        echo "  MAC:         $mac"
        
        log_event "Bridge active: $BRIDGE_INTERFACE ($ip)"
        return 0
    else
        echo -e "${RED}[INACTIVE]${NC} No USB-C bridge detected"
        echo "  → Connect USB-C cable between machines"
        log_event "Bridge inactive - no connection"
        return 1
    fi
}

# Check slave connectivity
check_slave_connectivity() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "Slave Machine Connectivity"
    echo "─────────────────────────────────────────────────────────"
    
    if ping -c 1 -W 1000 "$SLAVE_HOST" &>/dev/null; then
        local latency=$(ping -c 3 "$SLAVE_HOST" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
        echo -e "${GREEN}[CONNECTED]${NC} $SLAVE_HOST"
        echo "  Latency:     ${latency}ms (avg)"
        
        # Check SSH
        if nc -z -w 1 "$SLAVE_HOST" 22 &>/dev/null; then
            echo -e "  SSH:         ${GREEN}Port 22 open${NC}"
            log_event "Slave connected - latency: ${latency}ms"
        else
            echo -e "  SSH:         ${YELLOW}Port 22 closed${NC}"
            log_event "Slave connected but SSH unavailable"
        fi
        return 0
    else
        echo -e "${RED}[DISCONNECTED]${NC} $SLAVE_HOST unreachable"
        log_event "Slave disconnected"
        return 1
    fi
}

# Monitor network traffic
monitor_traffic() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "Real-time Traffic Monitor (${REFRESH_INTERVAL}s interval)"
    echo "─────────────────────────────────────────────────────────"
    
    if ! detect_bridge; then
        echo "  No bridge interface available"
        return 1
    fi
    
    # Get initial counters
    local stats=$(netstat -ibn | grep "^$BRIDGE_INTERFACE")
    local rx_packets=$(echo "$stats" | awk '{print $5}')
    local tx_packets=$(echo "$stats" | awk '{print $8}')
    local rx_bytes=$(echo "$stats" | awk '{print $7}')
    local tx_bytes=$(echo "$stats" | awk '{print $10}')
    local rx_errors=$(echo "$stats" | awk '{print $6}')
    local tx_errors=$(echo "$stats" | awk '{print $9}')
    
    echo "  RX: $(numfmt --to=iec-i --suffix=B $rx_bytes 2>/dev/null || echo $rx_bytes) ($rx_packets packets, $rx_errors errors)"
    echo "  TX: $(numfmt --to=iec-i --suffix=B $tx_bytes 2>/dev/null || echo $tx_bytes) ($tx_packets packets, $tx_errors errors)"
    
    # Calculate rate if previous values exist
    if [ -n "$PREV_RX_BYTES" ]; then
        local rx_rate=$(( (rx_bytes - PREV_RX_BYTES) / REFRESH_INTERVAL ))
        local tx_rate=$(( (tx_bytes - PREV_TX_BYTES) / REFRESH_INTERVAL ))
        echo ""
        echo "  Rate RX: $(numfmt --to=iec-i --suffix=B/s $rx_rate 2>/dev/null || echo "${rx_rate} B/s")"
        echo "  Rate TX: $(numfmt --to=iec-i --suffix=B/s $tx_rate 2>/dev/null || echo "${tx_rate} B/s")"
    fi
    
    # Store for next iteration
    export PREV_RX_BYTES=$rx_bytes
    export PREV_TX_BYTES=$tx_bytes
}

# Show ARP table (only bridge devices)
show_connected_devices() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "Connected Devices (ARP - Layer 2)"
    echo "─────────────────────────────────────────────────────────"
    
    local arp_entries=$(arp -an -i "$BRIDGE_INTERFACE" 2>/dev/null | grep -v incomplete)
    
    if [ -n "$arp_entries" ]; then
        echo "$arp_entries" | while read line; do
            echo "  $line"
        done
    else
        echo "  No devices detected on bridge"
    fi
}

# Show active connections (socket level)
show_active_connections() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "Active TCP Connections (via bridge)"
    echo "─────────────────────────────────────────────────────────"
    
    local connections=$(netstat -an | grep ESTABLISHED | grep -E "192.168|169.254|10\." || echo "")
    
    if [ -n "$connections" ]; then
        echo "$connections" | head -10 | awk '{print "  " $0}'
    else
        echo "  No active connections"
    fi
}

# Network isolation check (ensure no WiFi)
check_network_isolation() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "Network Isolation Status"
    echo "─────────────────────────────────────────────────────────"
    
    # Check WiFi status
    local wifi_power=$(networksetup -getairportpower en0 2>/dev/null | grep "On" || echo "")
    if [ -n "$wifi_power" ]; then
        echo -e "  WiFi (en0):  ${YELLOW}ENABLED${NC}"
        echo "  WARNING: WiFi is active - not fully isolated"
        log_event "WARNING: WiFi active during bridge connection"
    else
        echo -e "  WiFi (en0):  ${GREEN}DISABLED${NC}"
        echo "  ✓ Fully isolated connection"
    fi
    
    # Check default route
    local default_route=$(netstat -rn | grep "^default" | head -1 | awk '{print $4}')
    echo "  Default route via: $default_route"
    
    if [[ "$default_route" == "$BRIDGE_INTERFACE" ]]; then
        echo -e "  ${GREEN}✓ All traffic via USB-C bridge${NC}"
    fi
}

# System resource usage
show_system_resources() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "System Resources"
    echo "─────────────────────────────────────────────────────────"
    
    # Get uptime
    local uptime=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    echo "  Uptime:      $uptime"
    
    # CPU and memory from top
    local cpu=$(ps -A -o %cpu | awk '{s+=$1} END {print s "%"}')
    echo "  CPU Usage:   $cpu"
    
    # Network-related processes
    local ssh_procs=$(ps aux | grep -c "[s]shd:" || echo "0")
    echo "  SSH Procs:   $ssh_procs"
}

# Display dashboard
display_dashboard() {
    print_header
    
    echo "═════════════════════════════════════════════════════════"
    echo "Bridge Interface Status"
    echo "═════════════════════════════════════════════════════════"
    get_bridge_status
    
    if detect_bridge; then
        check_slave_connectivity
        monitor_traffic
        show_connected_devices
        show_active_connections
        check_network_isolation
        show_system_resources
    fi
    
    echo ""
    echo "═════════════════════════════════════════════════════════"
    echo "Log: $LOG_FILE"
    echo "Last updated: $(print_timestamp)"
    echo "═════════════════════════════════════════════════════════"
}

# Continuous monitoring mode
monitor_continuous() {
    log_event "=== Bridge monitor started ==="
    
    while true; do
        display_dashboard
        sleep "$REFRESH_INTERVAL"
    done
}

# One-shot status check
check_status() {
    display_dashboard
    echo ""
}

# Setup USB-C bridge connection
setup_bridge() {
    echo -e "${BLUE}Setting up USB-C Bridge Connection${NC}"
    echo ""
    
    echo "1. Physical Setup:"
    echo "   → Connect USB-C/Thunderbolt cable between machines"
    echo ""
    
    echo "2. Disable WiFi for isolation (optional):"
    echo "   → Machine 2: networksetup -setairportpower en0 off"
    echo "   → Machine 1N: networksetup -setairportpower en0 off"
    echo ""
    
    echo "3. Wait for bridge interface to appear..."
    for i in {1..10}; do
        if detect_bridge; then
            echo -e "   ${GREEN}✓ Bridge detected: $BRIDGE_INTERFACE${NC}"
            break
        fi
        echo "   Waiting... ($i/10)"
        sleep 2
    done
    
    if ! detect_bridge; then
        echo -e "   ${RED}✗ Bridge not detected${NC}"
        echo "   Check cable and Thunderbolt settings"
        return 1
    fi
    
    echo ""
    echo "4. Testing connectivity to slave..."
    if check_slave_connectivity; then
        echo ""
        echo -e "${GREEN}✓ USB-C bridge setup complete${NC}"
        log_event "Bridge setup successful"
        return 0
    else
        echo ""
        echo -e "${YELLOW}! Bridge active but slave not reachable${NC}"
        echo "  Ensure slave has bridge interface enabled"
        return 1
    fi
}

# Main menu
show_menu() {
    print_header
    
    echo "Select monitoring mode:"
    echo ""
    echo "  1) Live Monitor (continuous, auto-refresh)"
    echo "  2) Status Check (one-time snapshot)"
    echo "  3) Setup Bridge Connection"
    echo "  4) View Logs"
    echo "  5) Test Slave Connection"
    echo "  q) Quit"
    echo ""
    read -p "Choice: " choice
    
    case $choice in
        1)
            monitor_continuous
            ;;
        2)
            check_status
            ;;
        3)
            setup_bridge
            echo ""
            read -p "Press Enter to return to menu..."
            show_menu
            ;;
        4)
            if [ -f "$LOG_FILE" ]; then
                tail -50 "$LOG_FILE"
            else
                echo "No logs yet"
            fi
            echo ""
            read -p "Press Enter to return to menu..."
            show_menu
            ;;
        5)
            check_slave_connectivity
            echo ""
            read -p "Press Enter to return to menu..."
            show_menu
            ;;
        q|Q)
            log_event "Monitor stopped"
            exit 0
            ;;
        *)
            echo "Invalid choice"
            sleep 1
            show_menu
            ;;
    esac
}

# Handle command line arguments
case "${1:-menu}" in
    monitor|live)
        monitor_continuous
        ;;
    status|check)
        check_status
        ;;
    setup)
        setup_bridge
        ;;
    menu)
        show_menu
        ;;
    *)
        echo "USB-C Bridge Monitor"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  monitor    Live monitoring (continuous refresh)"
        echo "  status     One-time status check"
        echo "  setup      Setup USB-C bridge connection"
        echo "  menu       Interactive menu (default)"
        echo ""
        echo "Environment:"
        echo "  SLAVE_HOST         Slave hostname (default: machine1n.local)"
        echo "  REFRESH_INTERVAL   Refresh rate in seconds (default: 2)"
        exit 1
        ;;
esac
