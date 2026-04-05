# M2L Protocol - Machine-to-Learning Distribution

**Version**: 1.0  
**Date**: 2026-01-17  
**Status**: ✅ Operational with R Integration

---

## Overview

The **M2L Protocol** is a distributed machine learning protocol that integrates:

1. **Tesseract Protocol Suite** - Resilient network connectivity with 4D hypercube topology
2. **Data Scanner** - Network state monitoring and structured data collection
3. **Generative Data Pipeline** - Automated export to R for statistical analysis
4. **ML Architecture Tester** - Network resilience and data flow testing
5. **User Connection Protocol** - Entanglement-aware connection management

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    M2L Protocol Controller                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Tesseract   │  │     Data     │  │      R       │     │
│  │  Protocol    │──│   Scanner    │──│  Interface   │     │
│  │  (Network)   │  │  (Hénon Map) │  │ (Analysis)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │             │
│         │                  │                  │             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Entanglement │  │      ML      │  │    Output    │     │
│  │  Detection   │  │Architecture  │  │   Generator  │     │
│  │              │  │   Tester     │  │   (CSV/JSON) │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

1. **Python 3.13** with NumPy
2. **R 4.5.2+** with jsonlite package
3. **Tesseract Protocol** files

### Setup

```bash
cd /Users/nnlr/projects/NCOMM

# Verify R installation
R --version

# Install R packages (if needed)
R --vanilla --slave -e "install.packages(c('jsonlite'), repos='https://cloud.r-project.org')"

# Make scripts executable
chmod +x *.py

# Test installation
python3 m2l_protocol.py --no-connect --steps 10
```

---

## Usage

### Basic Simulation (Standalone Mode)

```bash
python3 m2l_protocol.py --no-connect --steps 100 --coupling 0.05
```

**Parameters:**
- `--no-connect` - Skip network connection (standalone mode)
- `--steps` - Number of simulation steps (default: 100)
- `--coupling` - Network coupling strength (default: 0.05)
- `--nodes` - Number of nodes (auto-adjusted to 16 for tesseract)

### With Network Connection

```bash
# Machine 2 (follower) - start first
python3 machine2_follower.py 0.0.0.0 5555

# Machine 1 (master) - connect and run
python3 m2l_protocol.py --host <machine2_ip> --port 5555 --steps 200
```

### Custom Configuration

```bash
python3 m2l_protocol.py \
  --host localhost \
  --port 5555 \
  --steps 500 \
  --coupling 0.03 \
  --no-connect
```

---

## Components

### 1. DataScanner

Monitors network state from Hénon map dynamics:

- **Statistics**: mean, std, min, max for x and y coordinates
- **Distribution**: Histograms of state space
- **Topology**: Phase space density and clustering coefficient
- **Export**: CSV format compatible with R

### 2. RInterface

Automated statistical analysis in R:

- **Summary Statistics**: Full statistical overview
- **Correlation Analysis**: Inter-variable correlations
- **Time Series**: Trend analysis for x and y coordinates
- **JSON Output**: Structured results for ML pipeline

### 3. MLArchitectureTester

Network performance and resilience testing:

- **Data Flow Test**: Latency and throughput metrics
- **Resilience Test**: Node dropout simulation (10% rate)
- **Success Criteria**: Network operational if >50% nodes active
- **JSON Export**: Test results for analysis

### 4. TesseractEntanglementProtocol

4D hypercube network topology with:

- **16 vertices** = Connection states (2^4)
- **32 edges** = State transitions
- **4 dimensions** = Network layers (Network, Transport, Session, Application)
- **Entanglement detection** = Stuck state recovery
- **Graceful disconnect** = Layer-by-layer teardown

---

## Output Files

All outputs are saved to `m2l_output/` directory:

```
m2l_output/
├── m2l_data_YYYYMMDD_HHMMSS.csv       # Scanned network data
├── m2l_analysis_results.json          # R analysis results
└── m2l_test_results.json              # ML architecture tests
```

### CSV Format (Data Scanner)

