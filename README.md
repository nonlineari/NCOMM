# NCOMM — Network Communication System

**Version 2.0** | Full-Stack Distributed ML, Security & Automation

NCOMM is a two-machine distributed system spanning physical network infrastructure through software-defined protocols for machine learning, security, and network topology management.

```
┌──────────────────────────────────────────────────────────────┐
│                     NCOMM V2 Stack                           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─ Protocol Layer ────────────────────────────────────────┐ │
│  │  M2L Protocol    — Distributed ML (Hénon dynamics)      │ │
│  │  LEN Protocol    — Security (auth, encryption, audit)   │ │
│  │  Tesseract       — 4D hypercube network topology        │ │
│  │  NCOMM Integrated — Unified protocol orchestrator       │ │
│  └─────────────────────────────────────────────────────────┘ │
│                          ▲                                   │
│                          │                                   │
│  ┌─ Infrastructure Layer ──────────────────────────────────┐ │
│  │  SSH Automation   — Key-based Machine 2 ↔ Machine 1N   │ │
│  │  USB-C Bridge     — Thunderbolt direct-link monitor     │ │
│  │  Network Diag     — Topology scanning & diagnostics     │ │
│  │  Router Configs   — TP-Link, Netgear, generic profiles  │ │
│  │  SPR Setup        — Secure Point Router provisioning    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

### Infrastructure — Machine Connectivity

```bash
# 1. Configure SSH to Machine 1N
chmod +x setup-ssh-machine1n.sh
./setup-ssh-machine1n.sh

# 2. Deploy automation to Machine 1N
./ncomm.sh deploy

# 3. Check connection status
./ncomm.sh status
```

### Protocols — ML & Security

```bash
# Demo the full integrated protocol stack
python3 protocols/ncomm_integrated.py --demo

# Run a secure ML simulation
python3 protocols/ncomm_integrated.py --secure-simulation \
  --username admin \
  --password admin123 \
  --steps 200

# Individual protocol demos
python3 protocols/len_protocol.py --demo
python3 protocols/m2l_protocol.py --no-connect --steps 100
```

## Project Structure

```
NCOMM/
├── README.md                       # This file
├── ARCHITECTURE.md                 # Full-stack architecture
├── NETWORK-TOPOLOGIES.md           # Network topology documentation
│
├── # Infrastructure (Machine Connectivity)
├── ncomm.sh                        # Quick-command wrapper
├── setup-ssh-machine1n.sh          # SSH key setup
├── automation-machine1n.sh         # Remote operations
├── machine1n-automate.sh           # Machine 1N local automation
├── deploy-to-machine1n.sh          # Deployment tool
├── compare-automation.sh           # Script comparison tool
├── diagnose-network.sh             # Network diagnostics
├── usbc-bridge-monitor.sh          # USB-C/Thunderbolt bridge monitor
├── wifi-master-slave-sim.sh        # WiFi topology simulation
├── spr-setup.sh                    # Secure Point Router setup
├── spr-config.txt                  # SPR configuration
├── router-configs/                 # Router configuration profiles
│   ├── generic-config.txt
│   ├── netgear-config.txt
│   └── tplink-config.txt
│
├── # Protocols (ML, Security, Network Topology)
└── protocols/
    ├── PROTOCOLS-README.md         # Protocol layer overview
    ├── PROTOCOLS-ARCHITECTURE.md   # Protocol stack architecture
    ├── LEN_README.md               # LEN security protocol docs
    ├── M2L_README.md               # M2L machine learning docs
    ├── CIMpp-findings.md           # CIM++ research findings
    ├── ncomm_integrated.py         # Unified protocol orchestrator
    ├── len_protocol.py             # Security: auth, encryption, audit
    ├── m2l_protocol.py             # ML: Hénon network simulation
    ├── tesseract_entanglement_protocol.py  # 4D network topology
    ├── m2l_analysis.R              # R statistical analysis
    └── m2l_visualize.R             # R visualization
```

## Infrastructure Layer

Physical machine-to-machine connectivity between Machine 2 (controller) and Machine 1N (worker) via SSH over Thunderbolt Bridge (USB-C) or WiFi.

### Machine Roles

- **Machine 2** (local) — Controller/orchestrator, initiates connections
- **Machine 1N** (remote, macOS 15.7.3) — Worker/target, executes tasks

### Common Operations

```bash
./ncomm.sh check              # Test connection
./ncomm.sh status             # Machine 1N status
./ncomm.sh sync-to <path>     # Upload files
./ncomm.sh sync-from <path>   # Download files
./ncomm.sh shell              # Interactive SSH session
./ncomm.sh exec "command"     # Remote execution
```

### Configuration

```bash
export MACHINE1N_USER="username"      # Default: nonlineari
export MACHINE1N_HOST="192.168.1.10"  # Default: machine1n.local
```

### Network Topologies

NCOMM supports multiple physical connection types. See [NETWORK-TOPOLOGIES.md](NETWORK-TOPOLOGIES.md) for details:

- **USB-C Thunderbolt Bridge** — 10-40 Gbps direct link, ~1ms latency
- **WiFi (same network)** — Wireless, both machines have internet
- **USB-C + Internet Sharing** — Machine 2 acts as gateway
- **Dual Connection** — Bridge + WiFi simultaneously for redundancy

## Protocol Layer

Three integrated software protocols form a layered stack running on the infrastructure:

### Tesseract — Network Layer
4D hypercube topology with 16 vertices (2^4 connection states). Manages bidirectional traversal, entanglement detection, and graceful disconnect.

### LEN — Security Layer
Login-Encryption-Network protocol providing salted SHA-256 authentication, token-based sessions, XOR/AES-GCM encryption, intrusion detection, and full audit trail across 4 security levels.

### M2L — Application Layer
Machine-to-Learning distribution using Hénon map dynamics across the tesseract network. Includes data scanning, R integration for statistical analysis, and network resilience testing.

See [Protocol Overview](protocols/PROTOCOLS-README.md) and [Protocol Architecture](protocols/PROTOCOLS-ARCHITECTURE.md) for full details.

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full-stack architecture (infra + protocols) |
| [NETWORK-TOPOLOGIES.md](NETWORK-TOPOLOGIES.md) | Physical network topology documentation |
| [Protocol Overview](protocols/PROTOCOLS-README.md) | Protocol layer details & quick start |
| [Protocol Architecture](protocols/PROTOCOLS-ARCHITECTURE.md) | Protocol stack design & data flows |
| [LEN Protocol](protocols/LEN_README.md) | Security & authentication docs |
| [M2L Protocol](protocols/M2L_README.md) | Machine learning distribution docs |
| [CIM++ Findings](protocols/CIMpp-findings.md) | Research findings |

## Version History

- **v2.0** (2026-04-07): Combined infrastructure automation + protocol stack into unified repository
- **v1.0** (2026-01-17): Initial protocol stack (M2L, LEN, Tesseract)

## License

MIT License
