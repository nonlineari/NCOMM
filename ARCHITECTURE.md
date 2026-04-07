# NCOMM Architecture

**Version**: 2.0
**Date**: 2026-04-07
**Status**: Full-Stack System (Infrastructure + Protocol Layers)

---

## System Overview

NCOMM is a **full-stack distributed system** with two main layers:

1. **Infrastructure Layer** — Physical machine connectivity (SSH, USB-C Bridge, WiFi, router management)
2. **Protocol Layer** — Software-defined protocols for ML, security, and network topology

The infrastructure layer provides the physical transport between Machine 2 and Machine 1N. The protocol layer runs on top of that connectivity, providing the Tesseract network topology, LEN security, and M2L machine learning distribution.

---

## Full-Stack Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          NCOMM V2                                │
└──────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
   ┌────────────┴────────────┐  ┌────────┴──────────────┐
   │   PROTOCOL LAYER          │  │  INFRASTRUCTURE LAYER     │
   │   (protocols/)            │  │  (root scripts)           │
   ├──────────────────────────┤  ├────────────────────────┤
   │                          │  │                        │
   │  ┌────────────────────┐  │  │  ┌──────────────────┐  │
   │  │ M2L Application   │  │  │  │ SSH Automation    │  │
   │  │ (m2l_protocol.py) │  │  │  │ (ncomm.sh +       │  │
   │  │ Hénon dynamics    │  │  │  │  automation-*.sh) │  │
   │  │ R analysis        │  │  │  └──────────────────┘  │
   │  └────────────────────┘  │  │                        │
   │                          │  │  ┌──────────────────┐  │
   │  ┌────────────────────┐  │  │  │ USB-C Bridge     │  │
   │  │ LEN Security      │  │  │  │ Monitor          │  │
   │  │ (len_protocol.py) │  │  │  │ (usbc-bridge-    │  │
   │  │ Auth + Encrypt    │  │  │  │  monitor.sh)     │  │
   │  │ Audit trail       │  │  │  └──────────────────┘  │
   │  └────────────────────┘  │  │                        │
   │                          │  │  ┌──────────────────┐  │
   │  ┌────────────────────┐  │  │  │ Network Diag     │  │
   │  │ Tesseract Network │  │  │  │ + Router Configs │  │
   │  │ (tesseract_*.py)  │  │  │  │ (diagnose-       │  │
   │  │ 4D hypercube      │  │  │  │  network.sh)     │  │
   │  │ 16 vertices       │  │  │  └──────────────────┘  │
   │  └────────────────────┘  │  │                        │
   │                          │  │  ┌──────────────────┐  │
   │  ┌────────────────────┐  │  │  │ SPR + WiFi Sim   │  │
   │  │ Orchestrator      │  │  │  │ (spr-setup.sh,   │  │
   │  │ (ncomm_           │  │  │  │  wifi-master-    │  │
   │  │  integrated.py)   │  │  │  │  slave-sim.sh)   │  │
   │  └────────────────────┘  │  │  └──────────────────┘  │
   │                          │  │                        │
   └──────────────────────────┘  └────────────────────────┘
