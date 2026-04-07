# NCOMM - Network Communication Project

**Multi-Protocol Distributed ML & Security System**

This project is synchronized between Machine 1 and Machine 2.

## Protocol Stack

```
┌────────────────────────────────────────────────────────┐
│  Application Layer - M2L Protocol                      │
│  Machine-to-Learning Distribution                       │
│  • Hénon network simulation                            │
│  • Data scanning & collection                          │
│  • R integration for ML analysis                       │
│  • Network resilience testing                          │
├────────────────────────────────────────────────────────┤
│  Security Layer - LEN Protocol                         │
│  Login-Encryption-Network                              │
│  • User authentication & sessions                      │
│  • Encryption layer (XOR demo / AES-GCM)              │
│  • Security auditing & intrusion detection             │
│  • Access control (4 security levels)                  │
├────────────────────────────────────────────────────────┤
│  Network Layer - Tesseract Protocol                    │
│  4D Hypercube Topology                                 │
│  • 16 vertices (2^4 connection states)                 │
│  • Entanglement detection & recovery                   │
│  • Graceful disconnect protocol                        │
│  • Bidirectional traversal                             │
└────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Demo LEN security protocol
python3 len_protocol.py --demo

# Demo M2L machine learning protocol  
python3 m2l_protocol.py --no-connect --steps 100

# Demo full integrated stack
python3 ncomm_integrated.py --demo

# Run secure simulation
python3 ncomm_integrated.py --secure-simulation \
  --username admin \
  --password admin123 \
  --steps 200
```

## Documentation

- **[LEN Protocol](LEN_README.md)** - Security & authentication layer
- **[M2L Protocol](M2L_README.md)** - Machine learning distribution layer
- **Tesseract Protocol** - Network connectivity (see `tesseract_entanglement_protocol.py`)

This project is synchronized between Machine 1 and Machine 2.

## Sync Commands

### Pull from Machine 2 to Machine 1 (this machine)
```bash
# Using saved bridge IP
rsync -avP --no-compress $(cat ~/.tb-bridge-ip):~/projects/NCOMM/ ~/projects/NCOMM/

# Or use the sync script
~/scripts/tb-sync.sh ~/projects/NCOMM
```

### Push from Machine 1 to Machine 2
```bash
# Using saved bridge IP
rsync -avP --no-compress ~/projects/NCOMM/ $(cat ~/.tb-bridge-ip):~/projects/NCOMM/

# Manual with specific IP
rsync -avP --no-compress ~/projects/NCOMM/ username@169.254.x.x:~/projects/NCOMM/
```

### Bidirectional Sync
```bash
# Pull first, then push
rsync -avP --no-compress $(cat ~/.tb-bridge-ip):~/projects/NCOMM/ ~/projects/NCOMM/
rsync -avP --no-compress ~/projects/NCOMM/ $(cat ~/.tb-bridge-ip):~/projects/NCOMM/
```

## Quick Access
```bash
# SSH to Machine 2
ssh $(cat ~/.tb-bridge-ip)

# View NCOMM on Machine 2
ssh $(cat ~/.tb-bridge-ip) "ls -la ~/projects/NCOMM/"
```

## Status
- Machine 1: ~/projects/NCOMM
- Machine 2: ~/projects/NCOMM
- Connection: Thunderbolt Bridge (USB-C)
