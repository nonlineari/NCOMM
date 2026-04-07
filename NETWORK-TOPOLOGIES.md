# NCOMM Network Topologies

## Overview

NCOMM supports multiple network connection scenarios between Machine 2 and Machine 1 N. The automation framework is transport-agnostic and works across all connection types.

## Supported Topologies

### 1. Direct USB-C Bridge Connection

**Topology:**
```
┌──────────────┐         USB-C Cable        ┌──────────────┐
│  Machine 2   │◄──────────────────────────►│  Machine 1 N │
│              │   Thunderbolt Bridge       │              │
└──────────────┘                            └──────────────┘
```

**Characteristics:**
- **Interface**: Thunderbolt Bridge (bridge0 or similar)
- **IP Assignment**: Link-local (169.254.x.x) or DHCP
- **DNS**: Bonjour/mDNS (`machine1n.local`)
- **Speed**: 10-40 Gbps (USB-C/Thunderbolt)
- **Latency**: Very low (~1ms)
- **Isolation**: Private network between two machines

**Setup:**
1. Connect USB-C cable
2. macOS automatically creates bridge interface
3. Bonjour announces hostname
4. SSH via `machine1n.local`

**Pros:**
- Extremely fast file transfers
- No router/WiFi required
- Secure (no network exposure)
- Low latency for real-time tasks

**Cons:**
- Physical connection required
- Limited to 2 machines (without hub)
- No internet on Machine 1 N unless shared

**Use Cases:**
- Large file transfers (video, datasets)
- Low-latency debugging
- Offline environments
- Direct system backup/restore

---

### 2. WiFi Network (Same Local Network)

**Topology:**
```
┌──────────────┐                            ┌──────────────┐
│  Machine 2   │                            │  Machine 1 N │
│    (WiFi)    │                            │    (WiFi)    │
└──────┬───────┘                            └──────┬───────┘
       │                                           │
       │          ┌────────────────┐               │
       └─────────►│  WiFi Router   │◄──────────────┘
                  │  192.168.1.1   │
                  └────────┬───────┘
                           │
                        Internet
```

**Characteristics:**
- **Interface**: en0 (WiFi)
- **IP Assignment**: DHCP from router (192.168.x.x, 10.0.x.x)
- **DNS**: mDNS or router DNS
- **Speed**: 100-1000+ Mbps (WiFi 5/6)
- **Latency**: Low (~5-20ms)
- **Isolation**: Shared network with other devices

**Setup:**
1. Both machines connect to same WiFi
2. Discover IP: `ifconfig en0 | grep "inet "`
3. Update SSH config with IP or use mDNS
4. SSH via IP or `machine1n.local`

**Pros:**
- Wireless/mobile
- Both machines have internet
- Can add more machines easily
- Standard network infrastructure

**Cons:**
- WiFi speed limitations
- Potential interference
- Router dependency
- Network security concerns

**Use Cases:**
- Remote development
- Multi-machine clusters
- Home lab setup
- Continuous automation

---

### 3. USB-C Bridge with Internet Sharing

**Topology:**
```
┌──────────────┐         USB-C              ┌──────────────┐
│  Machine 2   │◄──────────────────────────►│  Machine 1 N │
│              │                            │              │
│ WiFi: en0    │   NAT/Bridge Sharing       │ No WiFi      │
│ Bridge: br0  │   (Machine 2 routes)       │ Uses bridge  │
└──────┬───────┘                            └──────────────┘
       │
       │  WiFi
       ▼
   Internet
```

**Characteristics:**
- **Machine 2**: Acts as gateway/router
- **Machine 1 N**: Uses Machine 2 for internet
- **IP Assignment**: Machine 2 assigns via bridge
- **Speed**: Bridge limited, internet via WiFi
- **Latency**: Low between machines, WiFi to internet

**Setup on Machine 2:**
```bash
# Enable Internet Sharing
sudo sysctl -w net.inet.ip.forwarding=1

# Share WiFi (en0) to Thunderbolt Bridge (bridge0)
# System Settings → General → Sharing → Internet Sharing
# Share from: Wi-Fi
# To computers using: Thunderbolt Bridge
```

**Setup on Machine 1 N:**
```bash
# Set Machine 2 as gateway (automatic with Internet Sharing)
# Verify with: route -n get default
```

**Pros:**
- Machine 1 N gets internet via Machine 2
- High-speed local connection
- Useful if Machine 1 N has no WiFi

**Cons:**
- Machine 2 must stay connected and powered
- Internet speed limited by Machine 2's WiFi
- NAT complexity for some services

**Use Cases:**
- Machine 1 N WiFi broken/disabled
- Isolated testing with controlled internet
- Single internet source for two machines

---

### 4. Dual Connection (Bridge + WiFi Simultaneously)

**Topology:**
```
        ┌──────────────────────────────────────┐
        │         USB-C Bridge (Fast)          │
        │                                      │
┌───────▼────────┐                      ┌─────▼──────────┐
│   Machine 2    │                      │  Machine 1 N   │
│                │                      │                │
│ en0: WiFi      │                      │ en0: WiFi      │
│ br0: Bridge    │                      │ br0: Bridge    │
└───────┬────────┘                      └────────┬───────┘
        │                                        │
        └───────► Router ◄────────────────────────┘
                    │
                 Internet
```

