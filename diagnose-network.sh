#!/bin/bash
# NCOMM Network Topology Diagnostic Tool

set -e

REMOTE_HOST="machine1n"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    NCOMM Network Topology Diagnostic Tool         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Section 1: Machine 2 (Local) Network Status
echo -e "${GREEN}=== Machine 2 (Local) Network Status ===${NC}"
echo ""

echo -e "${BLUE}Active Interfaces:${NC}"
ifconfig | grep -E "^[a-z]" | while read iface rest; do
    iface_name=$(echo $iface | sed 's/://')
    status=$(ifconfig "$iface_name" | grep "status:" | awk '{print $2}' || echo "")
    inet=$(ifconfig "$iface_name" | grep "inet " | grep -v inet6 | awk '{print $2}' | head -1 || echo "")
    
    if [ ! -z "$inet" ]; then
        echo -e "  ${YELLOW}$iface_name${NC}: $inet ${GREEN}[$status]${NC}"
    fi
done
echo ""

# Detect connection types
echo -e "${BLUE}Connection Types Detected:${NC}"

# Check for WiFi
if ifconfig en0 2>/dev/null | grep -q "status: active"; then
    wifi_ip=$(ifconfig en0 | grep "inet " | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} WiFi (en0): $wifi_ip"
else
    echo -e "  ${RED}✗${NC} WiFi: Not connected"
fi

# Check for Thunderbolt Bridge
if ifconfig bridge0 2>/dev/null | grep -q "inet"; then
    bridge_ip=$(ifconfig bridge0 | grep "inet " | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} Thunderbolt Bridge (bridge0): $bridge_ip"
elif ifconfig bridge100 2>/dev/null | grep -q "inet"; then
    bridge_ip=$(ifconfig bridge100 | grep "inet " | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} Network Bridge (bridge100): $bridge_ip"
else
    echo -e "  ${YELLOW}⚠${NC} Bridge: Not detected (check USB-C connection)"
fi

# Check for Ethernet
if ifconfig en1 2>/dev/null | grep -q "status: active"; then
    eth_ip=$(ifconfig en1 | grep "inet " | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} Ethernet (en1): $eth_ip"
fi

echo ""

# Default route
echo -e "${BLUE}Default Gateway (Internet):${NC}"
default_route=$(route -n get default 2>/dev/null | grep gateway | awk '{print $2}')
default_iface=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
if [ ! -z "$default_route" ]; then
    echo -e "  Gateway: $default_route via ${YELLOW}$default_iface${NC}"
else
    echo -e "  ${RED}No default route${NC}"
fi
echo ""

# Section 2: Machine 1 N Connection Test
echo -e "${GREEN}=== Machine 1 N Connection Test ===${NC}"
echo ""

echo -e "${BLUE}Testing SSH connection...${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ SSH connection successful${NC}"
    
    # Get remote info
    echo ""
    echo -e "${BLUE}Machine 1 N Network Status:${NC}"
    
    # Remote hostname
    remote_hostname=$(ssh "$REMOTE_HOST" "hostname" 2>/dev/null)
    echo -e "  Hostname: ${YELLOW}$remote_hostname${NC}"
    
    # Remote IPs
    echo -e "  Active IPs:"
    ssh "$REMOTE_HOST" "ifconfig | grep 'inet ' | grep -v 127.0.0.1" | while read line; do
        ip=$(echo $line | awk '{print $2}')
        echo -e "    - $ip"
    done
    
    # Remote default route
    remote_gateway=$(ssh "$REMOTE_HOST" "route -n get default 2>/dev/null | grep gateway | awk '{print \$2}'")
    if [ ! -z "$remote_gateway" ]; then
        echo -e "  Gateway: $remote_gateway"
    else
        echo -e "  Gateway: ${YELLOW}None (no internet)${NC}"
    fi
    
    CONNECTION_OK=true
else
    echo -e "  ${RED}✗ Cannot connect to Machine 1 N${NC}"
    echo -e "  ${YELLOW}Run: ./setup-ssh-machine1n.sh${NC}"
    CONNECTION_OK=false
fi

echo ""

# Section 3: Topology Detection
echo -e "${GREEN}=== Network Topology Detection ===${NC}"
echo ""

TOPOLOGY="Unknown"

