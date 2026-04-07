#!/bin/bash

# SPR (Separate Physical Router) Setup & Activation
# Option 3: Dedicated isolated network for Machine 2 ↔ Machine 1N
# No interference from main network (iPhones, etc.)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SPR_NETWORK="10.0.10.0/24"
SPR_GATEWAY="10.0.10.1"
SPR_DHCP_START="10.0.10.100"
SPR_DHCP_END="10.0.10.150"
SPR_SSID="NCOMM-Isolated"
SPR_PASSWORD="ncomm2024secure"

# Machine MAC addresses (will be detected or set)
MACHINE2_MAC=""
MACHINE1N_MAC=""

# WiFi interface
WIFI_INTERFACE="en0"

# Log file
LOG_FILE="$HOME/Projects/NCOMM/spr-setup.log"
CONFIG_FILE="$HOME/Projects/NCOMM/spr-config.txt"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}   SPR Setup - Separate Physical Router Configuration   ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}   Isolated Network for NCOMM Machine-to-Machine        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Detect current machine MAC address
detect_machine2_mac() {
    MACHINE2_MAC=$(ifconfig "$WIFI_INTERFACE" | grep ether | awk '{print $2}')
    if [ -n "$MACHINE2_MAC" ]; then
        print_success "Machine 2 MAC: $MACHINE2_MAC"
        log "Detected Machine 2 MAC: $MACHINE2_MAC"
    else
        print_error "Could not detect Machine 2 MAC address"
        return 1
    fi
}

# Get Machine 1N MAC (from user or SSH)
get_machine1n_mac() {
    print_step "Attempting to detect Machine 1N MAC address..."
    
    # Try to get via SSH if connection exists
    if ssh -o ConnectTimeout=3 -o BatchMode=yes machine1n "ifconfig en0 | grep ether" 2>/dev/null; then
        MACHINE1N_MAC=$(ssh -o ConnectTimeout=3 -o BatchMode=yes machine1n "ifconfig en0 | grep ether | awk '{print \$2}'" 2>/dev/null)
        if [ -n "$MACHINE1N_MAC" ]; then
            print_success "Machine 1N MAC: $MACHINE1N_MAC (via SSH)"
            log "Detected Machine 1N MAC via SSH: $MACHINE1N_MAC"
            return 0
        fi
    fi
    
    # Manual input
    print_warning "Cannot detect Machine 1N automatically"
    echo ""
    echo "Please enter Machine 1N MAC address manually:"
    echo "(Run on Machine 1N: ifconfig en0 | grep ether)"
    echo ""
    read -p "Machine 1N MAC [xx:xx:xx:xx:xx:xx]: " MACHINE1N_MAC
    
    if [ -n "$MACHINE1N_MAC" ]; then
        print_success "Machine 1N MAC: $MACHINE1N_MAC (manual entry)"
        log "Machine 1N MAC entered manually: $MACHINE1N_MAC"
        return 0
    else
        print_error "MAC address required"
        return 1
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# SPR Configuration
# Generated: $(date)

# Network Configuration
SPR_NETWORK=$SPR_NETWORK
SPR_GATEWAY=$SPR_GATEWAY
SPR_DHCP_START=$SPR_DHCP_START
SPR_DHCP_END=$SPR_DHCP_END

# WiFi Configuration
SPR_SSID=$SPR_SSID
SPR_PASSWORD=$SPR_PASSWORD

# Machine MAC Addresses (whitelist)
MACHINE2_MAC=$MACHINE2_MAC
MACHINE1N_MAC=$MACHINE1N_MAC

# Status
SETUP_DATE=$(date)
STATUS=configured
EOF
    
    print_success "Configuration saved to: $CONFIG_FILE"
    log "Configuration saved"
}

# Load existing configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        print_success "Loaded existing configuration"
        return 0
    fi
    return 1
}