```

---

## Infrastructure Layer

### Machine Roles

- **Machine 2** (local) — Controller/orchestrator, macOS, `/Users/nonlineari/Projects/NCOMM`
- **Machine 1N** (remote) — Worker/target, macOS 15.7.3, `~/NCOMM` (automation) + `~/Projects/N` (data)

### Transport Mechanisms

NCOMM is transport-agnostic. See [NETWORK-TOPOLOGIES.md](NETWORK-TOPOLOGIES.md) for full details.

- **USB-C Thunderbolt Bridge** — Direct link, 10-40 Gbps, ~1ms latency
- **WiFi** — Shared network, both machines have internet
- **USB-C + Internet Sharing** — Machine 2 routes internet to Machine 1N
- **Dual Connection** — Bridge + WiFi for redundancy/performance

### SSH Configuration

- **Protocol**: SSH (Port 22)
- **Authentication**: Ed25519 key-based
- **Key Location**: `~/.ssh/id_machine1n` (Machine 2)
- **Config**: `~/.ssh/config` → Host alias `machine1n`

### Script Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Machine 2 (Local)                      │
├─────────────────────────────────────────────────────────────┤
│  ncomm.sh ───── Quick-command wrapper                         │
│  setup-ssh-machine1n.sh ─── SSH key generation & config     │
│  automation-machine1n.sh ── Remote exec, copy, sync, info   │
│  deploy-to-machine1n.sh ─── Deploy automation to remote     │
│  compare-automation.sh ──── Compare scripts across machines │
│  diagnose-network.sh ───── Network topology detection       │
│  usbc-bridge-monitor.sh ── Thunderbolt bridge monitoring   │
│  wifi-master-slave-sim.sh ─ WiFi topology simulation        │
│  spr-setup.sh ─────────── Secure Point Router setup       │
│  router-configs/ ──────── TP-Link, Netgear, generic       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ SSH (Port 22, Ed25519 key-based)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Machine 1N (Remote)                     │
├─────────────────────────────────────────────────────────────┤
│  ~/NCOMM/machine1n-automate.sh                               │
│  ├─ setup_project_n()            Create Project N           │
│  ├─ enable_ssh()                 Enable Remote Login        │
│  ├─ configure_network_sharing()  Network config             │
│  ├─ setup_ssh_keys()             SSH key management         │
│  ├─ test_machine2_connection()   Test reverse connection    │
│  ├─ create_network_info()        Generate network info      │
│  └─ show_status()                Display status             │
│                                                              │
│  ~/Projects/N/                                               │
│  ├─ src/ ├─ config/ ├─ data/ ├─ logs/                       │
│  ├─ network-info.txt  └─ README.md                          │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Sequences

**Initial Setup:**
```
Machine 2                           Machine 1N
    │                                    │
    │ 1. ./setup-ssh-machine1n.sh        │
    ├─ Generate SSH keys                 │
    ├─ Show public key                   │
    │        (User copies key)           │
    │ ────────────────────────────────>  │
    │                                    ├─ Enable Remote Login
    │                                    ├─ Add key to authorized_keys
    │ 2. ./ncomm.sh deploy               │
    ├─ Test connection ──────────────>   │
    ├─ Copy machine1n-automate.sh ───>   │
    ├─ Execute setup ─────────────────>  │
    │                                    ├─ Setup Project N
    │                                    └─ Create network-info.txt
```

**Daily Operations:**
```
Machine 2                           Machine 1N
    │                                    │
    │ ./ncomm.sh status ─────────────> │ ── Get status
    │ ./ncomm.sh sync-to ./project ───> │ ── Receive files
    │ ./ncomm.sh exec "command" ──────> │ ── Execute & return
```

---

## Protocol Layer

See [PROTOCOLS-ARCHITECTURE.md](protocols/PROTOCOLS-ARCHITECTURE.md) for the full protocol stack design.

### Protocol Integration Map

```
        ┌─────────────────────────────────────────┐
        │      ncomm_integrated.py                │
        │      • Orchestrates all protocols       │
        │      • Secure connection flow            │
        │      • System status monitoring          │
        └─────────────────────────────────────────┘
                │             │             │
        ┌───────┘     ┌─────┘     ┌───────┘
        ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ M2L           │ │ LEN           │ │ Tesseract      │
│ Application   │◄─│ Security      │◄─│ Network        │
│ Layer         │ │ Layer         │ │ Layer          │
└──────────────┘ └──────────────┘ └──────────────┘
     │                   │                   │
     ▼                   ▼                   ▼