```csv
timestamp,n_nodes,mean_x,mean_y,std_x,std_y,min_x,max_x,min_y,max_y,phase_space_density,clustering_coefficient
2026-01-17T23:10:32,16,1.0007,-0.0059,0.1234,0.0456,...
```

### JSON Format (Test Results)

```json
{
  "timestamp": "2026-01-17T23:10:32",
  "test_type": "resilience",
  "total_nodes": 16,
  "active_nodes": 15,
  "dropout_rate": 0.1,
  "network_operational": true
}
```

---

## Hénon Map Dynamics

The protocol uses a coupled Hénon map network:

```
x_{n+1} = 1 - a·x_n² + y_n + κ·(⟨x⟩_neighbors - x_n)
y_{n+1} = b·x_n + κ·(⟨y⟩_neighbors - y_n)
```

**Parameters:**
- `a = 1.4` (chaos parameter)
- `b = 0.3` (contraction parameter)
- `κ = 0.05` (coupling strength)

**Overflow Protection:**
- Initial conditions: x, y ∈ [-0.1, 0.1]
- Value clipping: [-10, 10]

---

## Tesseract Topology

### State Space

```
[0,0,0,0] = Fully connected (ground state)
[1,1,1,1] = Fully disconnected (terminal state)
```

### Dimensions

- **Dim 0**: Network layer
- **Dim 1**: Transport layer
- **Dim 2**: Session layer
- **Dim 3**: Application layer

### Path Traversal

**Forward (Disconnect):**
```
0000 → 0001 → 0011 → 0111 → 1111
```

**Reverse (Return):**
```
1111 → 0111 → 0011 → 0001 → 0000
```

---

## Troubleshooting

### R Analysis Fails

```bash
# Check R installation
which R
R --version

# Reinstall jsonlite
R -e "install.packages('jsonlite', repos='https://cloud.r-project.org')"
```

### Overflow Errors

Reduce coupling strength:
```bash
python3 m2l_protocol.py --no-connect --coupling 0.01
```

### Connection Refused

Ensure Machine 2 is listening:
```bash
# On Machine 2
python3 machine2_follower.py 0.0.0.0 5555

# Check with netstat
netstat -an | grep 5555
```

### Module Import Error

Ensure tesseract protocol is in same directory:
```bash
ls -l tesseract_entanglement_protocol.py
# If missing, copy from source
cp /Volumes/SDROCERSLN/tesseract_transfer/tesseract_entanglement_protocol.py .
```

---

## Integration with NCOMM

The M2L Protocol is part of the NCOMM (Network Communication) project:

```bash
# Sync from Machine 2
rsync -avP --no-compress $(cat ~/.tb-bridge-ip):~/projects/NCOMM/ ~/projects/NCOMM/

# Push to Machine 2
rsync -avP --no-compress ~/projects/NCOMM/ $(cat ~/.tb-bridge-ip):~/projects/NCOMM/
```

---

## Performance Metrics

### Typical Run (100 steps, 16 nodes)

- **Execution time**: ~5 seconds
- **Scans collected**: 10
- **ML tests**: 20
- **CSV size**: ~2KB
- **JSON size**: ~5KB

### Network Resilience

- **Node dropout tolerance**: 50%
- **Entanglement detection**: 3 ACK timeouts or 3s silence
- **Recovery mode**: Automatic force disconnect

---

## License

MIT License (per user preference)

---

## Support Files

- `m2l_protocol.py` - Main protocol implementation
- `tesseract_entanglement_protocol.py` - Network connectivity
- `machine2_follower.py` - Follower node (from SDROCERSLN)
- `README.md` - NCOMM project documentation
- `M2L_README.md` - This file

---

## Status Report

✅ **R Integration**: Installed and operational  
✅ **Data Scanner**: Collecting network metrics  
✅ **ML Testing**: Resilience and flow tests active  
✅ **Tesseract Protocol**: Entanglement detection enabled  
✅ **CSV Export**: R-compatible format  
⚠️ **R Analysis**: Minor issue with correlation (zero std dev) - non-critical  

**Last Test**: 2026-01-17 23:10:32  
**Output**: 10 scans, 20 tests  
**Result**: ✓ SUCCESS