**Characteristics:**
- **Two paths**: Bridge for speed, WiFi for redundancy
- **Routing**: macOS chooses based on metric
- **IP Assignment**: Both interfaces have IPs
- **Speed**: Bridge preferred for local, WiFi for internet

**Route Priority:**
```bash
# Check routing table
netstat -nr

# Typically:
# - Bridge: Higher priority for 169.254.x.x/16
# - WiFi: Higher priority for 0.0.0.0/0 (default/internet)
```

**Pros:**
- Redundancy (if one fails, other works)
- Optimize for speed vs. internet
- Flexibility

**Cons:**
- Complex routing
- Two IP addresses per machine
- Potential routing confusion

**Use Cases:**
- High-availability setup
- Speed-critical local + internet access
- Development testing different networks

---

## NCOMM Configuration for Each Topology

### Auto-Detection Script

All topologies work with NCOMM if the hostname or IP is correctly configured in `~/.ssh/config`.

**Current SSH Config:**
```bash
Host machine1n
    HostName machine1n.local    # Works with: Bridge, WiFi (if mDNS)
    User nonlineari
    IdentityFile ~/.ssh/id_machine1n
```

**For WiFi with Static IP:**
```bash
Host machine1n
    HostName 192.168.1.100      # Replace with actual IP
    User nonlineari
    IdentityFile ~/.ssh/id_machine1n
```

### Network Detection Commands

```bash
# Detect active connection type on Machine 2
ifconfig | grep -A 4 "^en0\|^bridge"

# Find Machine 1 N on network
dns-sd -B _ssh._tcp              # Bonjour SSH services
arp -a | grep -i "machine1n"     # ARP table lookup

# Get Machine 1 N IP (from Machine 1 N)
ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
```

---

## Debugging Connection Issues

### Connection Diagnosis Script

```bash
# On Machine 2
echo "=== Connection Diagnosis ==="

# 1. Check local interfaces
echo "Local interfaces:"
ifconfig | grep -E "^[a-z]|inet " | grep -v inet6

# 2. Test DNS resolution
echo -e "\nDNS resolution:"
dns-sd -G v4 machine1n.local &
sleep 2
kill %1

# 3. Test connectivity
echo -e "\nPing test:"
ping -c 3 machine1n.local || ping -c 3 192.168.1.100

# 4. Test SSH port
echo -e "\nSSH port test:"
nc -zv machine1n.local 22 2>&1

# 5. Check routes
echo -e "\nRouting table:"
netstat -nr | grep default
```

### Common Issues & Solutions

**Issue 1: `machine1n.local` not resolving**
```bash
# Solution: Use IP address instead
# 1. Get IP from Machine 1 N
ssh physical-access-to-machine1n
ifconfig | grep "inet " | grep -v 127.0.0.1

# 2. Update SSH config with IP
vim ~/.ssh/config
# Change: HostName 192.168.1.100
```

**Issue 2: Bridge not created with USB-C**
```bash
# Solution: Check cable and ports
# 1. Verify Thunderbolt cable (not charge-only)
# 2. Try different ports
# 3. Check System Settings → Network
```

**Issue 3: Slow transfer speeds**
```bash
# Solution: Check active interface
# Test speed:
./automation-machine1n.sh exec "dd if=/dev/zero bs=1M count=100" | pv > /dev/null

# If slow, check interface:
netstat -I en0 1    # WiFi stats
netstat -I bridge0 1  # Bridge stats
```

**Issue 4: Internet Sharing not working**
```bash
# On Machine 2
sudo sysctl net.inet.ip.forwarding    # Should be 1
sudo pfctl -s nat                      # Check NAT rules

# On Machine 1 N
route -n get default                   # Should point to Machine 2
```

---

## Performance Comparison

| Topology | Speed | Latency | Internet | Setup |
|----------|-------|---------|----------|-------|
| USB-C Bridge | ★★★★★ | ★★★★★ | ✗ | Easy |
| WiFi Network | ★★★☆☆ | ★★★★☆ | ✓ | Easy |
| Bridge + Sharing | ★★★★★ | ★★★★★ | ✓ (via M2) | Medium |
| Dual Connection | ★★★★★ | ★★★★★ | ✓ | Complex |

---

## Recommended Topology by Use Case

### Large File Transfers (Video, Backups)
→ **USB-C Bridge** (fastest, no WiFi congestion)

### Remote Development
→ **WiFi Network** (wireless, both have internet)

### Machine 1 N No WiFi
→ **Bridge + Internet Sharing** (fast + internet)

### High Availability
→ **Dual Connection** (redundancy)

### Quick Debugging
→ **Any available** (NCOMM works across all)

---

## Testing Your Current Connection

Run this to identify your active topology:

```bash
./ncomm.sh check                          # Test connection
ssh machine1n "ifconfig | grep -A 1 bridge0"  # Check for bridge
ssh machine1n "ifconfig | grep -A 1 en0"      # Check for WiFi
ssh machine1n "route -n get default"          # Check routing
```