┌──────────┐    ┌──────────┐    ┌──────────┐
│ Hénon     │    │ Users    │    │ State    │
│ Dynamics  │    │ Sessions │    │ Vector   │
│ R Engine  │    │ Auditor  │    │ Graph    │
│ ML Tests  │    │ Encrypt  │    │ Edges    │
└──────────┘    └──────────┘    └──────────┘
```

### Layer Summary

**Tesseract — Network Layer** (`tesseract_entanglement_protocol.py`)
- 16-vertex tesseract topology (2^4 states)
- Bidirectional traversal, entanglement detection, graceful disconnect
- 4 dimensions: Network, Transport, Session, Application
- State: `[0,0,0,0]` (connected) → `[1,1,1,1]` (disconnected)

**LEN — Security Layer** (`len_protocol.py`)
- Salted SHA-256 password hashing, token-based sessions (24h expiration)
- XOR demo / AES-GCM encryption, intrusion detection
- 4 levels: PUBLIC → AUTHENTICATED → ENCRYPTED → VERIFIED
- Full audit trail with timestamped event logging

**M2L — Application Layer** (`m2l_protocol.py`)
- Hénon map dynamics on 16-node tesseract (a=1.4, b=0.3, κ=0.05)
- Data scanning every 10 steps, statistical collection
- R integration for ML analysis and visualization
- Network resilience testing, CSV/JSON export

### Protocol Data Flow

```
User → LEN (auth) → Tesseract (network) → M2L (simulation)
                                              │
                                              ▼
                                    Results + Audit Trail
                                    └─ m2l_output/ (data)
                                    └─ len_output/ (security logs)
```

---

## Cross-Layer Integration

The infrastructure and protocol layers connect at the machine-sync boundary:

```
┌──────────────────────────────────────────────────────────────────┐
│  Machine 2 (Controller)                                          │
│                                                                  │
│  1. ncomm.sh deploy       ── Push automation scripts to M1N      │
│  2. ncomm.sh sync-to      ── Push protocol code to M1N           │
│  3. protocols/*.py        ── Run ML/security locally or remote   │
│  4. diagnose-network.sh   ── Verify connectivity before protocol │
│  5. ncomm.sh exec         ── Run protocol commands on M1N        │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

Typical workflow:
1. Use infrastructure scripts to establish/verify connectivity
2. Sync protocol code to Machine 1N
3. Run protocol stack (locally or remotely via SSH)
4. Collect results via sync-from

---

## Security Architecture

### Infrastructure Security
- Ed25519 SSH keys (no passwords)
- Keys stored in `~/.ssh/` with 600 permissions
- macOS Application Firewall allows SSH
- No root required for normal operations

### Protocol Security (LEN)
- 4-level access control: PUBLIC → AUTHENTICATED → ENCRYPTED → VERIFIED
- Brute-force detection and account lockout
- Full audit trail with timestamps and event types
- Session tokens with 24h expiration

---

## File Structure (V2)

```
NCOMM/
├── README.md                          # Unified project overview
├── ARCHITECTURE.md                    # This file
├── NETWORK-TOPOLOGIES.md              # Physical connection types
├── .gitignore
│
├── # Infrastructure Layer
├── ncomm.sh                           # Quick-command wrapper
├── setup-ssh-machine1n.sh             # SSH key setup
├── automation-machine1n.sh            # Remote operations
├── machine1n-automate.sh              # Remote-side automation
├── deploy-to-machine1n.sh             # Deployment tool
├── compare-automation.sh              # Cross-machine diff
├── diagnose-network.sh                # Topology detection
├── usbc-bridge-monitor.sh             # USB-C bridge monitoring
├── wifi-master-slave-sim.sh           # WiFi simulation
├── spr-setup.sh                       # SPR provisioning
├── spr-config.txt                     # SPR configuration
├── router-configs/                    # Router profiles
│   ├── generic-config.txt
│   ├── netgear-config.txt
│   └── tplink-config.txt
│
├── # Protocol Layer
└── protocols/
    ├── PROTOCOLS-README.md            # Protocol overview
    ├── PROTOCOLS-ARCHITECTURE.md       # Protocol stack design
    ├── LEN_README.md                  # LEN docs
    ├── M2L_README.md                  # M2L docs
    ├── CIMpp-findings.md              # Research findings
    ├── ncomm_integrated.py            # Protocol orchestrator
    ├── len_protocol.py                # Security layer
    ├── m2l_protocol.py                # ML layer
    ├── tesseract_entanglement_protocol.py  # Network topology
    ├── m2l_analysis.R                 # R analysis
    └── m2l_visualize.R                # R visualization
```

---

## Version History

- **v2.0** (2026-04-07): Combined infrastructure + protocol layers into unified repo
- **v1.0** (2026-01-17): Initial M2L and Tesseract protocols

---

## License

MIT License