# Display router setup instructions
show_router_setup_guide() {
    print_section "SPR Physical Router Setup Guide"
    
    echo ""
    echo "Hardware Requirements:"
    echo "  • Separate WiFi router (TP-Link, Netgear, etc.)"
    echo "  • Power adapter"
    echo "  • Ethernet cables (optional for initial setup)"
    echo ""
    
    echo "Router Configuration Steps:"
    echo ""
    echo "1. Physical Setup"
    echo "   └─ Connect router to power"
    echo "   └─ Keep router DISCONNECTED from main internet"
    echo "   └─ This creates an isolated network"
    echo ""
    
    echo "2. Connect to Router"
    echo "   └─ On Machine 2, connect to router's default WiFi"
    echo "   └─ Usually named: TP-Link_XXXX or similar"
    echo "   └─ Password on router label or 'admin'"
    echo ""
    
    echo "3. Access Router Admin Interface"
    echo "   └─ Open browser: http://192.168.0.1 or http://192.168.1.1"
    echo "   └─ Common logins: admin/admin, admin/password"
    echo "   └─ Check router label for specific IP/login"
    echo ""
    
    echo "4. Configure Network Settings"
    echo ""
    echo "   a) LAN Settings:"
    echo "      Router IP:        $SPR_GATEWAY"
    echo "      Subnet Mask:      255.255.255.0"
    echo "      DHCP Range:       $SPR_DHCP_START - $SPR_DHCP_END"
    echo ""
    
    echo "   b) WiFi Settings:"
    echo "      SSID:             $SPR_SSID"
    echo "      Password:         $SPR_PASSWORD"
    echo "      Security:         WPA2-PSK/WPA3"
    echo "      Hide SSID:        Optional (for extra isolation)"
    echo ""
    
    echo "   c) MAC Address Filtering (CRITICAL):"
    echo "      Enable MAC Filtering:  YES"
    echo "      Mode:                  Whitelist/Allow Only"
    echo "      Allowed MACs:"
    echo -e "        ${GREEN}Machine 2:  $MACHINE2_MAC${NC}"
    echo -e "        ${GREEN}Machine 1N: $MACHINE1N_MAC${NC}"
    echo ""
    echo "      ${YELLOW}This prevents iPhones and other devices from connecting${NC}"
    echo ""
    
    echo "5. Additional Security (Optional)"
    echo "   └─ Disable WPS"
    echo "   └─ Disable UPnP"
    echo "   └─ Disable remote management"
    echo "   └─ Change admin password"
    echo ""
    
    echo "6. Disconnect from Internet (IMPORTANT)"
    echo "   └─ Do NOT connect router WAN port to modem"
    echo "   └─ This keeps the network completely isolated"
    echo "   └─ Only Machine 2 and Machine 1N can communicate"
    echo ""
}

# Generate router-specific config files
generate_router_configs() {
    print_section "Generating Router Configuration Files"
    
    # Create configs directory
    mkdir -p "$HOME/Projects/NCOMM/router-configs"
    
    # Generic config template
    cat > "$HOME/Projects/NCOMM/router-configs/generic-config.txt" << EOF
# Generic Router Configuration Template
# Copy these settings into your router's admin interface

[LAN Settings]
Router IP Address: $SPR_GATEWAY
Subnet Mask: 255.255.255.0
DHCP Server: Enabled
DHCP Start IP: $SPR_DHCP_START
DHCP End IP: $SPR_DHCP_END
DNS Server: $SPR_GATEWAY (router will handle)

[WiFi Settings]
SSID: $SPR_SSID
Password: $SPR_PASSWORD
Security Mode: WPA2-PSK or WPA3
Channel: Auto (or use 1, 6, 11 for 2.4GHz)
Hide SSID: Optional (Yes for extra security)

[MAC Filtering]
Enable MAC Address Filtering: Yes
Filtering Mode: Whitelist (Allow Listed Only)

Allowed MAC Addresses:
1. $MACHINE2_MAC (Machine 2)
2. $MACHINE1N_MAC (Machine 1N)

[Security Settings]
WPS: Disabled
UPnP: Disabled
Remote Management: Disabled
Admin Password: [Change from default]

[WAN/Internet]
WAN Connection: DISCONNECTED
(Do not connect WAN port - keeps network isolated)
EOF
    
    print_success "Config saved: router-configs/generic-config.txt"
    
    # TP-Link specific
    cat > "$HOME/Projects/NCOMM/router-configs/tplink-config.txt" << EOF
# TP-Link Router Configuration

Login: http://192.168.0.1 or http://tplinkwifi.net
User: admin / Password: admin (or password on label)

Navigation Path:

1. Network → LAN
   - IP Address: $SPR_GATEWAY
   - Save

2. DHCP → DHCP Settings
   - DHCP Server: Enable
   - Start IP: $SPR_DHCP_START
   - End IP: $SPR_DHCP_END
   - Save

3. Wireless → Wireless Settings
   - Wireless Network Name: $SPR_SSID
   - Hide SSID: Optional
   - Save

4. Wireless → Wireless Security
   - Security Type: WPA/WPA2-Personal
   - Password: $SPR_PASSWORD
   - Save

5. Wireless → Wireless MAC Filtering
   - MAC Address Filtering: Enabled
   - Filtering Rules: Allow the stations specified
   - Add Entry: $MACHINE2_MAC (Description: Machine 2)
   - Add Entry: $MACHINE1N_MAC (Description: Machine 1N)
   - Save
EOF
    
    print_success "Config saved: router-configs/tplink-config.txt"
    
    # Netgear specific
    cat > "$HOME/Projects/NCOMM/router-configs/netgear-config.txt" << EOF
# Netgear Router Configuration

Login: http://192.168.1.1 or http://routerlogin.net
User: admin / Password: password (or on label)

Navigation Path:

1. Advanced → Setup → LAN Setup
   - IP Address: $SPR_GATEWAY
   - Apply

2. Advanced → Setup → LAN Setup
   - Use Router as DHCP Server: Yes
   - Starting IP: $SPR_DHCP_START
   - Ending IP: $SPR_DHCP_END
   - Apply

3. Wireless
   - Name (SSID): $SPR_SSID
   - Security Options: WPA2-PSK [AES]
   - Password: $SPR_PASSWORD
   - Apply

4. Advanced → Security → Access Control
   - Turn on Access Control: Yes
   - Access Control Mode: Allow
   - Add Device: $MACHINE2_MAC (Machine 2)
   - Add Device: $MACHINE1N_MAC (Machine 1N)
   - Apply
EOF
    
    print_success "Config saved: router-configs/netgear-config.txt"
    
    echo ""
    print_success "All configuration templates generated"
    log "Router configuration templates created"
}