if [ "$CONNECTION_OK" = true ]; then
    # Get configured hostname from SSH config
    ssh_hostname=$(grep -A 5 "^Host $REMOTE_HOST" ~/.ssh/config 2>/dev/null | grep HostName | awk '{print $2}')
    
    # Check if using mDNS (.local)
    if [[ "$ssh_hostname" == *".local" ]]; then
        # Try to determine if bridge or WiFi
        if ifconfig bridge0 2>/dev/null | grep -q "inet" || ifconfig bridge100 2>/dev/null | grep -q "inet"; then
            TOPOLOGY="USB-C Thunderbolt Bridge"
            echo -e "${CYAN}Detected: USB-C Thunderbolt Bridge${NC}"
            echo -e "  • Direct point-to-point connection"
            echo -e "  • mDNS hostname: $ssh_hostname"
            echo -e "  • Speed: ★★★★★ (10-40 Gbps)"
            echo -e "  • Latency: Very Low"
        else
            TOPOLOGY="WiFi Network (mDNS)"
            echo -e "${CYAN}Detected: WiFi Network${NC}"
            echo -e "  • Shared WiFi network"
            echo -e "  • mDNS hostname: $ssh_hostname"
            echo -e "  • Speed: ★★★☆☆ (WiFi dependent)"
            echo -e "  • Latency: Low"
        fi
    else
        # Using static IP
        TOPOLOGY="WiFi Network (Static IP)"
        echo -e "${CYAN}Detected: WiFi Network (Static IP)${NC}"
        echo -e "  • Direct IP connection: $ssh_hostname"
        echo -e "  • Speed: ★★★☆☆ (WiFi dependent)"
        echo -e "  • Latency: Low"
    fi
    
    # Check for internet sharing
    echo ""
    echo -e "${BLUE}Checking Internet Sharing:${NC}"
    if sysctl net.inet.ip.forwarding 2>/dev/null | grep -q "1"; then
        echo -e "  ${GREEN}✓${NC} IP Forwarding enabled on Machine 2"
        if [ "$TOPOLOGY" = "USB-C Thunderbolt Bridge" ] && [ ! -z "$remote_gateway" ]; then
            echo -e "  ${GREEN}✓${NC} Machine 1 N using Machine 2 as gateway"
            TOPOLOGY="USB-C Bridge + Internet Sharing"
            echo ""
            echo -e "${CYAN}Enhanced: USB-C Bridge with Internet Sharing${NC}"
            echo -e "  • Machine 2 sharing internet to Machine 1 N"
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} IP Forwarding not enabled"
    fi
    
    # Check for dual connection
    if ifconfig en0 2>/dev/null | grep -q "status: active" && \
       (ifconfig bridge0 2>/dev/null | grep -q "inet" || ifconfig bridge100 2>/dev/null | grep -q "inet"); then
        echo ""
        echo -e "${CYAN}Note: Dual Connection Available${NC}"
        echo -e "  • Both WiFi and Bridge active"
        echo -e "  • Can use either for different purposes"
    fi
else
    echo -e "${YELLOW}Cannot detect topology - no connection to Machine 1 N${NC}"
fi

echo ""

# Section 4: Performance Test
if [ "$CONNECTION_OK" = true ]; then
    echo -e "${GREEN}=== Quick Performance Test ===${NC}"
    echo ""
    
    echo -e "${BLUE}Testing latency (ping):${NC}"
    ping_result=$(ssh "$REMOTE_HOST" "ping -c 3 $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
    if [ ! -z "$ping_result" ]; then
        echo -e "  Average: ${YELLOW}${ping_result}ms${NC}"
    else
        echo -e "  ${YELLOW}Unable to test${NC}"
    fi
    
    echo ""
fi

# Section 5: Recommendations
echo -e "${GREEN}=== Recommendations ===${NC}"
echo ""

case "$TOPOLOGY" in
    "USB-C Thunderbolt Bridge")
        echo -e "${BLUE}Current setup is optimal for:${NC}"
        echo "  • Large file transfers"
        echo "  • Low-latency debugging"
        echo "  • Secure isolated development"
        echo ""
        echo -e "${YELLOW}Note:${NC} Machine 1 N has no internet access"
        echo "  To add: Enable Internet Sharing on Machine 2"
        ;;
    "USB-C Bridge + Internet Sharing")
        echo -e "${GREEN}Optimal configuration!${NC}"
        echo "  • Fast local connection"
        echo "  • Internet access on Machine 1 N"
        echo "  • Best of both worlds"
        ;;
    "WiFi Network"*)
        echo -e "${BLUE}Current setup is good for:${NC}"
        echo "  • Wireless development"
        echo "  • Both machines have internet"
        echo "  • Multi-machine clusters"
        echo ""
        echo -e "${YELLOW}Tip:${NC} Connect USB-C for faster transfers"
        ;;
    *)
        echo -e "${YELLOW}Setup incomplete${NC}"
        echo "  1. Run: ./setup-ssh-machine1n.sh"
        echo "  2. Configure Machine 1 N"
        echo "  3. Run: ./ncomm.sh deploy"
        ;;
esac

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "For more details: cat NETWORK-TOPOLOGIES.md"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