# Test SPR connectivity
test_spr_connection() {
    print_section "Testing SPR Network Connection"
    
    print_step "Checking WiFi connection to SPR..."
    
    # Check current SSID
    CURRENT_SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " SSID:" | awk '{print $2}')
    
    if [ "$CURRENT_SSID" = "$SPR_SSID" ]; then
        print_success "Connected to SPR network: $SPR_SSID"
        log "Connected to SPR network"
    else
        print_warning "Not connected to SPR network"
        echo "  Current SSID: $CURRENT_SSID"
        echo "  Expected: $SPR_SSID"
        echo ""
        echo "To connect:"
        echo "  1. System Settings → WiFi"
        echo "  2. Select: $SPR_SSID"
        echo "  3. Password: $SPR_PASSWORD"
        return 1
    fi
    
    # Check IP in correct subnet
    print_step "Checking IP assignment..."
    CURRENT_IP=$(ifconfig "$WIFI_INTERFACE" | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    
    if [[ "$CURRENT_IP" =~ ^10\.0\.10\. ]]; then
        print_success "IP in SPR subnet: $CURRENT_IP"
        log "Received IP: $CURRENT_IP"
    else
        print_error "IP not in SPR subnet: $CURRENT_IP"
        return 1
    fi
    
    # Ping gateway
    print_step "Testing gateway connectivity..."
    if ping -c 3 "$SPR_GATEWAY" &>/dev/null; then
        print_success "Gateway reachable: $SPR_GATEWAY"
        log "Gateway ping successful"
    else
        print_error "Cannot reach gateway: $SPR_GATEWAY"
        return 1
    fi
    
    # Check isolation (no internet)
    print_step "Verifying network isolation..."
    if ping -c 1 -W 1000 8.8.8.8 &>/dev/null; then
        print_warning "Internet accessible - network may not be fully isolated"
        echo "  This is OK if router has WAN connected"
        log "Internet accessible from SPR"
    else
        print_success "Network is isolated (no internet) - GOOD"
        log "Network isolated - no internet"
    fi
    
    echo ""
    print_success "SPR network connection test complete"
}

# Connect Machine 2 to SPR network
connect_to_spr() {
    print_section "Connecting Machine 2 to SPR Network"
    
    print_step "Connecting to WiFi: $SPR_SSID"
    
    # Use networksetup to connect
    if networksetup -setairportnetwork "$WIFI_INTERFACE" "$SPR_SSID" "$SPR_PASSWORD" 2>/dev/null; then
        print_success "Connected to $SPR_SSID"
        log "Connected to SPR WiFi"
        
        # Wait for IP
        print_step "Waiting for IP assignment..."
        sleep 3
        
        test_spr_connection
    else
        print_error "Failed to connect to $SPR_SSID"
        echo ""
        echo "Manual connection required:"
        echo "  1. System Settings → WiFi"
        echo "  2. Select: $SPR_SSID"
        echo "  3. Password: $SPR_PASSWORD"
        return 1
    fi
}

# Show current network status
show_network_status() {
    print_section "Current Network Status"
    
    # Current connection
    CURRENT_SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | grep " SSID:" | awk '{print $2}')
    CURRENT_IP=$(ifconfig "$WIFI_INTERFACE" | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    CURRENT_GATEWAY=$(netstat -rn | grep "^default" | head -1 | awk '{print $2}')
    
    echo "  WiFi SSID:    $CURRENT_SSID"
    echo "  IP Address:   $CURRENT_IP"
    echo "  Gateway:      $CURRENT_GATEWAY"
    echo ""
    
    if [ "$CURRENT_SSID" = "$SPR_SSID" ]; then
        print_success "On SPR network"
        
        # Check if Machine 1N is reachable
        print_step "Checking Machine 1N connectivity..."
        if ping -c 1 -W 2000 machine1n.local &>/dev/null; then
            M1N_IP=$(ping -c 1 machine1n.local | grep "bytes from" | awk '{print $4}' | cut -d: -f1)
            print_success "Machine 1N reachable at: $M1N_IP"
            log "Machine 1N reachable: $M1N_IP"
        else
            print_warning "Machine 1N not reachable yet"
            echo "  Ensure Machine 1N is connected to: $SPR_SSID"
        fi
    else
        print_warning "Not on SPR network"
        echo "  To connect: ./spr-setup.sh connect"
    fi
}

# Display summary
show_setup_summary() {
    print_section "SPR Setup Summary"
    
    echo ""
    echo "Network Configuration:"
    echo "  SSID:         $SPR_SSID"
    echo "  Password:     $SPR_PASSWORD"
    echo "  Network:      $SPR_NETWORK"
    echo "  Gateway:      $SPR_GATEWAY"
    echo ""
    echo "Allowed Devices (MAC Whitelist):"
    echo "  Machine 2:    $MACHINE2_MAC"
    echo "  Machine 1N:   $MACHINE1N_MAC"
    echo ""
    echo "Files Created:"
    echo "  Config:       $CONFIG_FILE"
    echo "  Logs:         $LOG_FILE"
    echo "  Templates:    $HOME/Projects/NCOMM/router-configs/"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure physical router (see router-configs/)"
    echo "  2. Connect Machine 2: ./spr-setup.sh connect"
    echo "  3. Connect Machine 1N to SSID: $SPR_SSID"
    echo "  4. Test connection: ./spr-setup.sh test"
    echo "  5. Start monitoring: ./usbc-bridge-monitor.sh"
    echo ""
}

# Main setup workflow
run_setup() {
    print_header
    
    log "=== SPR Setup Started ==="
    
    # Step 1: Detect MACs
    print_section "Step 1: Detect Machine MAC Addresses"
    detect_machine2_mac || exit 1
    get_machine1n_mac || exit 1
    
    # Step 2: Save config
    print_section "Step 2: Save Configuration"
    save_config
    
    # Step 3: Generate router configs
    generate_router_configs
    
    # Step 4: Show setup guide
    show_router_setup_guide
    
    # Step 5: Summary
    show_setup_summary
    
    log "=== SPR Setup Complete ==="
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
show_menu() {
    print_header
    
    # Load existing config if available
    load_config 2>/dev/null || true
    
    echo "SPR Network Manager"
    echo ""
    echo "  1) Initial Setup (configure SPR network)"
    echo "  2) Connect to SPR Network"
    echo "  3) Test SPR Connection"
    echo "  4) Show Network Status"
    echo "  5) View Configuration"
    echo "  6) View Router Setup Guide"
    echo "  7) Regenerate Config Files"
    echo "  q) Quit"
    echo ""
    read -p "Choice: " choice
    
    case $choice in
        1)
            run_setup
            show_menu
            ;;
        2)
            connect_to_spr
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        3)
            test_spr_connection
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            show_network_status
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        5)
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                print_error "No configuration found - run setup first"
            fi
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        6)
            load_config || { print_error "Run setup first"; sleep 2; show_menu; }
            show_router_setup_guide
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        7)
            load_config || { print_error "Run setup first"; sleep 2; show_menu; }
            generate_router_configs
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        q|Q)
            log "SPR setup exited"
            exit 0
            ;;
        *)
            show_menu
            ;;
    esac
}

# Command line interface
case "${1:-menu}" in
    setup)
        run_setup
        ;;
    connect)
        load_config || { print_error "Run setup first: ./spr-setup.sh setup"; exit 1; }
        connect_to_spr
        ;;
    test)
        load_config || { print_error "Run setup first"; exit 1; }
        test_spr_connection
        ;;
    status)
        load_config 2>/dev/null || true
        show_network_status
        ;;
    menu)
        show_menu
        ;;
    *)
        echo "SPR (Separate Physical Router) Setup & Activation"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup      Initial SPR configuration"
        echo "  connect    Connect to SPR network"
        echo "  test       Test SPR connection"
        echo "  status     Show network status"
        echo "  menu       Interactive menu (default)"
        echo ""
        exit 1
        ;;
esac
